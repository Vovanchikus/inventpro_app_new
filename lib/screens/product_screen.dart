import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';

import '../theme/colors.dart';
import '../boxes/hive_boxes.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../models/operation_product.dart';
import '../widgets/product/back_button.dart';
import '../widgets/page_view_images.dart';
import '../widgets/product/tab_buttons.dart';
import '../widgets/product/info_tab.dart';
import '../widgets/product/history_tab.dart';
import '../services/config.dart';

class ProductScreen extends StatefulWidget {
  final int productId;
  final String title;
  final String inventoryNumber;
  final double price;
  final double quantity;
  final double total;
  final String categoryPath;
  final List<String>? images; // ✅ Снова добавлено

  const ProductScreen({
    super.key,
    required this.productId,
    required this.title,
    required this.inventoryNumber,
    required this.price,
    required this.quantity,
    required this.total,
    required this.categoryPath,
    this.images,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  bool _isStatusBarWhite = false;
  int _activeTab = 0;
  int _activeImageIndex = 0;

  List<ProductImage> _images = [];
  bool _loadingImages = true;

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  late Box<ProductImage> _imageBox;
  late Box<Product> _productBox;

  @override
  void initState() {
    super.initState();
    print('[PRODUCT SCREEN] initState | productId=${widget.productId}');

    _scrollController.addListener(_onScroll);
    _imageBox = Hive.box<ProductImage>(HiveBoxes.productImages);
    _productBox = Hive.box<Product>(HiveBoxes.products);

    // Если переданы изображения из внешнего кода, используем их сразу
    if (widget.images != null && widget.images!.isNotEmpty) {
      _images = widget.images!
          .map(
            (url) => ProductImage(
              productId: widget.productId,
              serverUrl: url,
              localPath: '', // локальный путь пока пустой
              isNew: false,
              isSynced: true,
            ),
          )
          .toList();
    }

    _loadHistory();
    _loadImages();
  }

  void _onScroll() {
    if (_scrollController.offset > 250 && !_isStatusBarWhite) {
      _isStatusBarWhite = true;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      );
    } else if (_scrollController.offset <= 250 && _isStatusBarWhite) {
      _isStatusBarWhite = false;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      );
    }
  }

  void _loadHistory() async {
    print('[PRODUCT SCREEN] Загрузка истории');
    final box = Hive.box<OperationProduct>(HiveBoxes.operationProducts);

    final history = box.values
        .where((op) => op.product?.id == widget.productId)
        .map((op) {
          DateTime? date;
          if (op.docDate != null && op.docDate!.isNotEmpty) {
            date = DateTime.tryParse(op.docDate!);
          }
          return {
            'title': op.docName ?? '',
            'date': date,
            'description':
                'Количество: ${op.quantity?.toStringAsFixed(2) ?? '0'}, Контрагент: ${op.counteragent ?? '-'}',
          };
        })
        .toList();

    history.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    setState(() {
      _history = history;
      _loadingHistory = false;
    });

    print('[PRODUCT SCREEN] История загружена: ${history.length}');
  }

  Future<void> _loadImages() async {
    print('[PRODUCT SCREEN] Загрузка изображений из Hive');

    final localImages = _imageBox.values
        .where((img) => img.productId == widget.productId)
        .toList();

    for (final img in localImages) {
      // Если уже нет в списке, добавляем
      if (!_images.contains(img)) _images.add(img);
    }

    print(
      '[PRODUCT SCREEN] Локальных изображений после объединения: ${_images.length}',
    );
    _loadingImages = false;
    setState(() {});

    if (_images.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(0);
      _activeImageIndex = 0;
    }

    await _syncImagesFromServer();
  }

  Future<void> _syncImagesFromServer() async {
    final product = _productBox.get(widget.productId);
    if (product == null) return;

    print('[PRODUCT SCREEN] 🔄 Синхронизация с сервером');

    final dir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${dir.path}/products/${widget.productId}');
    if (!productDir.existsSync()) productDir.createSync(recursive: true);

    final serverUrls = product.images
        .where((url) => url.trim().isNotEmpty && url.startsWith('http'))
        .toList();

    // 1️⃣ Добавляем новые серверные фото
    for (final url in serverUrls) {
      final filename = url.split('/').last;

      final existing = _imageBox.values.firstWhereOrNull(
        (e) =>
            e.productId == widget.productId &&
            (e.serverUrl == url || e.localPath.split('/').last == filename),
      );

      if (existing != null) {
        existing.serverUrl = url;
        existing.isSynced = true;
        existing.isNew = false;
        await existing.save();
        if (!_images.contains(existing)) _images.add(existing);
        continue;
      }

      // Скачиваем новое изображение
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) continue;

        final file = File('${productDir.path}/$filename');
        await file.writeAsBytes(resp.bodyBytes);

        final serverImg = ProductImage(
          localPath: file.path,
          serverUrl: url,
          productId: widget.productId,
          isSynced: true,
          isNew: false,
        );

        await _imageBox.add(serverImg);
        _images.add(serverImg);
      } catch (e) {
        print('[PRODUCT SCREEN] ❌ Ошибка скачивания: $e');
      }
    }

    // 2️⃣ Удаляем локальные фото, которых больше нет на сервере
    final localImages = _imageBox.values
        .where((img) => img.productId == widget.productId)
        .toList();

    for (final img in localImages) {
      if (img.serverUrl != null && !serverUrls.contains(img.serverUrl)) {
        print(
          '[PRODUCT SCREEN] 🗑 Удаляем локально удалённое фото: ${img.localPath}',
        );

        // Удаляем файл
        final file = File(img.localPath);
        if (file.existsSync()) file.deleteSync();

        // Удаляем из Hive
        await img.delete();

        // Удаляем из списка для UI
        _images.removeWhere((e) => e.localPath == img.localPath);
      }
    }

    setState(() {});
  }

  Future<void> _addImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${dir.path}/products/${widget.productId}');
    if (!productDir.existsSync()) productDir.createSync(recursive: true);

    final filename = pickedFile.path.split('/').last;
    final localFile = await File(
      pickedFile.path,
    ).copy('${productDir.path}/$filename');

    final newImg = ProductImage(
      localPath: localFile.path,
      productId: widget.productId,
      isSynced: false,
      isNew: true,
    );

    await _imageBox.add(newImg);
    setState(() {
      _images.add(newImg);
      _activeImageIndex = _images.length - 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_activeImageIndex);
      }
    });

    _uploadImageToServer(newImg);
  }

  Future<void> _uploadImageToServer(ProductImage img) async {
    if (img.isSynced && img.serverUrl != null) return;

    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['product_id'] = img.productId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final streamedResponse = await request.send();
      final respBytes = await streamedResponse.stream.toBytes();
      final respBody = utf8.decode(respBytes);

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(respBody);
        final serverUrl = data['data']?['serverUrl'];
        if (serverUrl != null && serverUrl.toString().isNotEmpty) {
          img.serverUrl = serverUrl;
          img.isSynced = true;
          img.isNew = false;
          await img.save();
          if (!_images.contains(img)) _images.add(img);
        }
      }
    } catch (e) {
      print('[PRODUCT SCREEN] ❌ Исключение загрузки: $e');
    }

    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 300),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgApp,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabButtons(
                          activeTab: _activeTab,
                          onTabChanged: (i) => setState(() => _activeTab = i),
                        ),
                        const SizedBox(height: 20),
                        _activeTab == 0
                            ? InfoTab(
                                title: widget.title,
                                inventoryNumber: widget.inventoryNumber,
                                price: widget.price,
                                quantity: widget.quantity,
                                total: widget.total,
                                categoryPath: widget.categoryPath,
                              )
                            : HistoryTab(
                                history: _history,
                                loading: _loadingHistory,
                              ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: _loadingImages
                ? const Center(child: CircularProgressIndicator())
                : PageViewImages(
                    images: _images,
                    activeIndex: _activeImageIndex,
                    pageController: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _activeImageIndex = index),
                    onAddImage: _addImageFromGallery,
                  ),
          ),
          BackButtonWidget(topPadding: topPadding),
        ],
      ),
    );
  }
}

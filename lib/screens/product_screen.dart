import 'dart:io';
import 'dart:async';
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
import '../services/image_sync_service.dart';

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
  StreamSubscription? _imageSub;

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

    // Подписываемся на изменения в box изображений, чтобы обновлять UI при изменениях из других мест
    _imageSub = _imageBox.watch().listen((event) {
      final current = _imageBox.values
          .where((img) => img.productId == widget.productId)
          .toList();
      _images = [];
      for (final img in current) {
        if (!_images.contains(img)) _images.add(img);
      }
      setState(() {});
    });
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
    // Попробуем выбрать несколько изображений (pickMultiImage). Если недоступно — выбор одного.
    final ImagePicker picker = ImagePicker();
    List<XFile>? pickedFiles;
    try {
      pickedFiles = await picker.pickMultiImage();
    } catch (_) {
      final single = await picker.pickImage(source: ImageSource.gallery);
      if (single != null) pickedFiles = [single];
    }

    if (pickedFiles == null || pickedFiles.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${dir.path}/products/${widget.productId}');
    if (!productDir.existsSync()) await productDir.create(recursive: true);

    final startIndex = _images.length;
    int added = 0;

    for (final pickedFile in pickedFiles) {
      final filename = pickedFile.path.split('/').last;
      final destPath = '${productDir.path}/$filename';

      final localFile = File(pickedFile.path);
      final file = File(destPath);

      try {
        if (!file.existsSync()) {
          await localFile.copy(destPath);
          print('[LOCAL] Файл скопирован: $destPath');
        } else {
          print('[LOCAL] Файл уже существует: $destPath');
        }
      } catch (e) {
        print('[LOCAL] ❌ Ошибка копирования файла: $e');
        continue;
      }

      final newImg = ProductImage(
        localPath: destPath,
        productId: widget.productId,
        isSynced: false,
        isNew: true,
      );

      await _imageBox.add(newImg);

      setState(() {
        _images.add(newImg);
      });

      // Начинаем загрузку на сервер
      _uploadImageToServer(newImg);
      added++;
    }

    if (added > 0) {
      // Перейдём на первый добавленный
      final target = startIndex;
      _activeImageIndex = target;
      if (_pageController.hasClients) _pageController.jumpToPage(target);
    }
  }

  Future<void> _uploadImageToServer(ProductImage img) async {
    if (img.isSynced || img.isUploading) return;

    img.isUploading = true;
    await img.save();

    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields.addAll({
        'product_id': img.productId.toString(),
        'client_id': img.clientId, // уникальный ID для клиента
      });

      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body);
        final serverUrl = json['data']?['serverUrl'] ?? json['data']?['url'];

        if (serverUrl != null) {
          img.serverUrl = serverUrl;
          img.isSynced = true;
          img.isNew = false;
          img.uploadProgress = 1.0;
          await img.save();

          print('[UPLOAD] ✅ Загружено на сервер: $serverUrl');

          // 🔹 Синхронизация с продуктом
          final product = _productBox.get(img.productId);
          if (product != null && !product.images.contains(serverUrl)) {
            product.images = [...product.images, serverUrl];
            await _productBox.put(product.id, product);
          }

          // 🔹 Обновление UI сразу
          if (!_images.contains(img)) {
            _images.add(img);
          }
          setState(() {});
        } else {
          print('[UPLOAD] ❌ serverUrl не вернулся');
        }
      } else {
        print('[UPLOAD] ❌ HTTP ${streamed.statusCode}');
      }
    } catch (e) {
      print('[UPLOAD] ❌ Ошибка загрузки: $e');
    } finally {
      img.isUploading = false;
      await img.save();
    }
  }

  @override
  void dispose() {
    try {
      _imageSub?.cancel();
    } catch (_) {}
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final remainingHeight =
        MediaQuery.of(context).size.height - 300 - topPadding;

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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: remainingHeight > 0 ? remainingHeight : 0,
                  ),
                  child: Container(
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
                    onRetryImage: (img) async {
                      await ImageSyncService.syncSingleImage(img);
                      // Обновим UI после завершения повторной загрузки
                      setState(() {});
                    },
                  ),
          ),
          BackButtonWidget(topPadding: topPadding),
        ],
      ),
    );
  }
}

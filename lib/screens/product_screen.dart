import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:testing_app/services/config.dart';
import 'package:testing_app/services/image_sync_service.dart';
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
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ProductScreen extends StatefulWidget {
  final int productId;
  final String title;
  final String inventoryNumber;
  final double price;
  final double quantity;
  final double total;
  final List<String> images;
  final String categoryPath;

  const ProductScreen({
    super.key,
    required this.productId,
    required this.title,
    required this.inventoryNumber,
    required this.price,
    required this.quantity,
    required this.total,
    required this.images,
    required this.categoryPath,
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

  // ✅ Инициализация пустым списком
  List<ProductImage> _images = [];
  bool _loadingImages = true;

  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  late Box<ProductImage> _imageBox;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _imageBox = Hive.box<ProductImage>(HiveBoxes.productImages);

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
  }

  Future<void> _loadImages() async {
    final productBox = Hive.box<Product>(HiveBoxes.products);
    final product = productBox.get(widget.productId);

    if (product == null) {
      setState(() {
        _loadingImages = false;
      });
      return;
    }

    // Получаем все локальные фото этого продукта
    final localImages = _imageBox.values
        .where((img) => img.productId == widget.productId)
        .toList();

    // Серверные URL
    final serverUrls = product.images
        .where((url) => url.trim().isNotEmpty && url.startsWith('http'))
        .toList();

    // Создаём папку продукта
    final dir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${dir.path}/products/${widget.productId}');
    if (!productDir.existsSync()) productDir.createSync(recursive: true);

    // 1️⃣ Удаляем локальные фото, которых нет на сервере
    for (final img in localImages) {
      if (img.serverUrl != null && !serverUrls.contains(img.serverUrl)) {
        try {
          final file = File(img.localPath);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
        img.delete();
        print('Removed local image no longer on server: ${img.localPath}');
      }
    }

    // 2️⃣ Загружаем актуальные локальные фото заново
    final updatedLocalImages = _imageBox.values
        .where((img) => img.productId == widget.productId)
        .toList();

    _images = [...updatedLocalImages];

    // 3️⃣ Добавляем фото с сервера
    for (final url in serverUrls) {
      // Если уже есть в списке, пропускаем
      if (_images.any((img) => img.serverUrl == url)) continue;

      final filename = url.split('/').last;
      final file = File('${productDir.path}/$filename');
      bool downloaded = true;

      if (!file.existsSync()) {
        try {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200) {
            await file.writeAsBytes(resp.bodyBytes);
          } else {
            print('Error downloading $url: ${resp.statusCode}');
            downloaded = false;
          }
        } catch (e) {
          print('Exception downloading $url: $e');
          downloaded = false;
        }
      }

      if (downloaded && file.existsSync()) {
        final serverImg = ProductImage(
          localPath: file.path,
          serverUrl: url,
          productId: widget.productId,
          isSynced: true,
          isNew: false,
        );

        if (!_imageBox.values.any((img) => img.serverUrl == url)) {
          _imageBox.add(serverImg);
        }

        _images.add(serverImg);
      } else {
        print('Skipped adding image for $url because file not downloaded.');
      }
    }

    // 4️⃣ Обновляем состояние
    setState(() {
      _loadingImages = false;
    });

    // 5️⃣ Сбрасываем PageView на первый кадр
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
      _activeImageIndex = 0;
    }
  }

  Future<void> _addImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
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

      _imageBox.add(newImg);

      setState(() {
        _images.add(newImg);
        _activeImageIndex = _images.length - 1;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_activeImageIndex);
        }
      });

      await _uploadImageToServer(newImg);
    }
  }

  Future<void> _uploadImageToServer(ProductImage img) async {
    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['product_id'] = img.productId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final resp = await request.send();
      final respBody = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        final data = jsonDecode(respBody);

        setState(() {
          img.isSynced = true;
          img.isNew = false;
          if (data['success'] == true && data['data']?['serverUrl'] != null) {
            img.serverUrl = data['data']['serverUrl'];
          }
        });

        if (img.isInBox) img.save();
      } else {
        print('Error uploading image: ${resp.statusCode}');
      }
    } catch (e) {
      print('Exception during upload: $e');
    }
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
                SizedBox(height: 300),
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

          // ✅ PageView с индикатором загрузки
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

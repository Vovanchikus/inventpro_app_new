import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:testing_app/models/product.dart';
import '../theme/colors.dart';
import '../models/operation_product.dart';
import '../boxes/hive_boxes.dart';
import 'package:hive/hive.dart';

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

  late List<String> _images; // локальные и серверные пути
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _images = List<String>.from(widget.images); // начальная инициализация
    _loadHistory();
    _loadProductImages();
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
    final history = box.values.where((op) => op.product?.id == widget.productId).map((
      op,
    ) {
      DateTime? date;
      if (op.docDate != null && op.docDate!.isNotEmpty) {
        date = DateTime.tryParse(op.docDate!);
        if (date != null) {
          print('[ProductScreen] Parsed doc_date: ${op.docDate} -> $date');
        } else {
          print(
            '[ProductScreen] Ошибка парсинга doc_date для id: ${op.id}, значение: ${op.docDate}',
          );
        }
      }
      return {
        'title': op.docName ?? '',
        'date': date,
        'description':
            'Количество: ${op.quantity?.toStringAsFixed(2) ?? '0'}, Контрагент: ${op.counteragent ?? '-'}',
      };
    }).toList();

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
          // Контент скроллится
          NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              // Меняем статусбар при скролле
              if (scroll.metrics.pixels > 250 && !_isStatusBarWhite) {
                _isStatusBarWhite = true;
                SystemChrome.setSystemUIOverlayStyle(
                  SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.white,
                  ),
                );
              } else if (scroll.metrics.pixels <= 250 && _isStatusBarWhite) {
                _isStatusBarWhite = false;
                SystemChrome.setSystemUIOverlayStyle(
                  SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                  ),
                );
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 300), // отступ под PageView
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
                          Row(
                            children: [
                              _tabButton('Информация', 0),
                              const SizedBox(width: 12),
                              _tabButton('История', 1),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _activeTab == 0 ? _infoTab() : _historyTab(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PageView поверх контента
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _images.isEmpty ? 1 : _images.length,
                  onPageChanged: (index) {
                    setState(() => _activeImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    if (_images.isEmpty) {
                      return Center(
                        child: SvgPicture.asset(
                          'assets/icons/image-splash.svg',
                          width: 120,
                          height: 120,
                        ),
                      );
                    }

                    final imagePath = _images[index];
                    final isLocal = File(imagePath).existsSync();

                    return isLocal
                        ? Image.file(
                            File(imagePath),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: imagePath,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.error,
                              size: 60,
                              color: Colors.red,
                            ),
                          );
                  },
                ),

                // Page indicators
                if (_images.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_images.length, (index) {
                        final isActive = index == _activeImageIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 8 : 4,
                          height: isActive ? 8 : 4,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),

                // Кнопка добавить фото
                Positioned(
                  bottom: 16,
                  right: 12,
                  child: InkWell(
                    onTap: () async {
                      final pickedFile = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          _images.add(pickedFile.path);
                          _activeImageIndex = _images.length - 1;
                          _pageController.jumpToPage(_activeImageIndex);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.64),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/image-square-plus-circle.svg',
                        height: 24,
                        width: 24,
                        color: AppColors.bgLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Кнопка назад
          Positioned(
            top: topPadding + 16,
            left: 16,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Загружаем картинки продукта и сохраняем локально для офлайн
  Future<void> _loadProductImages() async {
    final box = Hive.box<Product>(HiveBoxes.products);
    final product = box.get(widget.productId);
    if (product == null || product.images.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    final productDir = Directory('${dir.path}/products/${widget.productId}');
    if (!productDir.existsSync()) productDir.createSync(recursive: true);

    List<String> localPaths = [];
    for (final url in product.images) {
      if (url.trim().isEmpty) continue;
      final filename = url.split('/').last;
      final file = File('${productDir.path}/$filename');

      if (!file.existsSync()) {
        try {
          print('[ProductScreen] Downloading image: $url');
          final resp = await http.get(Uri.parse(url));
          await file.writeAsBytes(resp.bodyBytes);
          print('[ProductScreen] Saved locally: ${file.path}');
        } catch (e) {
          print('[ProductScreen] Ошибка загрузки $url: $e');
        }
      } else {
        print('[ProductScreen] Already exists locally: ${file.path}');
      }
      localPaths.add(file.path);
    }

    if (localPaths.isNotEmpty) {
      setState(() {
        _images = localPaths;
        _activeImageIndex = 0;
        _pageController.jumpToPage(0);
      });
    }
  }

  Widget _tabButton(String text, int index) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _infoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final crumb in widget.categoryPath.split('/')) ...[
              Text(crumb, style: const TextStyle(color: Colors.grey)),
              if (crumb != widget.categoryPath.split('/').last)
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Инвентарный номер: ${widget.inventoryNumber}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoItem('Цена', widget.price.toStringAsFixed(2)),
            _infoItem('Количество', widget.quantity.toStringAsFixed(3)),
            _infoItem('Сумма', widget.total.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Описание товара',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Подробное описание товара. Любой объём текста.'),
      ],
    );
  }

  Widget _historyTab() {
    if (_loadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_history.every((h) => (h['title']?.isEmpty ?? true))) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'История отсутствует',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: _history.where((h) => (h['title']?.isNotEmpty ?? false)).map((
        h,
      ) {
        final index = _history
            .where((h) => (h['title']?.isNotEmpty ?? false))
            .toList()
            .indexOf(h);
        final isFirst = index == 0;
        final isLast =
            index ==
            _history.where((h) => (h['title']?.isNotEmpty ?? false)).length - 1;
        return _timelineCard(h, isFirst, isLast);
      }).toList(),
    );
  }

  Widget _infoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _timelineCard(Map<String, dynamic> h, bool isFirst, bool isLast) {
    const double dotSize = 12;
    const double lineWidth = 2;
    const double spacing = 12;

    String dateStr = '-';
    final date = h['date'] as DateTime?;
    if (date != null) dateStr = DateFormat('dd.MM.yyyy').format(date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dotSize,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: lineWidth, color: Colors.blue),
                  )
                else
                  const Spacer(),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: lineWidth, color: Colors.blue),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(h['description'] ?? ''),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

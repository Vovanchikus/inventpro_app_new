import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';

class ProductScreen extends StatefulWidget {
  final String title;
  final String inventoryNumber;
  final double price;
  final double quantity;
  final double total;
  final List<String> images;
  final String categoryPath;
  final List<Map<String, String>> history;

  const ProductScreen({
    super.key,
    required this.title,
    required this.inventoryNumber,
    required this.price,
    required this.quantity,
    required this.total,
    required this.images,
    required this.categoryPath,
    this.history = const [],
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasImages = widget.images.isNotEmpty;
    final pageCount = hasImages ? widget.images.length : 1;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _isStatusBarWhite
            ? SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white)
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Stack(
          children: [
            // PageView с изображениями
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 300,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: pageCount,
                    onPageChanged: (index) {
                      setState(() => _activeImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      if (!hasImages) {
                        return Center(
                          child: SvgPicture.asset(
                            'assets/icons/image-splash.svg',
                            width: 120,
                            height: 120,
                          ),
                        );
                      }
                      return Image.network(
                        widget.images[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    },
                  ),

                  // Индикаторы точек
                  if (hasImages && widget.images.length > 1)
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (index) {
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

                  // Кнопка добавления фото
                  Positioned(
                    bottom: 32,
                    right: 12,
                    child: InkWell(
                      onTap: () async {
                        final pickedFile = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedFile != null) {
                          setState(() {
                            widget.images.add(pickedFile.path);
                            _activeImageIndex = widget.images.length - 1;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.all(16), // размер "фона"
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

            // Белый блок с информацией и историей
            Positioned(
              top: 280,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.bgApp,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Вкладки
                        Row(
                          children: [
                            _tabButton('Информация', 0),
                            const SizedBox(width: 12),
                            _tabButton('История', 1),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_activeTab == 0) ...[
                          // Хлебные крошки (категории)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final crumb in widget.categoryPath.split(
                                '/',
                              )) ...[
                                Text(
                                  crumb,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (crumb !=
                                    widget.categoryPath.split('/').last)
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
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
                              _infoItem(
                                'Цена',
                                widget.price.toStringAsFixed(2),
                              ),
                              _infoItem(
                                'Количество',
                                widget.quantity.toStringAsFixed(3),
                              ),
                              _infoItem(
                                'Сумма',
                                widget.total.toStringAsFixed(2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Описание товара',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Подробное описание товара. Любой объём текста.',
                          ),
                        ],

                        if (_activeTab == 1) ...[
                          Column(
                            children: List.generate(widget.history.length, (
                              index,
                            ) {
                              final h = widget.history[index];
                              final isFirst = index == 0;
                              final isLast = index == widget.history.length - 1;
                              return _timelineCard(h, isFirst, isLast);
                            }),
                          ),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
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
      ),
    );
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

  Widget _timelineCard(Map<String, String> h, bool isFirst, bool isLast) {
    const double dotSize = 12;
    const double lineWidth = 2;
    const double spacing = 12;

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
                    h['date'] ?? '',
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

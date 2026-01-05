import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_image.dart';
import '../../theme/colors.dart';

class PageViewImages extends StatelessWidget {
  final List<ProductImage> images;
  final int activeIndex;
  final PageController pageController;
  final void Function() onAddImage;
  final void Function(int) onPageChanged;

  const PageViewImages({
    super.key,
    required this.images,
    required this.activeIndex,
    required this.pageController,
    required this.onAddImage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            itemCount: images.isEmpty ? 1 : images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              if (images.isEmpty) {
                return Center(
                  child: SvgPicture.asset(
                    'assets/icons/image-splash.svg',
                    width: 120,
                    height: 120,
                  ),
                );
              }

              final img = images[index];
              final isLocalFile =
                  img.localPath.isNotEmpty && File(img.localPath).existsSync();

              Widget imageWidget;

              if (isLocalFile) {
                imageWidget = Image.file(
                  File(img.localPath),
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              } else if (img.serverUrl != null) {
                imageWidget = CachedNetworkImage(
                  imageUrl: img.serverUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 60, color: Colors.red),
                );
              } else {
                imageWidget = const SizedBox.shrink();
              }

              return Stack(
                children: [
                  Positioned.fill(child: imageWidget),

                  // Прогресс загрузки только для локальных новых фото
                  // ⏳ Круглый индикатор загрузки (как в Telegram)
                  if (img.isNew && !img.isSynced)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: Center(
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: img.uploadProgress > 0
                                  ? img.uploadProgress
                                  : null,
                              strokeWidth: 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Индикатор точек для нескольких фото
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final isActive = index == activeIndex;
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
            bottom: 16,
            right: 12,
            child: InkWell(
              onTap: onAddImage,
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
    );
  }
}

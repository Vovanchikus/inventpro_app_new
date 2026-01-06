import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_image.dart';
import '../../theme/colors.dart';

class PageViewImages extends StatefulWidget {
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
  State<PageViewImages> createState() => _PageViewImagesState();
}

class _PageViewImagesState extends State<PageViewImages> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: widget.pageController,
            itemCount: widget.images.isEmpty ? 1 : widget.images.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              if (widget.images.isEmpty) {
                return Center(
                  child: SvgPicture.asset(
                    'assets/icons/image-splash.svg',
                    width: 120,
                    height: 120,
                  ),
                );
              }

              final img = widget.images[index];
              final isLocalFile =
                  img.localPath.isNotEmpty && File(img.localPath).existsSync();

              Widget imageWidget = const SizedBox.shrink();

              if (isLocalFile) {
                imageWidget = Image.file(
                  File(img.localPath),
                  fit: BoxFit.cover,
                );
              } else if (img.serverUrl != null) {
                imageWidget = CachedNetworkImage(
                  imageUrl: img.serverUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 60, color: Colors.red),
                );
              }

              final screenW = MediaQuery.of(context).size.width;
              final heroTag =
                  img.serverUrl ??
                  (img.localPath.isNotEmpty
                      ? img.localPath
                      : 'product_image_$index');

              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullscreenImage(
                            images: widget.images,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: SizedBox(
                        width: screenW,
                        height: 300,
                        child: Hero(
                          tag: heroTag,
                          child: ClipRect(
                            child: SizedBox.expand(child: imageWidget),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // upload progress overlay for new local images
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

          // Dots
          if (widget.images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  final isActive =
                      (widget.pageController.hasClients
                              ? (widget.pageController.page ??
                                    widget.activeIndex)
                              : widget.activeIndex)
                          .round() ==
                      index;
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

          // Add photo button
          Positioned(
            bottom: 16,
            right: 12,
            child: InkWell(
              onTap: widget.onAddImage,
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

class FullscreenImage extends StatefulWidget {
  final List<ProductImage> images;
  final int initialIndex;

  const FullscreenImage({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<FullscreenImage> createState() => _FullscreenImageState();
}

class _FullscreenImageState extends State<FullscreenImage> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildLargeImage(ProductImage image, String heroTag) {
    if (image.localPath.isNotEmpty && File(image.localPath).existsSync()) {
      return Image.file(File(image.localPath), fit: BoxFit.contain);
    } else if (image.serverUrl != null) {
      return CachedNetworkImage(
        imageUrl: image.serverUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            const Icon(Icons.error, size: 60, color: Colors.red),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final img = widget.images[i];
                final tag =
                    img.serverUrl ??
                    (img.localPath.isNotEmpty
                        ? img.localPath
                        : 'product_image_$i');
                return Center(
                  child: Hero(
                    tag: tag,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: _buildLargeImage(img, tag),
                    ),
                  ),
                );
              },
            ),

            // Top bar with close and index
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

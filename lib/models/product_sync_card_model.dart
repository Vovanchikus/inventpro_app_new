import 'photo_sync_status.dart';
import 'product_image.dart';

class ProductSyncCardModel {
  final int productId;
  final String productName;
  final String? previewImagePath;
  final int totalImages;
  final int pendingCount;
  final int uploadingCount;
  final int errorCount;
  final int syncedCount;
  final double progress;
  final PhotoSyncStatus aggregatedStatus;
  final List<ProductImage> images;

  const ProductSyncCardModel({
    required this.productId,
    required this.productName,
    required this.previewImagePath,
    required this.totalImages,
    required this.pendingCount,
    required this.uploadingCount,
    required this.errorCount,
    required this.syncedCount,
    required this.progress,
    required this.aggregatedStatus,
    required this.images,
  });

  bool get isCompleted => totalImages > 0 && syncedCount == totalImages;
  bool get hasIssues => errorCount > 0;
}

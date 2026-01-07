import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../boxes/hive_boxes.dart';
import '../models/photo_sync_status.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../models/product_sync_card_model.dart';
import '../services/image_sync_service.dart';

class ImagesSyncCenterViewModel extends ChangeNotifier {
  ImagesSyncCenterViewModel({HiveInterface? hive}) : _hive = hive ?? Hive;

  final HiveInterface _hive;

  Box<ProductImage>? _imagesBox;
  Box<Product>? _productsBox;
  StreamSubscription<BoxEvent>? _imagesSubscription;

  bool _isLoading = false;
  bool _isInitialized = false;
  final Set<int> _retryingProductIds = <int>{};

  final List<ProductSyncCardModel> _cards = [];

  List<ProductSyncCardModel> get cards => List.unmodifiable(_cards);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool isProductRetrying(int productId) =>
      _retryingProductIds.contains(productId);

  int get totalPending =>
      _cards.fold(0, (sum, card) => sum + card.pendingCount);
  int get totalUploading =>
      _cards.fold(0, (sum, card) => sum + card.uploadingCount);
  int get totalErrors => _cards.fold(0, (sum, card) => sum + card.errorCount);
  int get totalSynced => _cards.fold(0, (sum, card) => sum + card.syncedCount);

  Future<void> init() async {
    if (_isInitialized) return;
    _setLoading(true);
    await _ensureBoxes();
    _rebuildCards();
    _imagesSubscription = _imagesBox?.watch().listen((_) => _rebuildCards());
    _isInitialized = true;
    _setLoading(false);
  }

  Future<void> refresh() async {
    await _ensureBoxes();
    _rebuildCards();
  }

  Future<void> _ensureBoxes() async {
    _imagesBox = _hive.isBoxOpen(HiveBoxes.productImages)
        ? _hive.box<ProductImage>(HiveBoxes.productImages)
        : await _hive.openBox<ProductImage>(HiveBoxes.productImages);

    _productsBox = _hive.isBoxOpen(HiveBoxes.products)
        ? _hive.box<Product>(HiveBoxes.products)
        : await _hive.openBox<Product>(HiveBoxes.products);
  }

  void _rebuildCards() {
    if (_imagesBox == null || _productsBox == null) return;

    final grouped = <int, List<ProductImage>>{};
    for (final image in _imagesBox!.values.whereType<ProductImage>()) {
      grouped.putIfAbsent(image.productId, () => <ProductImage>[]).add(image);
    }

    final rebuilt = <ProductSyncCardModel>[];

    grouped.forEach((productId, images) {
      final counters = _countStatuses(images);
      final total = images.length;
      final synced = counters[PhotoSyncStatus.synced] ?? 0;
      final pending = counters[PhotoSyncStatus.pending] ?? 0;
      final uploading = counters[PhotoSyncStatus.uploading] ?? 0;
      final errors = counters[PhotoSyncStatus.error] ?? 0;

      final aggregatedStatus = _resolveAggregatedStatus(
        pending: pending,
        uploading: uploading,
        error: errors,
        synced: synced,
      );

      final productName =
          _productsBox!.get(productId)?.name ?? 'Товар #$productId';

      rebuilt.add(
        ProductSyncCardModel(
          productId: productId,
          productName: productName,
          previewImagePath: _resolvePreview(images),
          totalImages: total,
          pendingCount: pending,
          uploadingCount: uploading,
          errorCount: errors,
          syncedCount: synced,
          progress: _calculateProgress(images),
          aggregatedStatus: aggregatedStatus,
          images: List<ProductImage>.unmodifiable(images),
        ),
      );
    });

    rebuilt.sort(
      (a, b) =>
          a.productName.toLowerCase().compareTo(b.productName.toLowerCase()),
    );

    _cards
      ..clear()
      ..addAll(rebuilt);
    notifyListeners();
  }

  Map<PhotoSyncStatus, int> _countStatuses(List<ProductImage> images) {
    final counters = <PhotoSyncStatus, int>{};

    for (final image in images) {
      final status = _statusFor(image);
      counters[status] = (counters[status] ?? 0) + 1;
    }

    return counters;
  }

  PhotoSyncStatus _statusFor(ProductImage image) {
    if (image.hasError) return PhotoSyncStatus.error;
    if (image.isUploading) {
      return PhotoSyncStatus.uploading;
    }
    if (image.isSynced || (image.serverUrl?.isNotEmpty ?? false)) {
      return PhotoSyncStatus.synced;
    }
    return PhotoSyncStatus.pending;
  }

  PhotoSyncStatus _resolveAggregatedStatus({
    required int pending,
    required int uploading,
    required int error,
    required int synced,
  }) {
    if (error > 0) return PhotoSyncStatus.error;
    if (uploading > 0) return PhotoSyncStatus.uploading;
    if (pending > 0) return PhotoSyncStatus.pending;
    if (synced > 0) return PhotoSyncStatus.synced;
    return PhotoSyncStatus.pending;
  }

  String? _resolvePreview(List<ProductImage> images) {
    if (images.isEmpty) return null;
    final remote = images.firstWhere(
      (img) => img.serverUrl != null && img.serverUrl!.isNotEmpty,
      orElse: () => images.first,
    );
    return remote.serverUrl?.isNotEmpty == true
        ? remote.serverUrl
        : remote.localPath;
  }

  double _calculateProgress(List<ProductImage> images) {
    if (images.isEmpty) return 0;
    final progressSum = images.fold<double>(0, (sum, image) {
      if (image.isSynced || (image.serverUrl?.isNotEmpty ?? false)) {
        return sum + 1.0;
      }
      return sum + image.uploadProgress.clamp(0.0, 1.0);
    });
    return (progressSum / images.length).clamp(0.0, 1.0);
  }

  Future<void> retryProduct(int productId) async {
    await _ensureBoxes();
    if (_retryingProductIds.contains(productId)) return;
    _retryingProductIds.add(productId);
    notifyListeners();
    try {
      await ImageSyncService.syncImagesForProduct(productId);
    } finally {
      _retryingProductIds.remove(productId);
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _imagesSubscription?.cancel();
    super.dispose();
  }
}

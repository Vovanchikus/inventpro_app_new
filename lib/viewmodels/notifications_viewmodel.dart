import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../models/product_image.dart';
import '../services/image_sync_service.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../boxes/hive_boxes.dart';

class NotificationsViewModel extends ChangeNotifier {
  final List<NotificationModel> _items = [];
  bool isLoading = false;
  Box? _box;
  StreamSubscription? _boxSub;

  List<NotificationModel> get all => List.unmodifiable(_items);

  // Отфильтрованные списки для вкладок
  List<NotificationModel> get categories =>
      _items.where((e) => e.type == NotificationType.category).toList();

  List<NotificationModel> get products =>
      _items.where((e) => e.type == NotificationType.product).toList();

  List<NotificationModel> get photos =>
      _items.where((e) => e.type == NotificationType.photo).toList();

  List<NotificationModel> get operations =>
      _items.where((e) => e.type == NotificationType.operation).toList();

  // Непрочитанные счётчики для вкладок и общий
  int get unreadCategories => _items
      .where((e) => e.type == NotificationType.category && !e.isRead)
      .fold(0, (s, e) => s + (e.count ?? 1));

  int get unreadProducts => _items
      .where((e) => e.type == NotificationType.product && !e.isRead)
      .fold(0, (s, e) => s + (e.count ?? 1));

  int get unreadPhotos => _items
      .where((e) => e.type == NotificationType.photo && !e.isRead)
      .fold(0, (s, e) => s + (e.count ?? 1));

  int get unreadOperations => _items
      .where((e) => e.type == NotificationType.operation && !e.isRead)
      .fold(0, (s, e) => s + (e.count ?? 1));

  int get unreadTotal =>
      unreadCategories + unreadProducts + unreadPhotos + unreadOperations;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    // Открываем box уведомлений через NotificationService
    _box = await Hive.openBox(NotificationService.boxName);

    // Подписываемся на изменения в box, чтобы автоматически обновлять UI
    listenToBox();

    // Небольшая задержка для UX
    await Future.delayed(const Duration(milliseconds: 100));

    _reloadFromBox();

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();

  void _reloadFromBox() {
    _items.clear();
    if (_box == null) return;
    for (final v in _box!.values) {
      if (v is NotificationModel) {
        _items.add(v);
      } else if (v is Map) {
        try {
          _items.add(NotificationModel.fromMap(v));
        } catch (_) {}
      }
    }
    // сортируем по timestamp — новые сверху
    _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  // --- UI DTOs для карточек уведомлений (MVVM presentation layer) ---
  NotificationCardData cardDataFor(NotificationModel n) {
    // icon, color, status text come from status mapping
    final icon = _iconForStatus(n.status);
    final color = _colorForStatus(n.status);
    final statusLabel = _statusLabel(n);

    // title: keep a short, human-friendly title
    final title = n.type == NotificationType.photo ? 'Фото добавлено' : n.title;

    // subtitle: try to show product name when available, otherwise fallback to description
    String subtitle = n.description;
    if (n.type == NotificationType.photo) {
      // expected description format: 'Фото для товара #<id>' or similar
      final regex = RegExp(r'#(\d+)');
      final m = regex.firstMatch(n.description);
      if (m != null) {
        final pid = int.tryParse(m.group(1) ?? '');
        if (pid != null) {
          try {
            final box = Hive.box<Product>(HiveBoxes.products);
            final p = box.get(pid);
            if (p != null && (p.name?.isNotEmpty ?? false)) {
              subtitle = 'Товар: ${p.name}';
            } else {
              subtitle = 'Для товара #$pid';
            }
          } catch (_) {
            subtitle = 'Для товара #$pid';
          }
        }
      }
    }

    // provide retry callback for photo notifications
    Future<void> Function()? onRetry;
    if (n.type == NotificationType.photo) {
      // id format: photo_{clientId}
      final parts = n.id.split('_');
      if (parts.length >= 2) {
        final clientId = parts.sublist(1).join('_');
        onRetry = () => retryPhotoUpload(clientId);
      }
    }

    return NotificationCardData(
      id: n.id,
      title: title,
      subtitle: subtitle,
      statusLabel: statusLabel,
      icon: icon,
      iconColor: color,
      timestamp: n.timestamp,
      model: n,
      onRetry: onRetry,
    );
  }

  IconData _iconForStatus(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.pending:
        return Icons.hourglass_empty;
      case NotificationStatus.uploading:
        return Icons.cloud_upload;
      case NotificationStatus.synced:
      case NotificationStatus.success:
        return Icons.check_circle;
      case NotificationStatus.error:
        return Icons.error_outline;
    }
  }

  Color _colorForStatus(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.pending:
        return Colors.orange;
      case NotificationStatus.uploading:
        return Colors.blue;
      case NotificationStatus.synced:
      case NotificationStatus.success:
        return Colors.green;
      case NotificationStatus.error:
        return Colors.red;
    }
  }

  String _statusLabel(NotificationModel n) {
    // Prefer explicit paused wording when NotificationService set a paused title
    final t = n.title.toLowerCase();
    if (t.contains('приостанов')) return 'Загрузка приостановлена';
    // Presentation texts (user-friendly, no technical terms)
    switch (n.status) {
      case NotificationStatus.pending:
        return 'Ожидает синхронизации';
      case NotificationStatus.uploading:
        return 'Загружается…';
      case NotificationStatus.synced:
      case NotificationStatus.success:
        return 'Синхронизировано';
      case NotificationStatus.error:
        return 'Ошибка синхронизации';
    }
  }

  /// Пометить все уведомления прочитанными
  Future<void> markAllRead() async {
    await NotificationService.markAllRead();
    // обновим локальный стейт
    _reloadFromBox();
  }

  /// Пометить прочитанными уведомления конкретного типа (используется при открытии вкладке)
  Future<void> markReadByType(NotificationType type) async {
    await NotificationService.markReadByType(type);
    _reloadFromBox();
  }

  /// Очистить историю через ViewModel
  Future<void> clearAll() async {
    await NotificationService.clearAll();
    _reloadFromBox();
  }

  /// Подписка на изменения box (если нужно)
  void listenToBox() {
    if (_box == null) return;
    _boxSub = _box!.watch().listen((_) => _reloadFromBox());
  }

  void disposeListener() {
    if (_box == null) return;
    try {
      _boxSub?.cancel();
    } catch (_) {}
  }

  /// Retry upload for a photo by `clientId` (invoked from View)
  Future<void> retryPhotoUpload(String clientId) async {
    try {
      final box = Hive.box<ProductImage>(HiveBoxes.productImages);
      ProductImage? found;
      for (final e in box.values) {
        if (e is ProductImage && e.clientId == clientId) {
          found = e;
          break;
        }
      }
      if (found == null) return;
      await ImageSyncService.syncSingleImage(found);
    } catch (_) {}
  }
}

class NotificationCardData {
  final String id;
  final String title;
  final String subtitle;
  final String statusLabel;
  final IconData icon;
  final Color iconColor;
  final DateTime timestamp;
  final NotificationModel model;
  final Future<void> Function()? onRetry;

  NotificationCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.icon,
    required this.iconColor,
    required this.timestamp,
    required this.model,
    this.onRetry,
  });
}

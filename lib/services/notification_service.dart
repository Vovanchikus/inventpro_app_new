import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../boxes/hive_boxes.dart';
import '../models/product.dart';
import '../models/operation.dart';
import '../models/product_image.dart';
import '../models/category.dart' as app_category;
import '../models/photo_sync_status.dart';

class NotificationService {
  static const String boxName = 'notificationsBox';

  static Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return await Hive.openBox(boxName);
  }

  static Future<void> addNotification(NotificationModel n) async {
    final box = await _openBox();
    await box.add(n);
  }

  static Future<int> unreadCount() async {
    final box = await _openBox();
    int c = 0;
    for (final v in box.values) {
      if (v is NotificationModel) {
        if (v.isRead != true) c++;
      } else if (v is Map) {
        if (v['isRead'] != true) c++;
      }
    }
    return c;
  }

  static Future<void> markAllRead() async {
    final box = await _openBox();
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is NotificationModel) {
        if (!v.isRead) {
          v.isRead = true;
          await box.putAt(i, v);
        }
      } else if (v is Map) {
        final updated = Map<String, dynamic>.from(v);
        if (updated['isRead'] != true) {
          updated['isRead'] = true;
          await box.putAt(i, updated);
        }
      }
    }
  }

  static Future<void> markReadByType(NotificationType type) async {
    final box = await _openBox();
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is NotificationModel) {
        if (v.type == type && !v.isRead) {
          v.isRead = true;
          await box.putAt(i, v);
        }
      } else if (v is Map) {
        final updated = Map<String, dynamic>.from(v);
        if (updated['type'] == type.index && updated['isRead'] != true) {
          updated['isRead'] = true;
          await box.putAt(i, updated);
        }
      }
    }
  }

  static Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }

  /// Единая точка для создания/обновления уведомления о фото по clientId.
  /// Гарантирует, что для одного фото существует только одно уведомление.
  static Future<void> upsertOrUpdatePhotoNotification({
    required String clientId,
    required int productId,
    required Object status,
    String? localPath,
    String? serverUrl,
    String? errorText,
  }) async {
    final bool wasPaused =
        (status is PhotoSyncStatus && status == PhotoSyncStatus.paused);
    final box = await _openBox();
    final id = 'photo_$clientId';
    int? idx;
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is NotificationModel && v.id == id) {
        idx = i;
        break;
      } else if (v is Map && v['id'] == id) {
        idx = i;
        break;
      }
    }

    // Normalize incoming status: accept PhotoSyncStatus or NotificationStatus
    NotificationStatus nStatus;
    if (status is PhotoSyncStatus) {
      nStatus = status.toNotificationStatus();
    } else if (status is NotificationStatus) {
      nStatus = status as NotificationStatus;
    } else {
      throw ArgumentError(
        'status must be PhotoSyncStatus or NotificationStatus',
      );
    }

    String title;
    String description = 'Фото для товара #$productId';
    switch (nStatus) {
      case NotificationStatus.pending:
        title = wasPaused
            ? 'Загрузка приостановлена'
            : 'Фото добавлено (ожидает синхронизации)';
        if (wasPaused)
          description =
              errorText ?? 'Загрузка приостановлена (проверьте соединение)';
        break;
      case NotificationStatus.uploading:
        title = 'Фото загружается…';
        break;
      case NotificationStatus.synced:
        title = 'Фото добавлено и синхронизировано';
        break;
      case NotificationStatus.error:
        title = 'Фото добавлено, синхронизация не выполнена';
        if (errorText != null && errorText.isNotEmpty) description = errorText;
        break;
      case NotificationStatus.success:
        title = 'Фото добавлено';
        break;
    }

    final now = DateTime.now();
    if (idx != null) {
      final v = box.getAt(idx);
      if (v is NotificationModel) {
        v.status = nStatus;
        v.title = title;
        v.description = description;
        v.timestamp = now;
        v.isRead = false;
        await box.putAt(idx, v);
      } else if (v is Map) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = nStatus.index;
        updated['title'] = title;
        updated['description'] = description;
        updated['timestamp'] = now.toIso8601String();
        updated['isRead'] = false;
        await box.putAt(idx, updated);
      }
    } else {
      await box.add(
        NotificationModel(
          id: id,
          type: NotificationType.photo,
          action: NotificationAction.create,
          title: title,
          description: description,
          timestamp: now,
          status: nStatus,
          isRead: false,
        ),
      );
    }
  }

  static Future<void> initHistoricFromData() async {
    final box = await _openBox();
    if (box.isNotEmpty) return; // only if empty

    // Products
    if (Hive.isBoxOpen(HiveBoxes.products)) {
      final prodBox = Hive.box<Product>(HiveBoxes.products);
      for (final v in prodBox.values) {
        if (v is Product) {
          if (v.createdAt != null) {
            await box.add(
              NotificationModel(
                id: 'product_created_${v.id}_${v.createdAt.millisecondsSinceEpoch}',
                type: NotificationType.product,
                action: NotificationAction.create,
                title: 'Добавлен товар',
                description: v.name,
                timestamp: v.createdAt,
                status: NotificationStatus.success,
                isRead: false,
              ),
            );
          }
          if (v.updatedAt != null && v.updatedAt != v.createdAt) {
            await box.add(
              NotificationModel(
                id: 'product_updated_${v.id}_${v.updatedAt.millisecondsSinceEpoch}',
                type: NotificationType.product,
                action: NotificationAction.update,
                title: 'Обновлён товар',
                description: v.name,
                timestamp: v.updatedAt,
                status: NotificationStatus.success,
                isRead: false,
              ),
            );
          }
        }
      }
    }

    // Operations
    if (Hive.isBoxOpen(HiveBoxes.operations)) {
      final opBox = Hive.box<Operation>(HiveBoxes.operations);
      for (final v in opBox.values) {
        if (v is Operation) {
          final ts = v.createdAt ?? v.updatedAt ?? DateTime.now();
          await box.add(
            NotificationModel(
              id: 'operation_${v.id}_$ts',
              type: NotificationType.operation,
              action: NotificationAction.create,
              title: 'Операция',
              description: 'Операция #${v.id}',
              timestamp: ts,
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    // Product images
    if (Hive.isBoxOpen(HiveBoxes.productImages)) {
      final imgBox = Hive.box<ProductImage>(HiveBoxes.productImages);
      for (final v in imgBox.values) {
        if (v is ProductImage) {
          await box.add(
            NotificationModel(
              id: 'photo_${v.clientId}',
              type: NotificationType.photo,
              action: NotificationAction.create,
              title: 'Добавлено фото',
              description: 'Фото для товара ID ${v.productId}',
              timestamp: DateTime.now(),
              status: v.isSynced
                  ? NotificationStatus.synced
                  : NotificationStatus.pending,
              isRead: false,
            ),
          );
        }
      }
    }

    // Categories
    if (Hive.isBoxOpen(HiveBoxes.categories)) {
      final catBox = Hive.box<app_category.Category>(HiveBoxes.categories);
      for (final v in catBox.values) {
        if (v is app_category.Category) {
          await box.add(
            NotificationModel(
              id: 'category_${v.id}',
              type: NotificationType.category,
              action: NotificationAction.create,
              title: 'Категория',
              description: v.name,
              timestamp: DateTime.now(),
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    // После записи отсортировать неудобно в box (порядок добавления — хронологический),
    // UI будет сортировать по timestamp при чтении.
  }
}

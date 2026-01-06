import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../boxes/hive_boxes.dart';
import '../models/product.dart';
import '../models/operation.dart';
import '../models/product_image.dart';
import '../models/category.dart';

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
                  ? NotificationStatus.success
                  : NotificationStatus.pending,
              isRead: false,
            ),
          );
        }
      }
    }

    // Categories
    if (Hive.isBoxOpen(HiveBoxes.categories)) {
      final catBox = Hive.box<Category>(HiveBoxes.categories);
      for (final v in catBox.values) {
        if (v is Category) {
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

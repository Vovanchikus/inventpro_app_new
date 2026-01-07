import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../boxes/hive_boxes.dart';
import '../models/product.dart';
import '../models/operation.dart';
import '../models/category.dart' as app_category;

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
      for (final product in prodBox.values) {
        await box.add(
          NotificationModel(
            id: 'product_created_${product.id}_${product.createdAt.millisecondsSinceEpoch}',
            type: NotificationType.product,
            action: NotificationAction.create,
            title: 'Добавлен товар',
            description: product.name,
            timestamp: product.createdAt,
            status: NotificationStatus.success,
            isRead: false,
          ),
        );

        if (product.updatedAt != product.createdAt) {
          await box.add(
            NotificationModel(
              id: 'product_updated_${product.id}_${product.updatedAt.millisecondsSinceEpoch}',
              type: NotificationType.product,
              action: NotificationAction.update,
              title: 'Обновлён товар',
              description: product.name,
              timestamp: product.updatedAt,
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    // Operations
    if (Hive.isBoxOpen(HiveBoxes.operations)) {
      final opBox = Hive.box<Operation>(HiveBoxes.operations);
      for (final operation in opBox.values) {
        final ts = operation.createdAt ?? operation.updatedAt ?? DateTime.now();
        await box.add(
          NotificationModel(
            id: 'operation_${operation.id}_$ts',
            type: NotificationType.operation,
            action: NotificationAction.create,
            title: 'Операция',
            description: 'Операция #${operation.id}',
            timestamp: ts,
            status: NotificationStatus.success,
            isRead: false,
          ),
        );
      }
    }

    // Categories
    if (Hive.isBoxOpen(HiveBoxes.categories)) {
      final catBox = Hive.box<app_category.Category>(HiveBoxes.categories);
      for (final category in catBox.values) {
        await box.add(
          NotificationModel(
            id: 'category_${category.id}',
            type: NotificationType.category,
            action: NotificationAction.create,
            title: 'Категория',
            description: category.name,
            timestamp: DateTime.now(),
            status: NotificationStatus.success,
            isRead: false,
          ),
        );
      }
    }

    // После записи отсортировать неудобно в box (порядок добавления — хронологический),
    // UI будет сортировать по timestamp при чтении.
  }
}

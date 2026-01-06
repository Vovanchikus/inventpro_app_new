// api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/operation_type.dart';
import '../models/operation.dart';
import '../models/operation_product.dart';
import '../models/document.dart';
import '../boxes/hive_boxes.dart';
import '../models/notification_model.dart';

enum SyncStatus { success, info, error }

class ApiService {
  final String baseUrl;
  late HttpClient _httpClient;

  ApiService({required this.baseUrl}) {
    _httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }

  Future<List<dynamic>> _get(
    String endpoint, {
    Duration? timeout,
    bool noTimeout = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/$endpoint');
    final effectiveTimeout = (noTimeout
        ? null
        : (timeout ?? const Duration(seconds: 5)));

    try {
      final requestFuture = _httpClient.getUrl(url);
      final request = effectiveTimeout != null
          ? await requestFuture.timeout(effectiveTimeout)
          : await requestFuture;

      final responseFuture = request.close();
      final response = effectiveTimeout != null
          ? await responseFuture.timeout(effectiveTimeout)
          : await responseFuture;

      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        if (json['success'] == true && json['data'] != null) {
          if (json['data'] is Map) {
            return (json['data'] as Map).values.toList();
          }
          return json['data'] as List<dynamic>;
        } else {
          throw Exception('Ошибка API: ${json['error'] ?? 'пустой ответ'}');
        }
      } else {
        throw Exception('Ошибка API: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] Ошибка при GET $endpoint: $e');
      rethrow;
    }
  }

  /// Выполняет синхронизацию данных и возвращает список уведомлений,
  /// которые должны быть созданы на основании новых серверных объектов.
  Future<List<NotificationModel>> syncAll() async {
    const connectTimeout = Duration(seconds: 5);
    try {
      await _get('categories', timeout: connectTimeout);
    } on TimeoutException catch (_) {
      debugPrint('[ApiService] Сервер недоступен');
      throw TimeoutException('Сервер недоступен');
    } catch (e) {
      debugPrint('[ApiService] Ошибка проверки сервера: $e');
      rethrow;
    }

    try {
      final notifications = await _syncAllInternal(noTimeout: true);
      return notifications;
    } catch (e) {
      debugPrint('[ApiService] Ошибка syncAll: $e');
      rethrow;
    }
  }

  // ----------------------- Категории -----------------------
  Future<List<NotificationModel>> syncCategories({
    bool noTimeout = false,
  }) async {
    final data = await _get('categories', noTimeout: noTimeout);
    final box = Hive.box<Category>(HiveBoxes.categories);
    final List<NotificationModel> notifications = [];

    Future<void> _saveRecursive(List<dynamic> items, int? parentId) async {
      for (var item in items) {
        final category = Category(
          id: item['id'] ?? 0,
          name: item['name']?.toString() ?? '',
          parentId: parentId,
          slug: item['slug']?.toString() ?? '',
          deleted: false,
        );
        final existing = box.get(category.id);
        if (existing == null ||
            existing.name != category.name ||
            existing.parentId != category.parentId) {
          box.put(category.id, category);
          if (existing == null) {
            notifications.add(
              NotificationModel(
                id: 'category_sync_${category.id}_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.category,
                action: NotificationAction.create,
                title: 'Добавлена категория',
                description: category.name,
                timestamp: DateTime.now(),
                status: NotificationStatus.success,
                isRead: false,
              ),
            );
          }
        }
        if (item['children'] != null && item['children'] is List) {
          await _saveRecursive(item['children'], category.id);
        }
      }
    }

    await _saveRecursive(data, null);
    debugPrint(
      '[ApiService] Категории синхронизированы, уведомлений: ${notifications.length}',
    );
    return notifications;
  }

  // ----------------------- Продукты -----------------------
  Future<List<NotificationModel>> syncProducts({bool noTimeout = false}) async {
    final data = await _get('products', noTimeout: noTimeout);
    final box = Hive.box<Product>(HiveBoxes.products);
    final List<NotificationModel> notifications = [];

    for (var item in data) {
      final product = Product(
        id: item['id'] ?? 0,
        name: item['name']?.toString() ?? '',
        invNumber: item['inv_number']?.toString() ?? '',
        unit: item['unit']?.toString() ?? '',
        quantity: double.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
        price: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        sum: double.tryParse(item['sum']?.toString() ?? '0') ?? 0,
        categoryId: item['category_id'] ?? 0,
        updatedAt:
            DateTime.tryParse(item['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        createdAt:
            DateTime.tryParse(item['created_at']?.toString() ?? '') ??
            DateTime.now(),
        images: item['images'] != null && item['images'] is List
            ? (item['images'] as List)
                  .map((i) => i is String ? i : i['url']?.toString() ?? '')
                  .toList()
            : [],
      );

      final existing = box.get(product.id);
      if (existing == null ||
          existing.name != product.name ||
          existing.quantity != product.quantity ||
          existing.price != product.price ||
          existing.sum != product.sum ||
          existing.categoryId != product.categoryId ||
          !_listEquals(existing.images, product.images)) {
        box.put(product.id, product);
        if (existing == null) {
          notifications.add(
            NotificationModel(
              id: 'product_sync_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.product,
              action: NotificationAction.create,
              title: 'Добавлен товар',
              description: product.name,
              timestamp: DateTime.now(),
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    debugPrint(
      '[ApiService] Продукты синхронизированы, уведомлений: ${notifications.length}',
    );
    return notifications;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ----------------------- Типы операций -----------------------
  Future<List<NotificationModel>> syncOperationTypes({
    bool noTimeout = false,
  }) async {
    final data = await _get('operation-types', noTimeout: noTimeout);
    final box = Hive.box<OperationType>(HiveBoxes.operationTypes);
    final List<NotificationModel> notifications = [];
    for (var item in data) {
      final type = OperationType(
        id: item['id'] ?? 0,
        name: item['name']?.toString() ?? '',
      );
      final existing = box.get(type.id);
      if (existing == null || existing.name != type.name) {
        box.put(type.id, type);
        // no notifications for operation types
      }
    }

    debugPrint('[ApiService] Типы операций синхронизированы');
    return notifications;
  }

  // ----------------------- Операции -----------------------
  Future<List<NotificationModel>> syncOperations({
    bool noTimeout = false,
  }) async {
    final data = await _get('operations', noTimeout: noTimeout);
    final box = Hive.box<Operation>(HiveBoxes.operations);
    final List<NotificationModel> notifications = [];

    for (var item in data) {
      final op = Operation(
        id: item['id'] ?? 0,
        typeId: item['type_id'] ?? 0,
        createdAt:
            DateTime.tryParse(item['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(item['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

      final existing = box.get(op.id);
      if (existing == null || existing.typeId != op.typeId) {
        box.put(op.id, op);
        if (existing == null) {
          notifications.add(
            NotificationModel(
              id: 'operation_sync_${op.id}_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.operation,
              action: NotificationAction.create,
              title: 'Новая операция',
              description: 'Операция #${op.id}',
              timestamp: DateTime.now(),
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    debugPrint(
      '[ApiService] Операции синхронизированы, уведомлений: ${notifications.length}',
    );
    return notifications;
  }

  // ----------------------- OperationProducts -----------------------
  Future<List<NotificationModel>> syncOperationProducts({
    bool noTimeout = false,
  }) async {
    final data = await _get('history', noTimeout: noTimeout);
    final box = Hive.box<OperationProduct>(HiveBoxes.operationProducts);
    final List<NotificationModel> notifications = [];
    for (var item in data) {
      DateTime? docDate;
      final docDateStr = item['doc_date']?.toString();
      if (docDateStr != null && docDateStr.isNotEmpty) {
        docDate = DateFormat('dd.MM.yyyy').parse(docDateStr);
      }

      final opProduct = OperationProduct(
        id: item['id'] ?? 0,
        product: item['product'] != null && item['product'] is Map
            ? Product(
                id: item['product']['id'] ?? 0,
                name: item['product']['name'] ?? '',
                invNumber: item['product']['inv_number'] ?? '',
                unit: item['product']['unit'] ?? '',
                quantity: 0,
                price:
                    double.tryParse(
                      item['product']['price']?.toString() ?? '0',
                    ) ??
                    0,
                sum: 0,
                categoryId: item['product']['category_id'] ?? 0,
                updatedAt: DateTime.now(),
                createdAt: DateTime.now(),
                images:
                    item['product']['images'] != null &&
                        item['product']['images'] is List
                    ? (item['product']['images'] as List)
                          .map(
                            (i) => i is String ? i : i['url']?.toString() ?? '',
                          )
                          .toList()
                    : [],
              )
            : null,
        operation: item['operation'] != null && item['operation'] is Map
            ? Operation(
                id: item['operation']['id'] ?? 0,
                typeId: item['operation']['type']?['id'] ?? 0,
                createdAt: docDate,
                updatedAt: docDate,
              )
            : null,
        counteragent: item['counteragent']?.toString(),
        quantity: double.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
        docDate: docDate?.toIso8601String(),
        docName: item['doc_name']?.toString(),
        docNum: item['doc_num']?.toString(),
      );

      final existing = box.get(opProduct.id);
      if (existing == null ||
          existing.quantity != opProduct.quantity ||
          existing.counteragent != opProduct.counteragent ||
          existing.docDate != opProduct.docDate) {
        box.put(opProduct.id, opProduct);
      }
    }

    debugPrint('[ApiService] OperationProducts синхронизированы');
    return notifications;
  }

  // ----------------------- Документы -----------------------
  Future<List<NotificationModel>> syncDocuments({
    bool noTimeout = false,
  }) async {
    final data = await _get('documents', noTimeout: noTimeout);
    final box = Hive.box<Document>(HiveBoxes.documents);
    final List<NotificationModel> notifications = [];
    for (var item in data) {
      final doc = Document(
        id: item['id'] ?? 0,
        operationId: item['operation_id'] ?? 0,
        name: item['name']?.toString() ?? '',
        number: item['number']?.toString() ?? '',
        date: item['date'] != null
            ? DateTime.tryParse(item['date']?.toString() ?? '')
            : null,
        purpose: item['purpose']?.toString() ?? '',
        filePath: null,
      );

      final existing = box.get(doc.id);
      if (existing == null || existing.name != doc.name) {
        box.put(doc.id, doc);
      }
    }
    debugPrint('[ApiService] Документы синхронизированы');
    return notifications;
  }

  /// Внутренний агрегатор: выполняет все шаги и собирает NotificationModel-ы
  Future<List<NotificationModel>> _syncAllInternal({
    bool noTimeout = false,
  }) async {
    final List<NotificationModel> notifications = [];

    notifications.addAll(await syncCategories(noTimeout: noTimeout));
    notifications.addAll(await syncOperationTypes(noTimeout: noTimeout));
    notifications.addAll(await syncProducts(noTimeout: noTimeout));
    notifications.addAll(await syncOperations(noTimeout: noTimeout));
    notifications.addAll(await syncOperationProducts(noTimeout: noTimeout));
    notifications.addAll(await syncDocuments(noTimeout: noTimeout));

    return notifications;
  }
}

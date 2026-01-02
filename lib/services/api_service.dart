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

enum SyncStatus { success, info, error }

class ApiService {
  final String baseUrl;
  late HttpClient _httpClient;

  ApiService({required this.baseUrl}) {
    _httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }

  /// Универсальный GET-запрос с таймаутом подключения
  /// noTimeout == true => не ограничиваем таймаут
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

  /// ==========================
  /// Полная синхронизация с таймаутом подключения
  /// ==========================
  Future<SyncStatus> syncAll() async {
    // Таймаут только на проверку доступности сервера
    const connectTimeout = Duration(seconds: 5);

    try {
      await _get('categories', timeout: connectTimeout);
    } on TimeoutException catch (_) {
      debugPrint('[ApiService] Синхронизация отменена: сервер недоступен');
      return SyncStatus.error;
    } catch (e) {
      debugPrint('[ApiService] Ошибка при проверке сервера: $e');
      return SyncStatus.error;
    }

    // Если сервер доступен, запускаем обычную последовательную синхронизацию без таймаута
    try {
      await _syncAllInternal(noTimeout: true);
      return SyncStatus.success;
    } catch (e) {
      debugPrint('[ApiService] Ошибка при syncAll: $e');
      return SyncStatus.error;
    }
  }

  /// Внутренняя последовательная синхронизация всех сущностей
  Future<void> _syncAllInternal({bool noTimeout = false}) async {
    try {
      await syncCategories(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncCategories: $e');
    }
    try {
      await syncOperationTypes(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncOperationTypes: $e');
    }
    try {
      await syncProducts(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncProducts: $e');
    }
    try {
      await syncOperations(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncOperations: $e');
    }
    try {
      await syncOperationProducts(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncOperationProducts: $e');
    }
    try {
      await syncDocuments(noTimeout: noTimeout);
    } catch (e) {
      debugPrint('Ошибка syncDocuments: $e');
    }

    debugPrint('[ApiService] Полная синхронизация завершена');
  }

  /// ==========================
  /// Категории (рекурсивно)
  /// ==========================
  Future<int> _saveCategoriesRecursive(
    List<dynamic> data,
    Box<Category> box, [
    int? parentId,
  ]) async {
    int updated = 0;
    for (var item in data) {
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
        updated++;
      }

      if (item['children'] != null && item['children'] is List) {
        updated += await _saveCategoriesRecursive(
          item['children'],
          box,
          category.id,
        );
      }
    }
    return updated;
  }

  Future<int> syncCategories({bool noTimeout = false}) async {
    final data = await _get('categories', noTimeout: noTimeout);
    final box = Hive.box<Category>(HiveBoxes.categories);
    int updated = await _saveCategoriesRecursive(data, box);
    debugPrint('[ApiService] Категории синхронизированы: $updated');
    return updated;
  }

  /// ==========================
  /// Продукты
  /// ==========================
  Future<int> syncProducts({bool noTimeout = false}) async {
    final data = await _get('products', noTimeout: noTimeout);
    final box = Hive.box<Product>(HiveBoxes.products);
    int updated = 0;

    for (var item in data) {
      final product = Product(
        id: item['id'] ?? 0,
        name: item['name']?.toString() ?? '',
        invNumber: item['inv_number']?.toString() ?? '',
        unit: item['unit']?.toString() ?? '',
        quantity: double.tryParse(item['quantity']?.toString() ?? '') ?? 0,
        price: double.tryParse(item['price']?.toString() ?? '') ?? 0,
        sum: double.tryParse(item['sum']?.toString() ?? '') ?? 0,
        categoryId: item['category_id'] ?? 0,
        updatedAt:
            DateTime.tryParse(item['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        createdAt:
            DateTime.tryParse(item['created_at']?.toString() ?? '') ??
            DateTime.now(),
        images: item['images'] != null && item['images'] is List
            ? List<String>.from(item['images'])
            : [],
      );

      final existing = box.get(product.id);
      if (existing == null ||
          existing.name != product.name ||
          existing.quantity != product.quantity ||
          existing.price != product.price ||
          existing.sum != product.sum ||
          existing.categoryId != product.categoryId) {
        box.put(product.id, product);
        updated++;
      }
    }

    debugPrint('[ApiService] Продукты синхронизированы: $updated');
    return updated;
  }

  /// ==========================
  /// Типы операций
  /// ==========================
  Future<int> syncOperationTypes({bool noTimeout = false}) async {
    final data = await _get('operation-types', noTimeout: noTimeout);
    final box = Hive.box<OperationType>(HiveBoxes.operationTypes);
    int updated = 0;

    for (var item in data) {
      final type = OperationType(
        id: item['id'] ?? 0,
        name: item['name']?.toString() ?? '',
      );
      final existing = box.get(type.id);
      if (existing == null || existing.name != type.name) {
        box.put(type.id, type);
        updated++;
      }
    }

    debugPrint('[ApiService] Типы операций синхронизированы: $updated');
    return updated;
  }

  /// ==========================
  /// Операции
  /// ==========================
  Future<int> syncOperations({bool noTimeout = false}) async {
    final data = await _get('operations', noTimeout: noTimeout);
    final box = Hive.box<Operation>(HiveBoxes.operations);
    int updated = 0;

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
        updated++;
      }
    }

    debugPrint('[ApiService] Операции синхронизированы: $updated');
    return updated;
  }

  /// ==========================
  /// История операций (OperationProducts)
  /// ==========================
  Future<int> syncOperationProducts({bool noTimeout = false}) async {
    final data = await _get('history', noTimeout: noTimeout);
    final box = Hive.box<OperationProduct>(HiveBoxes.operationProducts);
    int updated = 0;

    for (var item in data) {
      DateTime? docDate;
      final docDateStr = item['doc_date']?.toString();
      if (docDateStr != null && docDateStr.isNotEmpty) {
        try {
          docDate = DateFormat('dd.MM.yyyy').parse(docDateStr);
        } catch (e) {
          debugPrint(
            '[syncOperationProducts] Ошибка парсинга doc_date: $docDateStr',
          );
        }
      }

      final opProduct = OperationProduct(
        id: item['id'] ?? 0,
        product: item['product'] != null
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
                categoryId: 0,
                updatedAt: DateTime.now(),
                createdAt: DateTime.now(),
                images:
                    item['product']['images'] != null &&
                        item['product']['images'] is List
                    ? List<String>.from(item['product']['images'])
                    : [],
              )
            : null,
        operation: item['operation'] != null
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
        updated++;
      }
    }

    debugPrint('[ApiService] OperationProducts синхронизированы: $updated');
    return updated;
  }

  /// ==========================
  /// Документы
  /// ==========================
  Future<int> syncDocuments({bool noTimeout = false}) async {
    final data = await _get('documents', noTimeout: noTimeout);
    final box = Hive.box<Document>(HiveBoxes.documents);
    int updated = 0;

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
        updated++;
      }
    }

    debugPrint('[ApiService] Документы синхронизированы: $updated');
    return updated;
  }
}

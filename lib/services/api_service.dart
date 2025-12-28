import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/io_client.dart';
import 'package:hive/hive.dart';

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
  late IOClient _client;

  ApiService({required this.baseUrl}) {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    _client = IOClient(httpClient);
  }

  Future<List<dynamic>> _get(String endpoint) async {
    final url = Uri.parse('$baseUrl/api/$endpoint');
    try {
      final res = await _client.get(url);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] != null) {
          return json['data'] as List<dynamic>;
        } else {
          throw Exception('Ошибка API: ${json['error'] ?? 'пустой ответ'}');
        }
      } else {
        throw Exception('Ошибка API: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] Ошибка при GET $endpoint: $e');
      rethrow;
    }
  }

  /// Рекурсивная функция для сохранения категорий и их дочерних элементов
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

      // Сохраняем дочерние категории рекурсивно
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

  Future<int> syncCategories() async {
    final data = await _get('categories');
    final box = Hive.box<Category>(HiveBoxes.categories);
    int updated = await _saveCategoriesRecursive(data, box);
    debugPrint('[ApiService] Категории синхронизированы: $updated');
    return updated;
  }

  Future<int> syncProducts() async {
    final data = await _get('products');
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

  Future<int> syncOperationTypes() async {
    final data = await _get('operation-types');
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

  Future<int> syncOperations() async {
    final data = await _get('operations');
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

  Future<int> syncOperationProducts() async {
    final ops = await _get('operations');
    final box = Hive.box<OperationProduct>(HiveBoxes.operationProducts);
    int updated = 0;
    for (var op in ops) {
      final products = (op['products'] ?? []) as List<dynamic>;
      for (var p in products) {
        final pivot = OperationProduct(
          operationId: op['id'] ?? 0,
          productId: p['id'] ?? 0,
          quantity: double.tryParse(p['quantity']?.toString() ?? '') ?? 0,
          sum: double.tryParse(p['sum']?.toString() ?? '') ?? 0,
          counteragent: p['counteragent']?.toString() ?? '',
        );
        final key = '${op['id']}_${p['id']}';
        final existing = box.get(key);
        if (existing == null ||
            existing.quantity != pivot.quantity ||
            existing.sum != pivot.sum) {
          box.put(key, pivot);
          updated++;
        }
      }
    }
    debugPrint('[ApiService] OperationProducts синхронизированы: $updated');
    return updated;
  }

  Future<int> syncDocuments() async {
    final data = await _get('documents');
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

  Future<SyncStatus> syncAll() async {
    int totalUpdated = 0;
    try {
      totalUpdated += await syncCategories();
    } catch (e) {
      debugPrint('Ошибка syncCategories: $e');
    }
    try {
      totalUpdated += await syncOperationTypes();
    } catch (e) {
      debugPrint('Ошибка syncOperationTypes: $e');
    }
    try {
      totalUpdated += await syncProducts();
    } catch (e) {
      debugPrint('Ошибка syncProducts: $e');
    }
    try {
      totalUpdated += await syncOperations();
    } catch (e) {
      debugPrint('Ошибка syncOperations: $e');
    }
    try {
      totalUpdated += await syncOperationProducts();
    } catch (e) {
      debugPrint('Ошибка syncOperationProducts: $e');
    }
    try {
      totalUpdated += await syncDocuments();
    } catch (e) {
      debugPrint('Ошибка syncDocuments: $e');
    }

    debugPrint('[ApiService] Полная синхронизация завершена: $totalUpdated');
    if (totalUpdated > 0) return SyncStatus.success;
    return SyncStatus.info;
  }
}

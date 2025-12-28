import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/operation_type.dart';
import '../models/operation.dart';
import '../models/operation_product.dart';
import '../models/document.dart';
import '../boxes/hive_boxes.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  /// Получаем JSON с сервера
  Future<List<dynamic>> _get(String endpoint) async {
    final url = Uri.parse('$baseUrl/api/$endpoint');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Ошибка API: ${res.statusCode}');
    }
  }

  /// Синхронизация категорий
  Future<void> syncCategories() async {
    final List<dynamic> data = await _get('categories');
    final box = Hive.box<Category>(HiveBoxes.categories);

    for (var item in data) {
      final existing = box.get(item['id']);
      final category = Category(
        id: item['id'],
        name: item['name'],
        parentId: item['parent_id'],
        slug: item['slug'],
        deleted: false,
      );
      box.put(category.id, category);
    }
  }

  /// Синхронизация продуктов
  Future<void> syncProducts() async {
    final List<dynamic> data = await _get('products');
    final box = Hive.box<Product>(HiveBoxes.products);

    for (var item in data) {
      final product = Product(
        id: item['id'],
        name: item['name'],
        invNumber: item['inv_number'],
        unit: item['unit'],
        quantity: (item['quantity'] ?? 0).toDouble(),
        price: (item['price'] ?? 0).toDouble(),
        sum: (item['sum'] ?? 0).toDouble(),
        categoryId: item['category_id'] ?? 0,
        updatedAt: DateTime.parse(item['updated_at']),
        createdAt: DateTime.parse(item['created_at']),
      );
      box.put(product.id, product);
    }
  }

  /// Синхронизация типов операций
  Future<void> syncOperationTypes() async {
    final List<dynamic> data = await _get('operation-types');
    final box = Hive.box<OperationType>(HiveBoxes.operationTypes);

    for (var item in data) {
      final type = OperationType(id: item['id'], name: item['name']);
      box.put(type.id, type);
    }
  }

  /// Синхронизация операций
  Future<void> syncOperations() async {
    final List<dynamic> data = await _get('operations');
    final box = Hive.box<Operation>(HiveBoxes.operations);

    for (var item in data) {
      final op = Operation(
        id: item['id'],
        typeId: item['type_id'] ?? 0,
        createdAt: DateTime.parse(item['created_at']),
        updatedAt: DateTime.parse(item['updated_at']),
      );
      box.put(op.id, op);
    }
  }

  /// Синхронизация pivot таблицы OperationProduct
  Future<void> syncOperationProducts() async {
    final List<dynamic> ops = await _get('operations');
    final box = Hive.box<OperationProduct>(HiveBoxes.operationProducts);

    for (var op in ops) {
      final products = op['products'] as List<dynamic>;
      for (var p in products) {
        final pivot = OperationProduct(
          operationId: op['id'],
          productId: p['id'],
          quantity: (p['quantity'] ?? 0).toDouble(),
          sum: (p['sum'] ?? 0).toDouble(),
          counteragent: p['counteragent'],
        );
        box.put('${op['id']}_${p['id']}', pivot);
      }
    }
  }

  /// Синхронизация документов
  Future<void> syncDocuments() async {
    final List<dynamic> data = await _get('documents');
    final box = Hive.box<Document>(HiveBoxes.documents);

    for (var item in data) {
      final doc = Document(
        id: item['id'],
        operationId: item['operation_id'],
        name: item['name'],
        number: item['number'],
        date: item['date'] != null ? DateTime.parse(item['date']) : null,
        purpose: item['purpose'],
        filePath: null, // можно добавить загрузку файла отдельно
      );
      box.put(doc.id, doc);
    }
  }

  /// Полная синхронизация
  Future<void> syncAll() async {
    await syncCategories();
    await syncOperationTypes();
    await syncProducts();
    await syncOperations();
    await syncOperationProducts();
    await syncDocuments();
  }
}

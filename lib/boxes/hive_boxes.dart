import 'package:hive/hive.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/operation_type.dart';
import '../models/operation.dart';
import '../models/operation_product.dart';
import '../models/document.dart';

class HiveBoxes {
  static const String categories = 'categoriesBox';
  static const String products = 'productsBox';
  static const String operationTypes = 'operationTypesBox';
  static const String operations = 'operationsBox';
  static const String operationProducts = 'operationProductsBox';
  static const String documents = 'documentsBox';

  static Future<void> openAll() async {
    await Hive.openBox<Category>(categories);
    await Hive.openBox<Product>(products);
    await Hive.openBox<OperationType>(operationTypes);
    await Hive.openBox<Operation>(operations);
    await Hive.openBox<OperationProduct>(operationProducts);
    await Hive.openBox<Document>(documents);
  }
}

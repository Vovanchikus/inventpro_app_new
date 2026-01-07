import 'package:hive/hive.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../models/operation.dart';
import '../models/operation_product.dart';
import '../models/operation_type.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../features/operations/data/models/operation_history_cache_entry.dart';

class HiveBoxes {
  static const String categories = 'categoriesBox';
  static const String products = 'productsBox';
  static const String operationTypes = 'operationTypesBox';
  static const String operations = 'operationsBox';
  static const String operationProducts = 'operationProductsBox';
  static const String documents = 'documentsBox';
  static const String productImages = 'productImagesBox';
  static const String operationsHistory = 'operations_history_box';

  static Future<void> openAll() async {
    await Hive.openBox<Category>(categories);
    await Hive.openBox<Product>(products);
    await Hive.openBox<OperationType>(operationTypes);
    await Hive.openBox<Operation>(operations);
    await Hive.openBox<OperationProduct>(operationProducts);
    await Hive.openBox<Document>(documents);
    await Hive.openBox<ProductImage>(productImages);
    await Hive.openBox<OperationHistoryCacheEntry>(operationsHistory);
  }
}

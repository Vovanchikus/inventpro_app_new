import 'package:hive/hive.dart';
import 'package:testing_app/models/product_image.dart';
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

  // Новый бокс для хранения изображений товаров
  static const String productImages = 'productImages';

  static Future<void> openAll() async {
    await Hive.openBox<Category>(categories);
    await Hive.openBox<Product>(products);
    await Hive.openBox<OperationType>(operationTypes);
    await Hive.openBox<Operation>(operations);
    await Hive.openBox<OperationProduct>(operationProducts);
    await Hive.openBox<Document>(documents);

    // Можно сразу открыть новый бокс при старте
    await Hive.openBox<ProductImage>(productImages);
  }
}

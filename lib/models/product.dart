import 'package:hive/hive.dart';
part 'product.g.dart';

@HiveType(typeId: 1)
class Product extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String invNumber;

  @HiveField(3)
  String unit;

  @HiveField(4)
  double quantity;

  @HiveField(5)
  double price;

  @HiveField(6)
  double sum;

  @HiveField(7)
  int categoryId;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  DateTime createdAt;

  // 🔹 Новое поле для списка изображений
  @HiveField(10)
  List<String> images;

  Product({
    required this.id,
    required this.name,
    required this.invNumber,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.sum,
    required this.categoryId,
    required this.updatedAt,
    required this.createdAt,
    this.images = const [],
  });
}

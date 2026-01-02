import 'package:hive/hive.dart';

part 'product_image.g.dart';

@HiveType(typeId: 6)
class ProductImage extends HiveObject {
  @HiveField(0)
  String localPath;

  @HiveField(1)
  String? serverUrl;

  @HiveField(2)
  bool isSynced;

  @HiveField(3)
  bool isNew;

  @HiveField(4)
  int productId; // добавляем привязку к продукту

  ProductImage({
    required this.localPath,
    this.serverUrl,
    this.isSynced = false,
    this.isNew = true,
    required this.productId,
  });
}

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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
  int productId;

  @HiveField(5)
  double uploadProgress;

  @HiveField(6)
  String clientId; // 🔑 уникальный ID

  @HiveField(7)
  bool isUploading; // защита от повторной отправки

  ProductImage({
    required this.localPath,
    this.serverUrl,
    this.isSynced = false,
    this.isNew = true,
    required this.productId,
    this.uploadProgress = 0.0,
    String? clientId,
    this.isUploading = false,
  }) : clientId = clientId ?? const Uuid().v4();
}

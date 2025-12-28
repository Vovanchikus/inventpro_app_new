import 'package:hive/hive.dart';
part 'operation_product.g.dart';

@HiveType(typeId: 4)
class OperationProduct extends HiveObject {
  @HiveField(0)
  int operationId;

  @HiveField(1)
  int productId;

  @HiveField(2)
  double quantity;

  @HiveField(3)
  double sum;

  @HiveField(4)
  String? counteragent;

  OperationProduct({
    required this.operationId,
    required this.productId,
    required this.quantity,
    required this.sum,
    this.counteragent,
  });
}

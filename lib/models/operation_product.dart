import 'package:hive/hive.dart';
import 'product.dart';
import 'operation.dart';

part 'operation_product.g.dart';

@HiveType(typeId: 4)
class OperationProduct extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  Product? product;

  @HiveField(2)
  Operation? operation;

  @HiveField(3)
  String? counteragent;

  @HiveField(4)
  double? quantity;

  @HiveField(5)
  String? docDate;

  @HiveField(6)
  String? docName;

  @HiveField(7)
  String? docNum;

  OperationProduct({
    required this.id,
    this.product,
    this.operation,
    this.counteragent,
    this.quantity,
    this.docDate,
    this.docName,
    this.docNum,
  });
}

import 'package:meta/meta.dart';

const Map<int, int> operationPolarity = <int, int>{
  1: 1, // Приход
  2: -1, // Передача
  3: -1, // Списание
};

const int importOperationTypeId = 4;

@immutable
class OperationProductEntity {
  const OperationProductEntity({
    required this.id,
    required this.name,
    required this.unit,
    required this.inventoryNumber,
    required this.price,
  });

  final int id;
  final String name;
  final String unit;
  final String inventoryNumber;
  final double price;
}

@immutable
class OperationItemEntity {
  const OperationItemEntity({
    required this.id,
    required this.product,
    required this.operationId,
    required this.operationTypeId,
    required this.operationTypeName,
    required this.counteragent,
    required this.quantity,
    required this.docDate,
    required this.docName,
    required this.docNum,
  });

  final int id;
  final OperationProductEntity product;
  final int operationId;
  final int operationTypeId;
  final String operationTypeName;
  final String counteragent;
  final double quantity;
  final DateTime? docDate;
  final String? docName;
  final String? docNum;

  double signedQuantity() {
    final multiplier = operationPolarity[operationTypeId] ?? -1;
    return quantity * multiplier;
  }
}

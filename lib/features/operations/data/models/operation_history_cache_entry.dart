import 'package:hive/hive.dart';

import 'operation_history_item_dto.dart';

class OperationHistoryCacheEntry {
  const OperationHistoryCacheEntry({
    required this.id,
    required this.operationId,
    required this.operationTypeId,
    required this.operationTypeName,
    required this.counteragent,
    required this.quantity,
    required this.docDate,
    required this.docName,
    required this.docNum,
    required this.productId,
    required this.productName,
    required this.productUnit,
    required this.productInventoryNumber,
    required this.productPrice,
  });

  factory OperationHistoryCacheEntry.fromDto(OperationHistoryItemDto dto) {
    return OperationHistoryCacheEntry(
      id: dto.id,
      operationId: dto.operationId,
      operationTypeId: dto.operationTypeId,
      operationTypeName: dto.operationTypeName,
      counteragent: dto.counteragent,
      quantity: dto.quantity,
      docDate: dto.docDate,
      docName: dto.docName,
      docNum: dto.docNum,
      productId: dto.product.id,
      productName: dto.product.name,
      productUnit: dto.product.unit,
      productInventoryNumber: dto.product.inventoryNumber,
      productPrice: dto.product.price,
    );
  }

  final int id;
  final int operationId;
  final int operationTypeId;
  final String operationTypeName;
  final String counteragent;
  final double quantity;
  final String? docDate;
  final String? docName;
  final String? docNum;
  final int productId;
  final String productName;
  final String productUnit;
  final String productInventoryNumber;
  final double productPrice;

  OperationHistoryItemDto toDto() {
    return OperationHistoryItemDto(
      id: id,
      product: OperationHistoryProductDto(
        id: productId,
        name: productName,
        unit: productUnit,
        inventoryNumber: productInventoryNumber,
        price: productPrice,
      ),
      operationId: operationId,
      operationTypeId: operationTypeId,
      operationTypeName: operationTypeName,
      counteragent: counteragent,
      quantity: quantity,
      docDate: docDate,
      docName: docName,
      docNum: docNum,
    );
  }
}

class OperationHistoryCacheEntryAdapter
    extends TypeAdapter<OperationHistoryCacheEntry> {
  @override
  final int typeId = 215;

  @override
  OperationHistoryCacheEntry read(BinaryReader reader) {
    return OperationHistoryCacheEntry(
      id: reader.readInt(),
      operationId: reader.readInt(),
      operationTypeId: reader.readInt(),
      operationTypeName: reader.readString(),
      counteragent: reader.readString(),
      quantity: reader.readDouble(),
      docDate: reader.read(),
      docName: reader.read(),
      docNum: reader.read(),
      productId: reader.readInt(),
      productName: reader.readString(),
      productUnit: reader.readString(),
      productInventoryNumber: reader.readString(),
      productPrice: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, OperationHistoryCacheEntry obj) {
    writer
      ..writeInt(obj.id)
      ..writeInt(obj.operationId)
      ..writeInt(obj.operationTypeId)
      ..writeString(obj.operationTypeName)
      ..writeString(obj.counteragent)
      ..writeDouble(obj.quantity)
      ..write(obj.docDate)
      ..write(obj.docName)
      ..write(obj.docNum)
      ..writeInt(obj.productId)
      ..writeString(obj.productName)
      ..writeString(obj.productUnit)
      ..writeString(obj.productInventoryNumber)
      ..writeDouble(obj.productPrice);
  }
}

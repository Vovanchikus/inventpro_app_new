// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OperationProductAdapter extends TypeAdapter<OperationProduct> {
  @override
  final int typeId = 4;

  @override
  OperationProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OperationProduct(
      operationId: fields[0] as int,
      productId: fields[1] as int,
      quantity: fields[2] as double,
      sum: fields[3] as double,
      counteragent: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OperationProduct obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.operationId)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.sum)
      ..writeByte(4)
      ..write(obj.counteragent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

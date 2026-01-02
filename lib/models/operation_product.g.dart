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
      id: fields[0] as int,
      product: fields[1] as Product?,
      operation: fields[2] as Operation?,
      counteragent: fields[3] as String?,
      quantity: fields[4] as double?,
      docDate: fields[5] as String?,
      docName: fields[6] as String?,
      docNum: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OperationProduct obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.product)
      ..writeByte(2)
      ..write(obj.operation)
      ..writeByte(3)
      ..write(obj.counteragent)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.docDate)
      ..writeByte(6)
      ..write(obj.docName)
      ..writeByte(7)
      ..write(obj.docNum);
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

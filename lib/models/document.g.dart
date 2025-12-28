// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentAdapter extends TypeAdapter<Document> {
  @override
  final int typeId = 5;

  @override
  Document read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Document(
      id: fields[0] as int,
      operationId: fields[1] as int,
      name: fields[2] as String,
      number: fields[3] as String,
      date: fields[4] as DateTime?,
      purpose: fields[5] as String?,
      filePath: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Document obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.operationId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.number)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.purpose)
      ..writeByte(6)
      ..write(obj.filePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

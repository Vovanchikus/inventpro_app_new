// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_image.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductImageAdapter extends TypeAdapter<ProductImage> {
  @override
  final int typeId = 6;

  @override
  ProductImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductImage(
      localPath: fields[0] as String,
      serverUrl: fields[1] as String?,
      isSynced: fields[2] as bool,
      isNew: fields[3] as bool,
      productId: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProductImage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.localPath)
      ..writeByte(1)
      ..write(obj.serverUrl)
      ..writeByte(2)
      ..write(obj.isSynced)
      ..writeByte(3)
      ..write(obj.isNew)
      ..writeByte(4)
      ..write(obj.productId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductImageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

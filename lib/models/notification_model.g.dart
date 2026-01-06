// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationModelAdapter extends TypeAdapter<NotificationModel> {
  @override
  final int typeId = 13;

  @override
  NotificationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationModel(
      id: fields[0] as String,
      type: fields[1] as NotificationType,
      action: fields[2] as NotificationAction,
      title: fields[3] as String,
      description: fields[4] as String,
      timestamp: fields[5] as DateTime,
      status: fields[6] as NotificationStatus,
      isRead: fields[7] as bool,
      count: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.isRead)
      ..writeByte(8)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationTypeAdapter extends TypeAdapter<NotificationType> {
  @override
  final int typeId = 10;

  @override
  NotificationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationType.category;
      case 1:
        return NotificationType.product;
      case 2:
        return NotificationType.photo;
      case 3:
        return NotificationType.operation;
      default:
        return NotificationType.category;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationType obj) {
    switch (obj) {
      case NotificationType.category:
        writer.writeByte(0);
        break;
      case NotificationType.product:
        writer.writeByte(1);
        break;
      case NotificationType.photo:
        writer.writeByte(2);
        break;
      case NotificationType.operation:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationActionAdapter extends TypeAdapter<NotificationAction> {
  @override
  final int typeId = 11;

  @override
  NotificationAction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationAction.create;
      case 1:
        return NotificationAction.update;
      case 2:
        return NotificationAction.delete;
      case 3:
        return NotificationAction.sync;
      default:
        return NotificationAction.create;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationAction obj) {
    switch (obj) {
      case NotificationAction.create:
        writer.writeByte(0);
        break;
      case NotificationAction.update:
        writer.writeByte(1);
        break;
      case NotificationAction.delete:
        writer.writeByte(2);
        break;
      case NotificationAction.sync:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationStatusAdapter extends TypeAdapter<NotificationStatus> {
  @override
  final int typeId = 12;

  @override
  NotificationStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationStatus.success;
      case 1:
        return NotificationStatus.error;
      case 2:
        return NotificationStatus.pending;
      default:
        return NotificationStatus.success;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationStatus obj) {
    switch (obj) {
      case NotificationStatus.success:
        writer.writeByte(0);
        break;
      case NotificationStatus.error:
        writer.writeByte(1);
        break;
      case NotificationStatus.pending:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

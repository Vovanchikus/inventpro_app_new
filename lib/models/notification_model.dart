import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 10)
enum NotificationType {
  @HiveField(0)
  category,
  @HiveField(1)
  product,
  @HiveField(2)
  photo,
  @HiveField(3)
  operation,
}

@HiveType(typeId: 11)
enum NotificationAction {
  @HiveField(0)
  create,
  @HiveField(1)
  update,
  @HiveField(2)
  delete,
  @HiveField(3)
  sync,
}

@HiveType(typeId: 12)
enum NotificationStatus {
  @HiveField(0)
  success,
  @HiveField(1)
  error,
  @HiveField(2)
  pending,
}

@HiveType(typeId: 13)
class NotificationModel {
  @HiveField(0)
  String id;

  @HiveField(1)
  NotificationType type;

  @HiveField(2)
  NotificationAction action;

  @HiveField(3)
  String title;

  @HiveField(4)
  String description;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  NotificationStatus status;

  @HiveField(7)
  bool isRead;

  @HiveField(8)
  int count;

  NotificationModel({
    required this.id,
    required this.type,
    required this.action,
    required this.title,
    required this.description,
    required this.timestamp,
    this.status = NotificationStatus.success,
    this.isRead = false,
    this.count = 1,
  });

  // Backwards compatibility with Map-based storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'action': action.toString().split('.').last,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'isRead': isRead,
      'count': count,
    };
  }

  factory NotificationModel.fromMap(Map map) {
    NotificationType _type = NotificationType.product;
    switch (map['type'] as String?) {
      case 'category':
        _type = NotificationType.category;
        break;
      case 'product':
        _type = NotificationType.product;
        break;
      case 'photo':
        _type = NotificationType.photo;
        break;
      case 'operation':
        _type = NotificationType.operation;
        break;
    }

    NotificationAction _action = NotificationAction.create;
    switch (map['action'] as String?) {
      case 'create':
        _action = NotificationAction.create;
        break;
      case 'update':
        _action = NotificationAction.update;
        break;
      case 'delete':
        _action = NotificationAction.delete;
        break;
      case 'sync':
        _action = NotificationAction.sync;
        break;
    }

    NotificationStatus _status = NotificationStatus.success;
    switch (map['status'] as String?) {
      case 'success':
        _status = NotificationStatus.success;
        break;
      case 'error':
        _status = NotificationStatus.error;
        break;
      case 'pending':
        _status = NotificationStatus.pending;
        break;
    }

    return NotificationModel(
      id: map['id'] as String,
      type: _type,
      action: _action,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      status: _status,
      isRead: map['isRead'] == true,
      count: (map['count'] is int)
          ? map['count'] as int
          : int.tryParse((map['count'] ?? '1').toString()) ?? 1,
    );
  }
}

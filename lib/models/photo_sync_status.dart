import 'notification_model.dart';

/// Локальные статусы синхронизации фото в приложении
enum PhotoSyncStatus {
  /// Фото добавлено локально, ожидает синхронизации
  pending,

  /// Фото загружается на сервер
  uploading,

  /// Загрузка приостановлена (нет сети или пользовательская пауза)
  paused,

  /// Успешно синхронизировано
  synced,

  /// Ошибка загрузки (реальная ошибка)
  error,
}

extension PhotoSyncStatusExt on PhotoSyncStatus {
  NotificationStatus toNotificationStatus() {
    switch (this) {
      case PhotoSyncStatus.pending:
        return NotificationStatus.pending;
      case PhotoSyncStatus.uploading:
        return NotificationStatus.uploading;
      case PhotoSyncStatus.paused:
        return NotificationStatus.pending;
      case PhotoSyncStatus.synced:
        return NotificationStatus.synced;
      case PhotoSyncStatus.error:
        return NotificationStatus.error;
    }
  }
}

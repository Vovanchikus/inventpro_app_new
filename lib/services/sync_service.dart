import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/operations/data/repositories/operation_history_repository.dart';
import '../models/notification_model.dart';
import 'api_service.dart';
import 'config.dart';
import 'image_sync_service.dart';
import 'notification_service.dart';

abstract class OperationsHistorySyncBridge {
  ValueListenable<bool> get isSyncingOperationsHistory;
  Stream<void> get operationsHistoryUpdates;
  Future<void> syncOperationsHistory({int retries});
}

enum SyncStep { idle, syncingData, syncingImages, completed, error }

class SyncService implements OperationsHistorySyncBridge {
  final ApiService apiService;
  final OperationHistoryRepository _operationHistoryRepository;

  /// Прогресс синхронизации (0.0 — 1.0)
  final ValueNotifier<double> progress = ValueNotifier(0.0);

  /// Текущий шаг синхронизации
  final ValueNotifier<SyncStep> step = ValueNotifier(SyncStep.idle);

  /// Текст текущего шага (для модалки)
  final ValueNotifier<String> statusText = ValueNotifier('');

  /// Таймаут только на подключение к серверу (для apiService.syncAll)
  final Duration connectionTimeout;

  /// Состояние синхронизации истории операций
  @override
  final ValueNotifier<bool> isSyncingOperationsHistory = ValueNotifier(false);

  final StreamController<void> _operationsHistoryUpdatesController =
      StreamController<void>.broadcast();
  Future<void>? _operationsHistorySyncFuture;

  static SyncService? _instance;

  SyncService({
    required this.apiService,
    OperationHistoryRepository? operationHistoryRepository,
    this.connectionTimeout = const Duration(seconds: 5),
  }) : _operationHistoryRepository =
           operationHistoryRepository ?? OperationHistoryRepository();

  static SyncService get instance {
    return _instance ??= SyncService(
      apiService: ApiService(baseUrl: Config.baseUrl),
    );
  }

  @override
  Stream<void> get operationsHistoryUpdates =>
      _operationsHistoryUpdatesController.stream;

  /// Главная точка синхронизации: данные + изображения
  Future<void> syncAll() async {
    step.value = SyncStep.syncingData;
    progress.value = 0.0;
    statusText.value = 'Проверка соединения с сервером...';

    try {
      // 🔹 Синхронизация данных с таймаутом на подключение
      final dataSyncFuture = apiService.syncAll();

      final List<NotificationModel> dataNotifications = await dataSyncFuture
          .timeout(
            connectionTimeout,
            onTimeout: () {
              throw TimeoutException('Нет подключения к серверу');
            },
          );

      // После успешной загрузки данных — уведомления будут созданы ниже

      // 🔹 Динамический прогресс по шагам данных
      final dataSteps = [
        'Синхронизация категорий',
        'Синхронизация товаров',
        'Синхронизация типов операций',
        'Синхронизация операций',
        'Синхронизация истории операций',
        'Синхронизация документов',
      ];

      double stepProgress = 0.0;
      final stepIncrement = 0.3 / dataSteps.length; // 30% от общего прогресса

      for (final s in dataSteps) {
        statusText.value = s;
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // имитация небольшого прогресса
        stepProgress += stepIncrement;
        progress.value = stepProgress;
      }

      await syncOperationsHistory(retries: 1);

      // 🔹 Синхронизация изображений
      step.value = SyncStep.syncingImages;
      statusText.value = 'Синхронизация изображений...';
      progress.value = 0.3;

      // Синхронизация изображений выполняется отдельно и больше не создаёт уведомления
      await ImageSyncService.syncAllImages();

      // Отправляем уведомления по данным через NotificationService
      for (final n in dataNotifications) {
        await NotificationService.addNotification(n);
      }

      // Завершающее уведомление о синхронизации
      await NotificationService.addNotification(
        NotificationModel(
          id: 'sync_complete_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.operation,
          action: NotificationAction.sync,
          title: 'Синхронизация завершена',
          description: 'Данные успешно синхронизированы',
          timestamp: DateTime.now(),
          status: NotificationStatus.success,
          isRead: false,
        ),
      );

      step.value = SyncStep.completed;
      statusText.value = 'Синхронизация завершена';
      progress.value = 1.0;
      debugPrint('[SyncService] ✅ Синхронизация завершена');
    } on TimeoutException catch (_) {
      step.value = SyncStep.error;
      progress.value = 0.0;
      statusText.value = 'Сервер недоступен (таймаут 5 секунд)';
      debugPrint('[SyncService] ❌ Таймаут синхронизации (нет подключения)');
    } catch (e) {
      step.value = SyncStep.error;
      progress.value = 0.0;
      statusText.value = 'Ошибка синхронизации';
      debugPrint('[SyncService] ❌ Ошибка синхронизации: $e');
    }
  }

  @override
  Future<void> syncOperationsHistory({int retries = 2}) {
    _operationsHistorySyncFuture ??= _performOperationsHistorySync(
      retries: retries,
    );
    return _operationsHistorySyncFuture!;
  }

  Future<void> _performOperationsHistorySync({int retries = 2}) async {
    if (isSyncingOperationsHistory.value) {
      return _operationsHistorySyncFuture ?? Future.value();
    }
    isSyncingOperationsHistory.value = true;
    int attempt = 0;
    try {
      while (true) {
        try {
          await _operationHistoryRepository.fetchHistory();
          _operationsHistoryUpdatesController.add(null);
          return;
        } catch (error) {
          attempt++;
          debugPrint(
            '[SyncService] Ошибка синхронизации истории ($attempt): $error',
          );
          if (attempt > retries) {
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    } finally {
      isSyncingOperationsHistory.value = false;
      _operationsHistorySyncFuture = null;
    }
  }
}

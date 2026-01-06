import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'api_service.dart';
import 'image_sync_service.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../boxes/hive_boxes.dart';

enum SyncStep { idle, syncingData, syncingImages, completed, error }

class SyncService {
  final ApiService apiService;

  /// Прогресс синхронизации (0.0 — 1.0)
  final ValueNotifier<double> progress = ValueNotifier(0.0);

  /// Текущий шаг синхронизации
  final ValueNotifier<SyncStep> step = ValueNotifier(SyncStep.idle);

  /// Текст текущего шага (для модалки)
  final ValueNotifier<String> statusText = ValueNotifier('');

  /// Таймаут только на подключение к серверу (для apiService.syncAll)
  final Duration connectionTimeout;

  SyncService({
    required this.apiService,
    this.connectionTimeout = const Duration(seconds: 5),
  });

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

      // 🔹 Синхронизация изображений
      step.value = SyncStep.syncingImages;
      statusText.value = 'Синхронизация изображений...';
      progress.value = 0.3;

      // Синхронизация изображений: получаем уведомления о скачанных картинках
      final imageNotifications = await ImageSyncService.syncAllImages();

      // Комбинируем уведомления от данных и от изображений
      final allNotifications = <NotificationModel>[];
      allNotifications.addAll(dataNotifications);
      allNotifications.addAll(imageNotifications);

      // Отправляем уведомления через NotificationService
      for (final n in allNotifications) {
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
}

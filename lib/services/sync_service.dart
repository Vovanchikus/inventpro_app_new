import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'api_service.dart';
import 'image_sync_service.dart';
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

      final result = await dataSyncFuture.timeout(
        connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Нет подключения к серверу');
        },
      );

      if (result != SyncStatus.success) {
        step.value = SyncStep.error;
        statusText.value = 'Ошибка синхронизации данных';
        debugPrint(
          '[SyncService] ❌ Синхронизация данных завершилась с ошибкой',
        );
        return;
      }

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

      final Box<ProductImage> imageBox = Hive.box<ProductImage>(
        HiveBoxes.productImages,
      );
      final Box<Product> productBox = Hive.box<Product>(HiveBoxes.products);

      final images = imageBox.values.toList();
      final totalImages = images.length;

      if (totalImages == 0) {
        statusText.value = 'Нет изображений для синхронизации';
        step.value = SyncStep.completed;
        progress.value = 1.0;
        return;
      }

      int completedImages = 0;

      // Синхронизация картинок через ImageSyncService
      for (final img in images) {
        statusText.value =
            'Синхронизация изображения ${completedImages + 1} из $totalImages';
        await ImageSyncService.syncSingleImage(img);
        completedImages++;
        progress.value = 0.3 + (completedImages / totalImages) * 0.7;
      }

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

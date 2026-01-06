// image_sync_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../boxes/hive_boxes.dart';
import '../models/product_image.dart';
import '../models/product.dart';
import '../models/notification_model.dart';
import 'config.dart';

class ImageSyncService {
  /// 🔥 Главная точка синхронизации
  static Future<List<NotificationModel>> syncAllImages() async {
    print('================ IMAGE SYNC STARTED ================');

    final box = Hive.box<ProductImage>(HiveBoxes.productImages);
    final productBox = Hive.box<Product>(HiveBoxes.products);

    print('[SYNC] Локальных изображений в Hive: ${box.length}');
    final List<NotificationModel> notifications = [];

    // 1️⃣ Синхронизация с сервера
    final downloaded = await _syncFromServer(box, productBox);
    notifications.addAll(downloaded);

    // 2️⃣ Загрузка новых локальных изображений
    final unsynced = box.values.where((img) => img.isNew).toList();
    print(
      '[SYNC] Новых локальных изображений для загрузки: ${unsynced.length}',
    );

    for (final img in unsynced) {
      _uploadImage(img, productBox);
    }

    print('================ IMAGE SYNC FINISHED ================');
    return notifications;
  }

  /// Синхронизировать один объект изображения (используется SyncService)
  static Future<void> syncSingleImage(ProductImage img) async {
    final productBox = Hive.box<Product>(HiveBoxes.products);

    // Если уже синхронизировано с сервером — ничего не делаем
    if (img.isSynced && img.serverUrl != null) {
      print('[SYNC SINGLE] ⏭ Уже синхронизировано: ${img.localPath}');
      return;
    }

    // Если это локальное новое изображение — загружаем
    await _uploadImage(img, productBox);
  }

  /// ➕ Добавление фото локально (сразу отображается)
  static Future<void> addLocalImage(File file, int productId) async {
    final box = Hive.box<ProductImage>(HiveBoxes.productImages);
    final productBox = Hive.box<Product>(HiveBoxes.products);

    // Проверяем дубликаты по локальному пути
    final exists = box.values.any(
      (e) => e.localPath == file.path && e.productId == productId,
    );

    if (exists) {
      print('[LOCAL] ⏭ Изображение уже есть локально: ${file.path}');
      return;
    }

    final img = ProductImage(
      productId: productId,
      localPath: file.path,
      serverUrl: null,
      isNew: true,
      isSynced: false,
    );

    await box.add(img);

    // Добавляем в продукт для совместимости
    final product = productBox.get(productId);
    if (product != null && !product.images.contains(file.path)) {
      product.images = [...product.images, file.path];
      await productBox.put(product.id, product);
    }

    print('[LOCAL] Фото добавлено локально: ${file.path}');

    // 🔄 Запускаем асинхронную загрузку
    _uploadImage(img, productBox);
  }

  /// ⬆ Загрузка изображения на сервер
  static Future<void> _uploadImage(
    ProductImage img,
    Box<Product> productBox,
  ) async {
    if (img.isSynced && img.serverUrl != null) {
      print('[UPLOAD] ⏭ Уже загружено: ${img.localPath}');
      return;
    }

    print('[UPLOAD] Старт загрузки: ${img.localPath}');
    img.isUploading = true;
    img.uploadProgress = 0.0;
    await img.save();

    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);

      // ✅ Используем clientId из модели
      request.fields['product_id'] = img.productId.toString();
      request.fields['client_id'] = img.clientId;

      // ⚡ Имя файла должно быть "file", если сервер ожидает
      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      print('[UPLOAD] HTTP ${streamed.statusCode}: $body');

      if (streamed.statusCode != 200) {
        print('[UPLOAD] ❌ Ошибка HTTP ${streamed.statusCode}');
        img.isUploading = false;
        await img.save();
        return;
      }

      final json = jsonDecode(body);
      final serverUrl = json['data']?['url'] ?? json['data']?['serverUrl'];

      if (serverUrl == null) {
        print('[UPLOAD] ❌ serverUrl не вернулся');
        img.isUploading = false;
        await img.save();
        return;
      }

      // ✅ Обновляем модель
      img.serverUrl = serverUrl;
      img.isSynced = true;
      img.isNew = false;
      img.uploadProgress = 1.0;
      img.isUploading = false;
      await img.save();

      print('[UPLOAD] ✅ Загружено на сервер: $serverUrl');

      // Добавляем в продукт
      final product = productBox.get(img.productId);
      if (product != null && !product.images.contains(serverUrl)) {
        product.images = [...product.images, serverUrl];
        await productBox.put(product.id, product);
      }
    } catch (e) {
      print('[UPLOAD] ❌ Исключение: $e');
      img.isUploading = false;
      img.uploadProgress = 0.0;
      await img.save();
    }
  }

  /// 🔄 Синхронизация с сервера
  static Future<List<NotificationModel>> _syncFromServer(
    Box<ProductImage> box,
    Box<Product> productBox,
  ) async {
    print('[SERVER SYNC] Запрос изображений с сервера');

    final resp = await http.get(
      Uri.parse('${Config.baseUrl}/api/warehouse-products'),
    );

    if (resp.statusCode != 200) {
      print('[SERVER SYNC] ❌ Ошибка HTTP ${resp.statusCode}');
      return <NotificationModel>[];
    }

    final data = jsonDecode(resp.body);
    if (data['success'] != true) {
      print('[SERVER SYNC] ❌ success=false');
      return <NotificationModel>[];
    }

    final List<NotificationModel> notifications = [];
    for (final product in data['data']) {
      final int productId = product['id'];
      final List images = product['images'] ?? [];

      for (final img in images) {
        final serverUrl = img['url'];
        if (serverUrl == null) continue;

        final exists = box.values.any(
          (e) =>
              e.productId == productId &&
              (e.serverUrl == serverUrl ||
                  e.localPath.split('/').last == serverUrl.split('/').last),
        );

        if (exists) {
          print('⏭ [SYNC] Уже есть локально: $serverUrl');
          continue;
        }

        print('[SERVER SYNC] ⬇ Скачиваем: $serverUrl');
        final downloaded = await _downloadImage(
          productId,
          serverUrl,
          box,
          productBox,
        );
        if (downloaded != null) {
          notifications.add(
            NotificationModel(
              id: 'photo_sync_${downloaded.clientId}_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.photo,
              action: NotificationAction.create,
              title: 'Добавлено фото',
              description: 'Фото для товара ID ${downloaded.productId}',
              timestamp: DateTime.now(),
              status: NotificationStatus.success,
              isRead: false,
            ),
          );
        }
      }
    }

    // Проверка удалённых изображений
    for (final img in box.values.toList()) {
      if (img.serverUrl == null) continue;

      final check = await http.get(
        Uri.parse(
          '${Config.baseUrl}/api/check-image?url=${Uri.encodeComponent(img.serverUrl!)}',
        ),
      );

      if (check.statusCode == 404) {
        print('[SERVER SYNC] 🗑 Удалено на сервере: ${img.serverUrl}');

        final file = File(img.localPath);
        if (file.existsSync()) file.deleteSync();

        await img.delete();

        final product = productBox.get(img.productId);
        if (product != null) {
          product.images.remove(img.serverUrl);
          await productBox.put(product.id, product);
        }
      }
    }
    return notifications;
  }

  /// ⬇ Скачивание изображения с сервера
  static Future<ProductImage?> _downloadImage(
    int productId,
    String serverUrl,
    Box<ProductImage> box,
    Box<Product> productBox,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final productDir = Directory('${dir.path}/product_images/$productId');
      if (!productDir.existsSync()) productDir.createSync(recursive: true);

      final fileName = serverUrl.split('/').last;
      final filePath = '${productDir.path}/$fileName';

      // Проверяем локально дубликаты
      final existing = box.values.firstWhere(
        (e) =>
            e.productId == productId && e.localPath.split('/').last == fileName,
        orElse: () => ProductImage(
          productId: -1,
          localPath: '',
          isNew: false,
          isSynced: true,
        ),
      );
      if (existing.productId != -1) {
        print('[DOWNLOAD] ⏭ Уже есть локально: $fileName');
        existing.serverUrl = serverUrl;
        existing.isSynced = true;
        existing.isNew = false;
        await existing.save();
        return existing;
      }

      final resp = await http.get(Uri.parse(serverUrl));
      if (resp.statusCode != 200) {
        print('[DOWNLOAD] ❌ Ошибка загрузки $serverUrl');
        return null;
      }

      final file = File(filePath);
      await file.writeAsBytes(resp.bodyBytes);

      final img = ProductImage(
        productId: productId,
        localPath: filePath,
        serverUrl: serverUrl,
        isNew: false,
        isSynced: true,
      );

      await box.add(img);

      final product = productBox.get(productId);
      if (product != null && !product.images.contains(serverUrl)) {
        product.images = [...product.images, serverUrl];
        await productBox.put(product.id, product);
      }

      print('[DOWNLOAD] ✅ Скачано: $filePath');
      return img;
    } catch (e) {
      print('[DOWNLOAD] ❌ Исключение: $e');
      return null;
    }
  }
}

// image_sync_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../boxes/hive_boxes.dart';
import '../models/product_image.dart';
import '../models/product.dart';
import 'config.dart';

class ImageSyncService {
  /// 🔥 Главная точка синхронизации
  static Future<void> syncAllImages() async {
    print('================ IMAGE SYNC STARTED ================');

    final box = Hive.box<ProductImage>(HiveBoxes.productImages);
    final productBox = Hive.box<Product>(HiveBoxes.products);

    print('[SYNC] Локальных изображений в Hive: ${box.length}');

    // 1️⃣ Синхронизация с сервера
    await _syncFromServer(box, productBox);

    // 2️⃣ Загрузка новых локальных изображений
    final unsynced = box.values.where((img) => img.isNew).toList();
    print(
      '[SYNC] Новых локальных изображений для загрузки: ${unsynced.length}',
    );

    for (final img in unsynced) {
      _uploadImage(
        img,
        productBox,
      ); // 🔄 Запускаем без await, чтобы работало как очередь
    }

    print('================ IMAGE SYNC FINISHED ================');
  }

  /// ➕ Добавление фото локально (сразу отображается)
  static Future<void> addLocalImage(File file, int productId) async {
    final box = Hive.box<ProductImage>(HiveBoxes.productImages);
    final productBox = Hive.box<Product>(HiveBoxes.products);

    final img = ProductImage(
      productId: productId,
      localPath: file.path,
      serverUrl: null,
      isNew: true,
      isSynced: false,
    );

    await box.add(img);

    // Добавляем в продукт сразу (для отображения)
    final product = productBox.get(productId);
    if (product != null) {
      product.images = [
        ...product.images,
        file.path,
      ]; // локальный путь добавляем
      await productBox.put(product.id, product);
    }

    print('[LOCAL] Фото добавлено локально: ${file.path}');

    // 🔄 Запускаем асинхронную загрузку в фоне
    _uploadImage(img, productBox);
  }

  /// ⬆ Загрузка изображения на сервер
  static Future<void> _uploadImage(
    ProductImage img,
    Box<Product> productBox,
  ) async {
    // 🔒 Защита от повторной загрузки
    if (img.isSynced == true && img.serverUrl != null) {
      print('[UPLOAD] ⏭ Уже загружено, пропуск: ${img.localPath}');
      return;
    }

    print('[UPLOAD] Старт загрузки: ${img.localPath}');

    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['product_id'] = img.productId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final response = await request.send();
      final body = utf8.decode(await response.stream.toBytes());

      if (response.statusCode != 200) {
        print('[UPLOAD] ❌ Ошибка HTTP ${response.statusCode}');
        return;
      }

      final json = jsonDecode(body);
      final serverUrl = json['data']?['url'] ?? json['data']?['serverUrl'];
      if (serverUrl == null) {
        print('[UPLOAD] ❌ serverUrl не вернулся');
        return;
      }

      img.serverUrl = serverUrl;
      img.isSynced = true;
      img.isNew = false;
      await img.save();

      print('[UPLOAD] ✅ Загружено на сервер: $serverUrl');

      final product = productBox.get(img.productId);
      if (product != null) {
        // Заменяем локальный путь на serverUrl, но локальный путь остаётся для отображения
        if (!product.images.contains(serverUrl)) {
          product.images = [...product.images, serverUrl];
          await productBox.put(product.id, product);
          print('[UPLOAD] 🧩 Обновлён Product.images');
        }
      }
    } catch (e) {
      print('[UPLOAD] ❌ Исключение: $e');
    }
  }

  /// 🔄 Синхронизация с сервера
  static Future<void> _syncFromServer(
    Box<ProductImage> box,
    Box<Product> productBox,
  ) async {
    print('[SERVER SYNC] Запрос изображений с сервера');

    final resp = await http.get(
      Uri.parse('${Config.baseUrl}/api/warehouse-products'),
    );

    if (resp.statusCode != 200) {
      print('[SERVER SYNC] ❌ Ошибка HTTP ${resp.statusCode}');
      return;
    }

    final data = jsonDecode(resp.body);
    if (data['success'] != true) {
      print('[SERVER SYNC] ❌ success=false');
      return;
    }

    for (final product in data['data']) {
      final int productId = product['id'];
      final List images = product['images'] ?? [];

      print(
        '[SERVER SYNC] Товар $productId | Фото на сервере: ${images.length}',
      );

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

        print('[SERVER SYNC] ⬇ Скачиваем новое изображение: $serverUrl');
        await _downloadImage(productId, serverUrl, box, productBox);
      }
    }

    // Проверяем удалённые изображения
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
        if (file.existsSync()) {
          file.deleteSync();
          print('[SERVER SYNC] 🗑 Файл удалён локально');
        }

        await img.delete();

        final product = productBox.get(img.productId);
        if (product != null) {
          product.images.remove(img.serverUrl);
          productBox.put(product.id, product);
          print('[SERVER SYNC] 🧩 Product.images обновлён');
        }
      }
    }
  }

  /// ⬇ Скачивание изображения с сервера
  static Future<void> _downloadImage(
    int productId,
    String serverUrl,
    Box<ProductImage> box,
    Box<Product> productBox,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final productDir = Directory('${dir.path}/product_images/$productId');

      if (!productDir.existsSync()) {
        productDir.createSync(recursive: true);
      }

      final fileName = serverUrl.split('/').last;
      final filePath = '${productDir.path}/$fileName';

      final resp = await http.get(Uri.parse(serverUrl));
      if (resp.statusCode != 200) {
        print('[DOWNLOAD] ❌ Ошибка загрузки $serverUrl');
        return;
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

      print('[DOWNLOAD] ✅ Скачано: $filePath');

      final product = productBox.get(productId);
      if (product != null && !product.images.contains(serverUrl)) {
        product.images = [...product.images, serverUrl];
        productBox.put(product.id, product);
        print('[DOWNLOAD] 🧩 Product.images обновлён');
      }
    } catch (e) {
      print('[DOWNLOAD] ❌ Исключение: $e');
    }
  }
}

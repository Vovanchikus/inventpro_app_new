import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:testing_app/boxes/hive_boxes.dart';
import 'package:testing_app/models/product.dart';
import 'package:testing_app/models/product_image.dart';
import 'package:testing_app/services/config.dart';

class ImageSyncService {
  /// Синхронизация всех локальных фото с сервером
  static Future<void> syncAllImages() async {
    final box = Hive.box<ProductImage>(HiveBoxes.productImages);
    final unsynced = box.values.where((img) => img.isNew).toList();

    if (unsynced.isEmpty) {
      print('=== No images to sync ===');
      return;
    }

    print('=== Syncing ${unsynced.length} images ===');

    for (final img in unsynced) {
      await _uploadImage(img, box);
    }

    print('=== Image sync queue complete ===');
  }

  static Future<void> _uploadImage(
    ProductImage img,
    Box<ProductImage> box,
  ) async {
    try {
      final uri = Uri.parse('${Config.baseUrl}/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['product_id'] = img.productId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', img.localPath),
      );

      final resp = await request.send();
      final respBody = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        final data = jsonDecode(respBody);
        img.isNew = false;
        img.isSynced = true;
        if (data['success'] == true && data['data']?['serverUrl'] != null) {
          img.serverUrl = data['data']['serverUrl'];
        }
        if (img.isInBox) img.save();
        print('Image synced: ${img.productId}');
      } else {
        print('Error syncing image ${img.productId}');
      }
    } catch (e) {
      print('Exception syncing image ${img.productId}: $e');
    }
  }

  /// Удаление локальных фото, которых нет на сервере
  static Future<void> removeDeletedFromServer() async {
    final box = Hive.box<ProductImage>(HiveBoxes.productImages);

    for (final img in box.values.toList()) {
      if (!img.isNew && img.serverUrl != null) {
        try {
          // Проверяем реальный статус фото на сервере
          final resp = await http.get(
            Uri.parse(
              '${Config.baseUrl}/api/check-image?url=${Uri.encodeComponent(img.serverUrl!)}',
            ),
          );
          if (resp.statusCode == 404) {
            // Удаляем локальный файл
            final file = File(img.localPath);
            if (file.existsSync()) file.deleteSync();
            img.delete();
            print('Removed local image no longer on server: ${img.localPath}');
          }
        } catch (e) {
          print('Error checking image on server: $e');
        }
      }
    }
  }
}

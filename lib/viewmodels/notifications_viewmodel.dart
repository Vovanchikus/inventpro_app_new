import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsViewModel extends ChangeNotifier {
  final List<NotificationModel> _items = [];
  bool isLoading = false;
  Box? _box;
  StreamSubscription? _boxSub;

  List<NotificationModel> get all => List.unmodifiable(_items);

  // Отфильтрованные списки для вкладок
  List<NotificationModel> get categories =>
      _items.where((e) => e.type == NotificationType.category).toList();

  List<NotificationModel> get products =>
      _items.where((e) => e.type == NotificationType.product).toList();

  List<NotificationModel> get operations =>
      _items.where((e) => e.type == NotificationType.operation).toList();

  // Непрочитанные счётчики для вкладок и общий
  int get unreadCategories => _items
      .where((e) => e.type == NotificationType.category && !e.isRead)
      .fold(0, (s, e) => s + e.count);

  int get unreadProducts => _items
      .where((e) => e.type == NotificationType.product && !e.isRead)
      .fold(0, (s, e) => s + e.count);

  int get unreadOperations => _items
      .where((e) => e.type == NotificationType.operation && !e.isRead)
      .fold(0, (s, e) => s + e.count);

  int get unreadTotal => unreadCategories + unreadProducts + unreadOperations;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    // Открываем box уведомлений через NotificationService
    _box = await Hive.openBox(NotificationService.boxName);

    // Подписываемся на изменения в box, чтобы автоматически обновлять UI
    listenToBox();

    // Небольшая задержка для UX
    await Future.delayed(const Duration(milliseconds: 100));

    _reloadFromBox();

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();

  void _reloadFromBox() {
    _items.clear();
    if (_box == null) return;
    for (final v in _box!.values) {
      if (v is NotificationModel) {
        _items.add(v);
      } else if (v is Map) {
        try {
          _items.add(NotificationModel.fromMap(v));
        } catch (_) {}
      }
    }
    // сортируем по timestamp — новые сверху
    _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  /// Пометить все уведомления прочитанными
  Future<void> markAllRead() async {
    await NotificationService.markAllRead();
    // обновим локальный стейт
    _reloadFromBox();
  }

  /// Пометить прочитанными уведомления конкретного типа (используется при открытии вкладке)
  Future<void> markReadByType(NotificationType type) async {
    await NotificationService.markReadByType(type);
    _reloadFromBox();
  }

  /// Очистить историю через ViewModel
  Future<void> clearAll() async {
    await NotificationService.clearAll();
    _reloadFromBox();
  }

  /// Подписка на изменения box (если нужно)
  void listenToBox() {
    if (_box == null) return;
    _boxSub = _box!.watch().listen((_) => _reloadFromBox());
  }

  void disposeListener() {
    if (_box == null) return;
    try {
      _boxSub?.cancel();
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_model.dart';
import '../viewmodels/notifications_viewmodel.dart';
import '../theme/colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  late final NotificationsViewModel vm;
  late final TabController _tabController;
  final List<Tab> tabs = const [
    Tab(text: 'Категории'),
    Tab(text: 'Товары'),
    Tab(text: 'Фотографии'),
    Tab(text: 'Операции'),
  ];

  @override
  void initState() {
    super.initState();
    vm = NotificationsViewModel();
    _tabController = TabController(length: tabs.length, vsync: this);
    vm.addListener(_vmListener);
    vm.load().then((_) {
      // Подписка на обновления box
      vm.listenToBox();
    });
    // Помечаем прочитанными уведомления для вкладки при переключении
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final idx = _tabController.index;
        NotificationType? t;
        switch (idx) {
          case 0:
            t = NotificationType.category;
            break;
          case 1:
            t = NotificationType.product;
            break;
          case 2:
            t = NotificationType.photo;
            break;
          case 3:
            t = NotificationType.operation;
            break;
        }
        if (t != null) {
          vm.markReadByType(t);
        }
      }
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю'),
        content: const Text(
          'Вы уверены, что хотите удалить всю историю уведомлений?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await vm.clearAll();
    }
  }

  void _vmListener() => setState(() {});

  @override
  void dispose() {
    vm.removeListener(_vmListener);
    vm.disposeListener();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => vm.refresh();

  Widget _buildEmpty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.category:
        return Icons.category_outlined;
      case NotificationType.product:
        return Icons.inventory_2_outlined;
      case NotificationType.photo:
        return Icons.camera_alt_outlined;
      case NotificationType.operation:
        return Icons.swap_horiz;
    }
  }

  Color _statusColor(NotificationStatus s) {
    switch (s) {
      case NotificationStatus.success:
        return Colors.green;
      case NotificationStatus.error:
        return Colors.red;
      case NotificationStatus.pending:
        return Colors.orange;
    }
  }

  Widget _buildList(List<NotificationModel> list, String emptyText) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) return _buildEmpty(emptyText);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, idx) {
        final n = list[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Card(
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.bgLight,
                child: Icon(_iconForType(n.type), color: AppColors.brand),
              ),
              title: Text(
                n.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(n.description),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('dd.MM.y HH:mm').format(n.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(n.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      describeEnum(n.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(n.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_forever),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            _tabWithBadge('Категории', vm.unreadCategories),
            _tabWithBadge('Товары', vm.unreadProducts),
            _tabWithBadge('Фотографии', vm.unreadPhotos),
            _tabWithBadge('Операции', vm.unreadOperations),
          ],
          isScrollable: false,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildList(vm.categories, 'Нет изменений в категориях'),
          ),
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildList(vm.products, 'Нет изменений в товарах'),
          ),
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildList(vm.photos, 'Нет изменений с фотографиями'),
          ),
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildList(vm.operations, 'Нет операций'),
          ),
        ],
      ),
    );
  }

  Widget _tabWithBadge(String label, int count) {
    final display = count <= 0 ? null : (count > 99 ? '99+' : count.toString());
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (display != null) ...[
            const SizedBox(width: 8),
            IgnorePointer(
              ignoring: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 20),
                child: Text(
                  display,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

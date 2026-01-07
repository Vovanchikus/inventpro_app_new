import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../boxes/hive_boxes.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_sync_card_model.dart';
import '../theme/colors.dart';
import '../viewmodels/images_sync_center_viewmodel.dart';
import '../widgets/sync/product_sync_card.dart';
import 'notifications_page.dart';
import 'product_screen.dart';

class ImagesSyncCenterScreen extends StatefulWidget {
  const ImagesSyncCenterScreen({super.key});

  @override
  State<ImagesSyncCenterScreen> createState() => _ImagesSyncCenterScreenState();
}

class _ImagesSyncCenterScreenState extends State<ImagesSyncCenterScreen> {
  late final ImagesSyncCenterViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ImagesSyncCenterViewModel()
      ..addListener(_onVmChanged)
      ..init();
  }

  void _onVmChanged() => setState(() {});

  @override
  void dispose() {
    _vm
      ..removeListener(_onVmChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _openProduct(ProductSyncCardModel card) async {
    final productBox = Hive.isBoxOpen(HiveBoxes.products)
        ? Hive.box<Product>(HiveBoxes.products)
        : await Hive.openBox<Product>(HiveBoxes.products);
    final categoryBox = Hive.isBoxOpen(HiveBoxes.categories)
        ? Hive.box<Category>(HiveBoxes.categories)
        : await Hive.openBox<Category>(HiveBoxes.categories);

    final product = productBox.get(card.productId);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар не найден в локальном справочнике'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final categoryName =
        categoryBox.get(product.categoryId)?.name ??
        'Категория #${product.categoryId}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductScreen(
          productId: product.id,
          title: product.name,
          inventoryNumber: product.invNumber,
          price: product.price,
          quantity: product.quantity,
          total: product.sum,
          categoryPath: categoryName,
          images: product.images,
        ),
      ),
    );
  }

  Future<void> _retryProduct(ProductSyncCardModel card) async {
    try {
      await _vm.retryProduct(card.productId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось запустить синхронизацию: $e')),
      );
    }
  }

  Widget _buildBody() {
    if (_vm.isLoading && !_vm.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vm.cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: _vm.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.image_outlined, size: 48, color: AppColors.neutral400),
            SizedBox(height: 16),
            Text(
              'Нет изображений в очереди',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Как только вы добавите фото, здесь появится прогресс по каждому товару.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSubTitle),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        itemCount: _vm.cards.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          if (index == 0) return _Summary(vm: _vm);
          final card = _vm.cards[index - 1];
          return ProductSyncCard(
            data: card,
            onRetry: () => _retryProduct(card),
            onDetails: () => _openProduct(card),
            isRetrying: _vm.isProductRetrying(card.productId),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      appBar: AppBar(
        title: const Text('Центр синхронизации'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vm});

  final ImagesSyncCenterViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF233D7B), Color(0xFF4869C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Состояние синхронизации',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _SummaryItem(
                label: 'Pending',
                value: vm.totalPending,
                color: Colors.orangeAccent,
              ),
              _SummaryItem(
                label: 'Uploading',
                value: vm.totalUploading,
                color: Colors.lightBlueAccent,
              ),
              _SummaryItem(
                label: 'Ошибки',
                value: vm.totalErrors,
                color: Colors.redAccent,
              ),
              _SummaryItem(
                label: 'Синхронизировано',
                value: vm.totalSynced,
                color: Colors.greenAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

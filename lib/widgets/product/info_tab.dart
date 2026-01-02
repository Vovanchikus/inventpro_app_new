import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../models/product_image.dart';

class InfoTab extends StatelessWidget {
  final String title;
  final String inventoryNumber;
  final double price;
  final double quantity;
  final double total;
  final String categoryPath;

  const InfoTab({
    super.key,
    required this.title,
    required this.inventoryNumber,
    required this.price,
    required this.quantity,
    required this.total,
    required this.categoryPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final crumb in categoryPath.split('/')) ...[
              Text(crumb, style: const TextStyle(color: Colors.grey)),
              if (crumb != categoryPath.split('/').last)
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Инвентарный номер: $inventoryNumber',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _infoItem('Цена', price.toStringAsFixed(2)),
            _infoItem('Количество', quantity.toStringAsFixed(3)),
            _infoItem('Сумма', total.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Описание товара',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Подробное описание товара. Любой объём текста.'),
      ],
    );
  }

  Widget _infoItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ProductCard extends StatefulWidget {
  final String title;
  final String inventoryNumber;
  final double price;
  final double quantity; // Количество теперь double для 3 знаков после запятой
  final double total;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.title,
    required this.inventoryNumber,
    required this.price,
    required this.quantity,
    required this.total,
    this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isPressed ? 0.02 : 0.06),
              blurRadius: _isPressed ? 6 : 16,
              offset: Offset(0, _isPressed ? 3 : 8),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Название
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 4),
            // Инвентарный номер
            Text(
              widget.inventoryNumber,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.neutral400,
              ),
            ),
            const SizedBox(height: 12),
            // Нижний ряд: Цена | К-во | Сумма
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Цена', widget.price, AppColors.success, 2),
                _buildInfoColumn('К-во', widget.quantity, AppColors.brand, 3),
                _buildInfoColumn('Сумма', widget.total, AppColors.error, 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    double value,
    Color accent,
    int fractionDigits,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.neutral400,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween<double>(begin: 0, end: value),
          builder: (context, val, child) {
            return Text(
              val.toStringAsFixed(fractionDigits),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            );
          },
        ),
      ],
    );
  }
}

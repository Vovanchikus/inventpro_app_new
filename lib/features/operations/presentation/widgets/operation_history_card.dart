import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:testing_app/theme/colors.dart';

import '../viewmodels/operation_history_view_model.dart';
import '../../domain/entities/operation_item_entity.dart';

class OperationHistoryCard extends StatelessWidget {
  const OperationHistoryCard({
    super.key,
    required this.operationId,
    required this.items,
  });

  final int operationId;
  final List<OperationItemUiModel> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final primary = items.first.entity;
    final theme = Theme.of(context);
    final dateLabel = _formatDate(primary.docDate);
    final docTitle = _formatDocumentTitle(primary);

    final chipColor = _colorForOperationType(primary.operationTypeId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operation type chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  primary.operationTypeName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Date on the right
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Document title (big) + optional number
          Text(
            docTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          // Counteragent
          Text(
            'Контрагент: ${primary.counteragent.trim().isEmpty ? 'Не указан' : primary.counteragent}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSubTitle,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Products
          ...items.map((uiModel) => _ProductRow(model: uiModel)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Дата не указана';
    }
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _formatDocumentTitle(OperationItemEntity entity) {
    final name = (entity.docName ?? '').trim();
    final num = (entity.docNum ?? '').trim();
    if (name.isEmpty && num.isEmpty) {
      return entity.operationTypeName;
    }
    if (name.isEmpty) {
      return num.isEmpty ? entity.operationTypeName : '№$num';
    }
    return num.isEmpty ? name : '$name №$num';
  }

  Color _colorForOperationType(int typeId) {
    switch (typeId) {
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.error;
      default:
        return AppColors.brand;
    }
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.model});

  final OperationItemUiModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = model.entity.product;
    final quantityLabel = _formatQuantity(model);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: model.signSymbol == '+'
                ? AppColors.bgSuccess
                : AppColors.bgError,
            child: Text(
              model.signSymbol,
              style: theme.textTheme.titleMedium?.copyWith(
                color: model.signSymbol == '+'
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  product.inventoryNumber.isEmpty
                      ? 'Инвентарный номер отсутствует'
                      : product.inventoryNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubTitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quantity with tabular figures
          Text(
            quantityLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(OperationItemUiModel model) {
    final formatter = NumberFormat('#,##0.###', 'ru');
    final absQuantity = model.signedQuantity.abs();
    final formatted = formatter.format(absQuantity);
    final unit = model.entity.product.unit.isEmpty
        ? ''
        : ' ${model.entity.product.unit}';
    return '${model.signSymbol}$formatted$unit';
  }
}

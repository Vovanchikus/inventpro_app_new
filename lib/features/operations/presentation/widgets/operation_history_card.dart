import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final docLabel = _formatDocument(primary);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  primary.operationTypeName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '#$operationId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Контрагент: ${primary.counteragent.isEmpty ? 'Не указан' : primary.counteragent}',
            style: theme.textTheme.bodyMedium,
          ),
          if (docLabel != null) ...[
            const SizedBox(height: 4),
            Text(docLabel, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
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

  String? _formatDocument(OperationItemEntity entity) {
    final parts = <String>[];
    if ((entity.docName ?? '').isNotEmpty) {
      parts.add(entity.docName!.trim());
    }
    if ((entity.docNum ?? '').isNotEmpty) {
      parts.add('№ ${entity.docNum!.trim()}');
    }
    if (parts.isEmpty) {
      return null;
    }
    return 'Документ: ${parts.join(' ')}';
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
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Text(
              model.signSymbol,
              style: theme.textTheme.titleMedium?.copyWith(
                color: model.signSymbol == '+'
                    ? Colors.green.shade700
                    : Colors.red.shade600,
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
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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

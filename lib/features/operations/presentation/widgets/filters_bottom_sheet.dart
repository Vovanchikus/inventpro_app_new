import 'package:flutter/material.dart';
import 'package:testing_app/features/operations/presentation/viewmodels/operation_history_view_model.dart';
import 'package:testing_app/features/operations/domain/usecases/operation_history_usecases.dart';
import 'package:testing_app/features/operations/domain/entities/operation_item_entity.dart';
import 'package:testing_app/theme/colors.dart';

class FiltersBottomSheet extends StatefulWidget {
  const FiltersBottomSheet({
    super.key,
    required this.initialFilters,
    required this.availableYears,
    required this.availableOperationTypes,
    required this.availableCounteragents,
    required this.onApply,
    required this.onReset,
  });

  final OperationHistoryFilters initialFilters;
  final List<int> availableYears;
  final List<OperationTypeOption> availableOperationTypes;
  final List<String> availableCounteragents;
  final ValueChanged<OperationHistoryFilters> onApply;
  final VoidCallback onReset;

  @override
  State<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  late OperationHistoryFilters _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.initialFilters;
  }

  void _onYearChanged(int? year) {
    setState(
      () => _pending = OperationHistoryFilters(
        year: year,
        operationTypeId: _pending.operationTypeId,
        counteragent: _pending.counteragent,
      ),
    );
  }

  void _onTypeSelected(int? id) {
    setState(
      () => _pending = OperationHistoryFilters(
        year: _pending.year,
        operationTypeId: id,
        counteragent: _pending.counteragent,
      ),
    );
  }

  void _onCounteragentSelected(String? agent) {
    setState(
      () => _pending = OperationHistoryFilters(
        year: _pending.year,
        operationTypeId: _pending.operationTypeId,
        counteragent: agent,
      ),
    );
  }

  Color _typeColor(int id) {
    switch (id) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = widget.availableOperationTypes
        .where((t) => t.id != importOperationTypeId)
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Фильтры', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Год', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _pending.year == null
                            ? AppColors.brand
                            : theme.cardColor,
                        border: Border.all(
                          color: _pending.year == null
                              ? AppColors.brand
                              : theme.dividerColor.withAlpha(
                                  (0.3 * 255).round(),
                                ),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _onYearChanged(null),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              'Все годы',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _pending.year == null
                                    ? Colors.white
                                    : AppColors.textBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...widget.availableYears.map((y) {
                    final selected = _pending.year == y;
                    final bg = selected ? AppColors.brand : theme.cardColor;
                    final border = selected
                        ? AppColors.brand
                        : theme.dividerColor.withAlpha((0.3 * 255).round());
                    final txt = selected ? Colors.white : AppColors.textBody;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: bg,
                          border: Border.all(color: border),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _onYearChanged(selected ? null : y),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                y.toString(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: txt,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Тип операции', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _pending.operationTypeId == null
                          ? AppColors.brand
                          : theme.cardColor,
                      border: Border.all(
                        color: _pending.operationTypeId == null
                            ? AppColors.brand
                            : theme.dividerColor.withAlpha((0.3 * 255).round()),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _onTypeSelected(null),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            'Все',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _pending.operationTypeId == null
                                  ? Colors.white
                                  : AppColors.textBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...types.map((option) {
                  final selected = _pending.operationTypeId == option.id;
                  final base = _typeColor(option.id);
                  final bg = selected ? base : theme.cardColor;
                  final border = selected
                      ? base
                      : theme.dividerColor.withAlpha((0.3 * 255).round());
                  final txt = selected ? Colors.white : AppColors.textBody;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: bg,
                      border: Border.all(color: border),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            _onTypeSelected(selected ? null : option.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            option.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: txt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 12),
            Text('Контрагент', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: (_pending.counteragent == null)
                            ? AppColors.brand
                            : theme.cardColor,
                        border: Border.all(
                          color: (_pending.counteragent == null)
                              ? AppColors.brand
                              : theme.dividerColor.withAlpha(
                                  (0.3 * 255).round(),
                                ),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _onCounteragentSelected(null),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              'Все',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: (_pending.counteragent == null)
                                    ? Colors.white
                                    : AppColors.textBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...widget.availableCounteragents.map((agent) {
                    final selected =
                        (_pending.counteragent ?? '').trim() == agent.trim();
                    final bg = selected ? AppColors.brand : theme.cardColor;
                    final border = selected
                        ? AppColors.brand
                        : theme.dividerColor.withAlpha((0.3 * 255).round());
                    final txt = selected ? Colors.white : AppColors.textBody;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: bg,
                          border: Border.all(color: border),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _onCounteragentSelected(
                              selected ? null : agent,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                agent,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: txt,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.initialFilters.isEmpty
                        ? null
                        : widget.onReset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_pending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 6,
                      shadowColor: AppColors.brand.withAlpha(
                        (0.25 * 255).round(),
                      ),
                    ),
                    child: const Text(
                      'Применить',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

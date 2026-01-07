import 'package:flutter/material.dart';

import 'package:testing_app/features/operations/domain/usecases/operation_history_usecases.dart';
import 'package:testing_app/features/operations/presentation/viewmodels/operation_history_view_model.dart';
import 'package:testing_app/features/operations/presentation/widgets/operation_history_card.dart';
import 'package:testing_app/features/operations/data/repositories/operation_history_repository.dart';
import 'package:testing_app/theme/colors.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late final OperationHistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = OperationHistoryViewModel(
      repository: OperationHistoryRepository(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadHistory();
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      appBar: AppBar(
        title: const Text('История операций (новая)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _viewModel.isLoading ? null : _viewModel.loadHistory,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (_, __) => RefreshIndicator(
          onRefresh: _viewModel.loadHistory,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.groupedData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_viewModel.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            'Не удалось загрузить историю',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _viewModel.error!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _viewModel.loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Попробовать снова'),
          ),
        ],
      );
    }

    if (_viewModel.groupedData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('История операций пуста'),
        ],
      );
    }

    final groups = _viewModel.groupedData;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: groups.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _FiltersPanel(
            viewModel: _viewModel,
            onFilterChanged: _applyFilter,
          );
        }
        if (index == 1) {
          return _CounteragentSummary(
            counteragentTotals: _viewModel.counteragentTotals,
          );
        }
        final group = groups[index - 2];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.year.toString(),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...group.operations.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OperationHistoryCard(
                    operationId: entry.key,
                    items: entry.value,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyFilter(OperationHistoryFilters filters) {
    _viewModel.applyFilters(filters);
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({required this.viewModel, required this.onFilterChanged});

  final OperationHistoryViewModel viewModel;
  final ValueChanged<OperationHistoryFilters> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filters = viewModel.filters;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Фильтры', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DropdownFilter<int?>(
                  label: 'Год',
                  value: filters.year,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Все годы'),
                    ),
                    ...viewModel.availableYears
                        .map(
                          (year) => DropdownMenuItem<int?>(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(),
                  ],
                  onChanged: (year) => onFilterChanged(
                    OperationHistoryFilters(
                      year: year,
                      operationTypeId: filters.operationTypeId,
                      counteragent: filters.counteragent,
                    ),
                  ),
                ),
                _DropdownFilter<int?>(
                  label: 'Тип операции',
                  value: filters.operationTypeId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Все типы'),
                    ),
                    ...viewModel.availableOperationTypes
                        .map(
                          (option) => DropdownMenuItem<int?>(
                            value: option.id,
                            child: Text(option.name),
                          ),
                        )
                        .toList(),
                  ],
                  onChanged: (typeId) => onFilterChanged(
                    OperationHistoryFilters(
                      year: filters.year,
                      operationTypeId: typeId,
                      counteragent: filters.counteragent,
                    ),
                  ),
                ),
                _DropdownFilter<String?>(
                  label: 'Контрагент',
                  value: filters.counteragent,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все контрагенты'),
                    ),
                    ...viewModel.availableCounteragents
                        .map(
                          (counteragent) => DropdownMenuItem<String?>(
                            value: counteragent,
                            child: Text(counteragent),
                          ),
                        )
                        .toList(),
                  ],
                  onChanged: (counteragent) => onFilterChanged(
                    OperationHistoryFilters(
                      year: filters.year,
                      operationTypeId: filters.operationTypeId,
                      counteragent: counteragent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: filters.isEmpty ? null : viewModel.resetFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Сбросить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounteragentSummary extends StatelessWidget {
  const _CounteragentSummary({required this.counteragentTotals});

  final Map<String, double> counteragentTotals;

  @override
  Widget build(BuildContext context) {
    if (counteragentTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сальдо по контрагентам',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: counteragentTotals.entries.map((entry) {
                final value = entry.value;
                final sign = value >= 0 ? '+' : '-';
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: value >= 0
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Text(
                      sign,
                      style: TextStyle(
                        color: value >= 0
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    '${entry.key}: ${value.abs().toStringAsFixed(2)}',
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

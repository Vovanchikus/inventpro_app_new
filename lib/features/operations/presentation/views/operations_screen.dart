import 'package:flutter/material.dart';
import 'dart:async';

import 'package:testing_app/features/operations/presentation/viewmodels/operation_history_view_model.dart';
import 'package:testing_app/features/operations/presentation/widgets/operation_history_card.dart';
import 'package:testing_app/features/operations/presentation/widgets/filters_bottom_sheet.dart';
import 'package:testing_app/features/operations/data/repositories/operation_history_repository.dart';
import 'package:testing_app/services/sync_service.dart';
import 'package:testing_app/theme/colors.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late final OperationHistoryViewModel _viewModel;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _viewModel = OperationHistoryViewModel(
      repository: OperationHistoryRepository(),
      syncBridge: SyncService.instance,
    );
    _searchController = TextEditingController(
      text: _viewModel.searchQuery ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadHistory();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgApp,
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildContentArea(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final searchField = _viewModel.searchField;
    final hint = searchField == SearchField.product
        ? 'Поиск по товарам'
        : 'Поиск по документам';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SearchToggleIcon(
                          tooltip: 'Товар',
                          icon: Icons.shopping_bag,
                          selected: searchField == SearchField.product,
                          onTap: () => _viewModel.applySearch(
                            _searchController.text,
                            SearchField.product,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SearchToggleIcon(
                          tooltip: 'Документ',
                          icon: Icons.receipt_long,
                          selected: searchField == SearchField.document,
                          onTap: () => _viewModel.applySearch(
                            _searchController.text,
                            SearchField.document,
                          ),
                        ),
                      ],
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      _viewModel.applySearch(v, _viewModel.searchField);
                    },
                  );
                },
                onSubmitted: (v) =>
                    _viewModel.applySearch(v, _viewModel.searchField),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                _viewModel.openFiltersSheet();
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Wrap(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            child: FiltersBottomSheet(
                              initialFilters: _viewModel.filters,
                              availableYears: _viewModel.availableYears,
                              availableOperationTypes:
                                  _viewModel.availableOperationTypes,
                              availableCounteragents:
                                  _viewModel.availableCounteragents,
                              onApply: (f) {
                                _viewModel.applyFilters(f);
                                Navigator.of(ctx).pop();
                              },
                              onReset: () {
                                _viewModel.resetFilters();
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                _viewModel.closeFiltersSheet();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgLight,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
                elevation: 6,
                shadowColor: AppColors.brand.withOpacity(0.25),
              ),
              child: const Icon(
                Icons.filter_list,
                color: AppColors.textTitle,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
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
          Text(
            'История обновляется автоматически при запуске приложения и через кнопку синхронизации в AppBar.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      );
    }

    final sections = <Widget>[
      if (_viewModel.isOffline) const _OfflineBanner(),
      if (_viewModel.isSyncing) const _SyncingIndicator(),
    ];

    if (_viewModel.groupedData.isEmpty) {
      sections.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.inbox, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('История операций пуста'),
              ],
            ),
          ),
        ),
      );
    } else {
      for (final group in _viewModel.groupedData) {
        sections.add(
          Padding(
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
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      children: sections,
    );
  }
}

class _SearchToggleIcon extends StatelessWidget {
  const _SearchToggleIcon({
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : AppColors.textBody;
    final bg = selected ? AppColors.brand : Colors.transparent;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: Border.all(
            color: selected
                ? AppColors.brand
                : AppColors.textBody.withOpacity(0.12),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Нет подключения к сети',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Нет подключения к сети — отображаются последние данные. Обновите данные через синхронизацию в верхнем AppBar.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncingIndicator extends StatelessWidget {
  const _SyncingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Синхронизация истории операций... данные остаются доступными.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

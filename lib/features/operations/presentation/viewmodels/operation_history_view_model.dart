import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../operations/data/models/operation_history_item_dto.dart';
import '../../../operations/data/repositories/operation_history_repository.dart';
import '../../../operations/domain/entities/operation_item_entity.dart';
import '../../../operations/domain/usecases/operation_history_usecases.dart';

class OperationItemUiModel {
  const OperationItemUiModel({
    required this.entity,
    required this.signedQuantity,
    required this.signSymbol,
  });

  final OperationItemEntity entity;
  final double signedQuantity;
  final String signSymbol;
}

class OperationHistoryGroup {
  const OperationHistoryGroup({required this.year, required this.operations});

  final int year;
  final LinkedHashMap<int, List<OperationItemUiModel>> operations;
}

class OperationTypeOption {
  const OperationTypeOption({required this.id, required this.name});

  final int id;
  final String name;
}

class OperationHistoryViewModel extends ChangeNotifier {
  OperationHistoryViewModel({
    required OperationHistoryRepository repository,
    OperationHistoryUseCases? useCases,
    OperationTypePolarityResolver? resolver,
  }) : _repository = repository,
       _resolver = resolver ?? defaultPolarityResolver,
       _useCases =
           useCases ??
           OperationHistoryUseCases(
             resolver: resolver ?? defaultPolarityResolver,
           );

  final OperationHistoryRepository _repository;
  final OperationHistoryUseCases _useCases;
  final OperationTypePolarityResolver _resolver;

  bool _isLoading = false;
  List<OperationHistoryItemDto> _originalData = const [];
  List<OperationHistoryGroup> _groupedData = const [];
  Map<String, double> _counteragentTotals = const {};
  OperationHistoryFilters _filters = const OperationHistoryFilters();
  String? _error;
  List<int> _availableYears = const [];
  List<OperationTypeOption> _availableOperationTypes = const [];
  List<String> _availableCounteragents = const [];

  bool get isLoading => _isLoading;
  List<OperationHistoryItemDto> get originalData => _originalData;
  List<OperationHistoryGroup> get groupedData => _groupedData;
  Map<String, double> get counteragentTotals => _counteragentTotals;
  OperationHistoryFilters get filters => _filters;
  String? get error => _error;
  List<int> get availableYears => _availableYears;
  List<OperationTypeOption> get availableOperationTypes =>
      _availableOperationTypes;
  List<String> get availableCounteragents => _availableCounteragents;

  Future<void> loadHistory() async {
    _setLoading(true);
    _error = null;

    try {
      final dtoList = await _repository.fetchHistory();
      _originalData = dtoList;
      final entities = dtoList.map(_mapDtoToEntity).toList(growable: false);
      _recalculateAvailableFilters(entities);
      _applyFiltersInternal(entities, _filters);
    } catch (error) {
      _error = error.toString();
      _groupedData = const [];
      _counteragentTotals = const {};
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void applyFilters(OperationHistoryFilters filters) {
    _filters = filters;
    final entities = _originalData.map(_mapDtoToEntity).toList(growable: false);
    _recalculateAvailableFilters(entities);
    _applyFiltersInternal(entities, filters);
  }

  void resetFilters() {
    applyFilters(const OperationHistoryFilters());
  }

  void _applyFiltersInternal(
    List<OperationItemEntity> entities,
    OperationHistoryFilters filters,
  ) {
    final filtered = _useCases.applyFilters(entities, filters);
    _groupedData = _buildGroupedData(filtered);
    _counteragentTotals = _useCases.aggregateCounteragents(filtered);
    _error = null;
    notifyListeners();
  }

  List<OperationHistoryGroup> _buildGroupedData(
    List<OperationItemEntity> items,
  ) {
    final groups = <OperationHistoryGroup>[];
    final groupedByYear = _useCases.groupByYear(items);
    groupedByYear.forEach((year, yearItems) {
      final byOperation = _useCases.groupByOperationId(yearItems);
      final sortedEntries = byOperation.entries.toList()
        ..sort((a, b) {
          final firstDateA = a.value.first.docDate;
          final firstDateB = b.value.first.docDate;
          if (firstDateA == null && firstDateB == null) return 0;
          if (firstDateA == null) return 1;
          if (firstDateB == null) return -1;
          return firstDateB.compareTo(firstDateA);
        });
      final mapped = LinkedHashMap<int, List<OperationItemUiModel>>();
      for (final entry in sortedEntries) {
        final uiItems = entry.value
            .map((entity) {
              final signed = entity.signedQuantity(resolver: _resolver);
              return OperationItemUiModel(
                entity: entity,
                signedQuantity: signed,
                signSymbol: signed >= 0 ? '+' : '-',
              );
            })
            .toList(growable: false);
        mapped[entry.key] = uiItems;
      }
      groups.add(OperationHistoryGroup(year: year, operations: mapped));
    });
    return groups;
  }

  void _recalculateAvailableFilters(List<OperationItemEntity> entities) {
    final years = <int>{};
    final typeNames = <int, String>{};
    final counteragents = <String>{};

    for (final entity in entities) {
      final docYear = entity.docDate?.year;
      if (docYear != null) {
        years.add(docYear);
      }
      if (entity.operationTypeId != 0) {
        typeNames[entity.operationTypeId] = entity.operationTypeName;
      }
      final normalizedCounteragent = entity.counteragent.trim().isEmpty
          ? 'Не указан'
          : entity.counteragent.trim();
      counteragents.add(normalizedCounteragent);
    }

    final typeOptions =
        typeNames.entries
            .map(
              (entry) => OperationTypeOption(id: entry.key, name: entry.value),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    _availableYears = years.toList()..sort((a, b) => b.compareTo(a));
    _availableOperationTypes = typeOptions;
    _availableCounteragents = counteragents.toList()
      ..sort((a, b) => a.compareTo(b));
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  OperationItemEntity _mapDtoToEntity(OperationHistoryItemDto dto) {
    final product = OperationProductEntity(
      id: dto.product.id,
      name: dto.product.name,
      unit: dto.product.unit,
      inventoryNumber: dto.product.inventoryNumber,
      price: dto.product.price,
    );

    return OperationItemEntity(
      id: dto.id,
      product: product,
      operationId: dto.operationId,
      operationTypeId: dto.operationTypeId,
      operationTypeName: dto.operationTypeName,
      counteragent: dto.counteragent,
      quantity: dto.quantity,
      docDate: _parseDocDate(dto.docDate),
      docName: dto.docName,
      docNum: dto.docNum,
    );
  }

  DateTime? _parseDocDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) {
      return isoParsed;
    }

    try {
      return DateFormat('dd.MM.yyyy').parse(trimmed);
    } catch (_) {
      return null;
    }
  }
}

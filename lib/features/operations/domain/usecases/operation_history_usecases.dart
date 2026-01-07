import 'dart:collection';

import 'package:meta/meta.dart';

import '../entities/operation_item_entity.dart';

@immutable
class OperationHistoryFilters {
  const OperationHistoryFilters({
    this.year,
    this.operationTypeId,
    this.counteragent,
  });

  final int? year;
  final int? operationTypeId;
  final String? counteragent;

  bool get isEmpty =>
      year == null &&
      operationTypeId == null &&
      (counteragent == null || counteragent!.isEmpty);

  bool matches(OperationItemEntity item) {
    if (year != null) {
      final docYear = item.docDate?.year;
      if (docYear == null || docYear != year) {
        return false;
      }
    }
    if (operationTypeId != null && item.operationTypeId != operationTypeId) {
      return false;
    }
    if (counteragent != null && counteragent!.isNotEmpty) {
      final normalizedTarget = counteragent!.toLowerCase().trim();
      final normalizedItem = item.counteragent.toLowerCase().trim();
      if (normalizedItem != normalizedTarget) {
        return false;
      }
    }
    return true;
  }
}

class OperationHistoryUseCases {
  const OperationHistoryUseCases();

  List<OperationItemEntity> applyFilters(
    List<OperationItemEntity> items,
    OperationHistoryFilters filters,
  ) {
    if (filters.isEmpty) {
      return List<OperationItemEntity>.from(items);
    }

    return items.where(filters.matches).toList(growable: false);
  }

  Map<int, List<OperationItemEntity>> groupByYear(
    List<OperationItemEntity> items,
  ) {
    final grouped = SplayTreeMap<int, List<OperationItemEntity>>(
      (a, b) => b.compareTo(a),
    );
    for (final item in items) {
      final year = item.docDate?.year;
      if (year == null) {
        continue;
      }
      grouped.putIfAbsent(year, () => <OperationItemEntity>[]).add(item);
    }
    return grouped;
  }

  Map<int, List<OperationItemEntity>> groupByOperationId(
    List<OperationItemEntity> items,
  ) {
    final grouped = <int, List<OperationItemEntity>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.operationId, () => <OperationItemEntity>[])
          .add(item);
    }
    return grouped;
  }
}

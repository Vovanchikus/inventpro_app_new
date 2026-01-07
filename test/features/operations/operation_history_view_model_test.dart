import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:testing_app/features/operations/data/models/operation_history_item_dto.dart';
import 'package:testing_app/features/operations/data/repositories/operation_history_repository.dart';
import 'package:testing_app/features/operations/domain/usecases/operation_history_usecases.dart';
import 'package:testing_app/features/operations/presentation/viewmodels/operation_history_view_model.dart';

void main() {
  group('OperationHistoryViewModel', () {
    late FakeOperationHistoryRepository repository;
    late OperationHistoryViewModel viewModel;

    setUp(() {
      repository = FakeOperationHistoryRepository(_sampleItems);
      viewModel = OperationHistoryViewModel(repository: repository);
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('loadHistory converts and groups data with proper signs', () async {
      await viewModel.loadHistory();

      expect(viewModel.originalData.length, _sampleItems.length);
      expect(viewModel.groupedData, isNotEmpty);
      expect(viewModel.counteragentTotals['Partner A'], closeTo(17, 0.001));
      expect(viewModel.counteragentTotals['Partner B'], closeTo(-5, 0.001));

      final inbound = viewModel.groupedData
          .expand((group) => group.operations.values)
          .expand((items) => items)
          .where((item) => item.entity.operationTypeId == 4)
          .first;
      expect(inbound.signSymbol, equals('+'));
      expect(inbound.signedQuantity, greaterThan(0));

      final outbound = viewModel.groupedData
          .expand((group) => group.operations.values)
          .expand((items) => items)
          .where((item) => item.entity.operationTypeId == 2)
          .first;
      expect(outbound.signSymbol, equals('-'));
      expect(outbound.signedQuantity, lessThan(0));
    });

    test('applyFilters filters by year and type', () async {
      await viewModel.loadHistory();

      viewModel.applyFilters(const OperationHistoryFilters(year: 2023));
      expect(
        viewModel.groupedData.every((group) => group.year == 2023),
        isTrue,
      );

      viewModel.applyFilters(const OperationHistoryFilters(operationTypeId: 4));
      expect(
        viewModel.groupedData
            .expand((group) => group.operations.values)
            .expand((items) => items)
            .every((item) => item.entity.operationTypeId == 4),
        isTrue,
      );
    });

    test('resetFilters restores full dataset', () async {
      await viewModel.loadHistory();

      viewModel.applyFilters(const OperationHistoryFilters(year: 2023));
      final filteredLength = viewModel.groupedData.length;

      viewModel.resetFilters();
      expect(
        viewModel.groupedData.length,
        greaterThanOrEqualTo(filteredLength),
      );
      expect(viewModel.filters.isEmpty, isTrue);
    });
  });
}

class FakeOperationHistoryRepository extends OperationHistoryRepository {
  FakeOperationHistoryRepository(this._items)
    : super(baseUrl: 'http://localhost', httpClient: http.Client());

  final List<OperationHistoryItemDto> _items;

  @override
  Future<List<OperationHistoryItemDto>> fetchHistory() async {
    return _items;
  }

  @override
  void dispose() {
    // Skip closing any clients for test simplicity.
  }
}

const _sampleItems = <OperationHistoryItemDto>[
  OperationHistoryItemDto(
    id: 1,
    product: OperationHistoryProductDto(
      id: 10,
      name: 'Fuel A-95',
      unit: 'л',
      inventoryNumber: 'INV-1',
      price: 38.74,
    ),
    operationId: 100,
    operationTypeId: 4,
    operationTypeName: 'Импорт',
    counteragent: 'Partner A',
    quantity: 10,
    docDate: '2024-01-15',
    docName: 'ТОРГ-12',
    docNum: '001',
  ),
  OperationHistoryItemDto(
    id: 2,
    product: OperationHistoryProductDto(
      id: 11,
      name: 'Fuel Diesel',
      unit: 'л',
      inventoryNumber: 'INV-2',
      price: 40,
    ),
    operationId: 101,
    operationTypeId: 2,
    operationTypeName: 'Расход',
    counteragent: 'Partner B',
    quantity: 5,
    docDate: '2024-02-20',
    docName: 'ТОРГ-12',
    docNum: '002',
  ),
  OperationHistoryItemDto(
    id: 3,
    product: OperationHistoryProductDto(
      id: 12,
      name: 'Fuel A-92',
      unit: 'л',
      inventoryNumber: 'INV-3',
      price: 30,
    ),
    operationId: 102,
    operationTypeId: 4,
    operationTypeName: 'Импорт',
    counteragent: 'Partner A',
    quantity: 7,
    docDate: '2023-12-11',
    docName: 'ТОРГ-12',
    docNum: '003',
  ),
];

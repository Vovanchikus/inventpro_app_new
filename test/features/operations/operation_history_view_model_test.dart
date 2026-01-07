import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import 'package:testing_app/boxes/hive_boxes.dart';
import 'package:testing_app/features/operations/data/models/operation_history_cache_entry.dart';
import 'package:testing_app/features/operations/data/models/operation_history_item_dto.dart';
import 'package:testing_app/features/operations/data/repositories/operation_history_repository.dart';
import 'package:testing_app/features/operations/domain/usecases/operation_history_usecases.dart';
import 'package:testing_app/features/operations/presentation/viewmodels/operation_history_view_model.dart';
import 'package:testing_app/services/sync_service.dart';

void main() {
  Directory? tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('operations_history_test');
    Hive.init(tempDir!.path);
    final adapter = OperationHistoryCacheEntryAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    await Hive.openBox<OperationHistoryCacheEntry>(HiveBoxes.operationsHistory);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir != null && await tempDir!.exists()) {
      await tempDir!.delete(recursive: true);
    }
  });

  group('OperationHistoryViewModel', () {
    late FakeOperationHistoryRepository repository;
    late FakeOperationsHistorySyncService syncService;
    late OperationHistoryViewModel viewModel;

    setUp(() {
      repository = FakeOperationHistoryRepository(_sampleItems);
      syncService = FakeOperationsHistorySyncService(repository);
      viewModel = OperationHistoryViewModel(
        repository: repository,
        syncBridge: syncService,
      );
    });

    tearDown(() {
      viewModel.dispose();
      syncService.dispose();
    });

    test('loadHistory converts and groups data with polarity map', () async {
      await viewModel.loadHistory();

      expect(viewModel.originalData.length, _sampleItems.length);
      expect(viewModel.groupedData, isNotEmpty);
      expect(viewModel.isOffline, isFalse);

      final arrival = viewModel.groupedData
          .expand((group) => group.operations.values)
          .expand((items) => items)
          .where((item) => item.entity.operationTypeId == 1)
          .first;
      expect(arrival.signSymbol, equals('+'));
      expect(arrival.signedQuantity, greaterThan(0));

      final writeOff = viewModel.groupedData
          .expand((group) => group.operations.values)
          .expand((items) => items)
          .where((item) => item.entity.operationTypeId == 3)
          .first;
      expect(writeOff.signSymbol, equals('-'));
      expect(writeOff.signedQuantity, lessThan(0));
    });

    test('applyFilters filters by year and type', () async {
      await viewModel.loadHistory();

      viewModel.applyFilters(const OperationHistoryFilters(year: 2023));
      expect(
        viewModel.groupedData.every((group) => group.year == 2023),
        isTrue,
      );

      viewModel.applyFilters(const OperationHistoryFilters(operationTypeId: 1));
      expect(
        viewModel.groupedData
            .expand((group) => group.operations.values)
            .expand((items) => items)
            .every((item) => item.entity.operationTypeId == 1),
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

    test('loadHistory does not trigger sync service directly', () async {
      await viewModel.loadHistory();
      expect(syncService.callCount, equals(0));
    });

    test('isOffline toggles after external sync uses cache fallback', () async {
      await viewModel.loadHistory();
      repository.stateOverride = OperationHistoryFetchState.offline(
        _sampleItems.length,
      );

      await syncService.syncOperationsHistory();
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.isOffline, isTrue);
    });

    test('available operation types exclude import type', () async {
      await viewModel.loadHistory();

      expect(
        viewModel.availableOperationTypes.every((option) => option.id != 4),
        isTrue,
      );
    });
  });
}

class FakeOperationHistoryRepository extends OperationHistoryRepository {
  FakeOperationHistoryRepository(this._items)
    : super(baseUrl: 'http://localhost', httpClient: http.Client()) {
    _cached = List<OperationHistoryItemDto>.from(_items);
  }

  final List<OperationHistoryItemDto> _items;
  OperationHistoryFetchState? stateOverride;
  late List<OperationHistoryItemDto> _cached;

  @override
  Future<List<OperationHistoryItemDto>> fetchHistory() async {
    final snapshot =
        stateOverride ?? OperationHistoryFetchState.success(_items.length);
    debugSetState(snapshot);
    _cached = List<OperationHistoryItemDto>.from(_items);
    return _items;
  }

  @override
  List<OperationHistoryItemDto> loadCachedHistory() {
    return _cached;
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
    operationTypeId: 1,
    operationTypeName: 'Приход',
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
    operationTypeName: 'Передача',
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
    operationTypeId: 3,
    operationTypeName: 'Списание',
    counteragent: 'Partner C',
    quantity: 7,
    docDate: '2023-12-11',
    docName: 'ТОРГ-12',
    docNum: '003',
  ),
  OperationHistoryItemDto(
    id: 4,
    product: OperationHistoryProductDto(
      id: 13,
      name: 'Fuel Import',
      unit: 'л',
      inventoryNumber: 'INV-4',
      price: 52,
    ),
    operationId: 103,
    operationTypeId: 4,
    operationTypeName: 'Импорт',
    counteragent: 'Partner D',
    quantity: 4,
    docDate: '2024-03-05',
    docName: 'ТОРГ-12',
    docNum: '004',
  ),
];

class FakeOperationsHistorySyncService implements OperationsHistorySyncBridge {
  FakeOperationsHistorySyncService(this.repository);

  final OperationHistoryRepository repository;
  final ValueNotifier<bool> _isSyncing = ValueNotifier(false);
  final StreamController<void> _controller = StreamController.broadcast();
  Duration syncDelay = Duration.zero;
  int callCount = 0;

  @override
  ValueListenable<bool> get isSyncingOperationsHistory => _isSyncing;

  @override
  Stream<void> get operationsHistoryUpdates => _controller.stream;

  @override
  Future<void> syncOperationsHistory({int retries = 2}) async {
    _isSyncing.value = true;
    try {
      callCount++;
      if (syncDelay > Duration.zero) {
        await Future.delayed(syncDelay);
      }
      await repository.fetchHistory();
      _controller.add(null);
    } finally {
      _isSyncing.value = false;
    }
  }

  void dispose() {
    _controller.close();
  }
}

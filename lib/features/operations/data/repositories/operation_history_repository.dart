import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../../../boxes/hive_boxes.dart';
import '../../../../services/config.dart';
import '../models/operation_history_cache_entry.dart';
import '../models/operation_history_item_dto.dart';

/// Statuses that describe the outcome of the latest fetch attempt.
enum OperationHistoryLoadStatus { initial, success, empty, error, offline }

/// Immutable snapshot with information about the last fetch attempt.
class OperationHistoryFetchState {
  const OperationHistoryFetchState._({
    required this.status,
    required this.itemCount,
    this.message,
  });

  const OperationHistoryFetchState.initial()
    : this._(status: OperationHistoryLoadStatus.initial, itemCount: 0);

  const OperationHistoryFetchState.success(int count)
    : this._(status: OperationHistoryLoadStatus.success, itemCount: count);

  const OperationHistoryFetchState.empty()
    : this._(status: OperationHistoryLoadStatus.empty, itemCount: 0);

  const OperationHistoryFetchState.error(String? message)
    : this._(
        status: OperationHistoryLoadStatus.error,
        itemCount: 0,
        message: message,
      );

  const OperationHistoryFetchState.offline(int count)
    : this._(
        status: OperationHistoryLoadStatus.offline,
        itemCount: count,
        message: 'offline',
      );

  final OperationHistoryLoadStatus status;
  final int itemCount;
  final String? message;
}

/// Repository that talks to /api/history and converts raw JSON into DTOs.
class OperationHistoryRepository {
  OperationHistoryRepository({
    http.Client? httpClient,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 10),
    Box<OperationHistoryCacheEntry>? cacheBox,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? Config.baseUrl,
       _timeout = timeout,
       _cacheBox =
           cacheBox ??
           Hive.box<OperationHistoryCacheEntry>(HiveBoxes.operationsHistory);

  final http.Client _httpClient;
  final String _baseUrl;
  final Duration _timeout;
  final Box<OperationHistoryCacheEntry> _cacheBox;

  OperationHistoryFetchState _state =
      const OperationHistoryFetchState.initial();

  OperationHistoryFetchState get state => _state;

  Future<List<OperationHistoryItemDto>> fetchHistory() async {
    try {
      final items = await _fetchRemote();
      await _persistCache(items);
      if (items.isEmpty) {
        _state = const OperationHistoryFetchState.empty();
        return const <OperationHistoryItemDto>[];
      }
      _state = OperationHistoryFetchState.success(items.length);
      return items;
    } on SocketException catch (error) {
      final cached = _readCache();
      if (cached.isNotEmpty) {
        _state = OperationHistoryFetchState.offline(cached.length);
        return cached;
      }
      _state = const OperationHistoryFetchState.error('Сеть недоступна');
      throw OperationHistoryRepositoryException(
        'Network unavailable and no cache',
        error,
      );
    } on TimeoutException catch (error, stackTrace) {
      final cached = _readCache();
      if (cached.isNotEmpty) {
        _state = OperationHistoryFetchState.offline(cached.length);
        return cached;
      }
      _state = const OperationHistoryFetchState.error('Request timeout');
      throw OperationHistoryRepositoryException(
        'History request timed out',
        error,
        stackTrace,
      );
    } on OperationHistoryRepositoryException catch (error) {
      _state = OperationHistoryFetchState.error(error.message);
      rethrow;
    } catch (error, stackTrace) {
      final cached = _readCache();
      if (cached.isNotEmpty) {
        _state = OperationHistoryFetchState.offline(cached.length);
        return cached;
      }
      _state = OperationHistoryFetchState.error(error.toString());
      throw OperationHistoryRepositoryException(
        'Unexpected history error',
        error,
        stackTrace,
      );
    }
  }

  List<OperationHistoryItemDto> loadCachedHistory() {
    return _readCache();
  }

  void dispose() {
    _httpClient.close();
  }

  @visibleForTesting
  void debugSetState(OperationHistoryFetchState newState) {
    _state = newState;
  }

  Future<List<OperationHistoryItemDto>> _fetchRemote() async {
    final uri = Uri.parse('$_baseUrl/api/history');
    final response = await _httpClient.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw OperationHistoryRepositoryException(
        'History request failed with status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final success = decoded['success'] == true;
    final rawData = decoded['data'];

    if (!success || rawData == null) {
      throw const OperationHistoryRepositoryException(
        'Malformed history response',
      );
    }

    if (rawData is! List) {
      throw const OperationHistoryRepositoryException(
        'Unexpected data structure',
      );
    }

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(OperationHistoryItemDto.fromJson)
        .toList();
  }

  Future<void> _persistCache(List<OperationHistoryItemDto> items) async {
    await _cacheBox.clear();
    for (final dto in items) {
      await _cacheBox.put(dto.id, OperationHistoryCacheEntry.fromDto(dto));
    }
  }

  List<OperationHistoryItemDto> _readCache() {
    if (_cacheBox.isEmpty) {
      return const <OperationHistoryItemDto>[];
    }
    return _cacheBox.values
        .map((entry) => entry.toDto())
        .toList(growable: false);
  }
}

/// Custom exception to keep error handling explicit at upper layers.
class OperationHistoryRepositoryException implements Exception {
  const OperationHistoryRepositoryException(
    this.message, [
    this.error,
    this.stackTrace,
  ]);

  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'OperationHistoryRepositoryException(message: $message, error: $error)';
}

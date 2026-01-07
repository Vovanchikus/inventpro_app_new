import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../services/config.dart';
import '../models/operation_history_item_dto.dart';

/// Statuses that describe the outcome of the latest fetch attempt.
enum OperationHistoryLoadStatus { initial, success, empty, error }

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
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? Config.baseUrl,
       _timeout = timeout;

  final http.Client _httpClient;
  final String _baseUrl;
  final Duration _timeout;

  OperationHistoryFetchState _state =
      const OperationHistoryFetchState.initial();

  OperationHistoryFetchState get state => _state;

  Future<List<OperationHistoryItemDto>> fetchHistory() async {
    final uri = Uri.parse('$_baseUrl/api/history');

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        _state = OperationHistoryFetchState.error(
          'HTTP ${response.statusCode}',
        );
        throw OperationHistoryRepositoryException(
          'History request failed with status ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final rawData = decoded['data'];

      if (!success || rawData == null) {
        _state = const OperationHistoryFetchState.error('Payload missing data');
        throw const OperationHistoryRepositoryException(
          'Malformed history response',
        );
      }

      if (rawData is! List) {
        _state = const OperationHistoryFetchState.error(
          'Unexpected payload shape',
        );
        throw const OperationHistoryRepositoryException(
          'Unexpected data structure',
        );
      }

      final items = rawData
          .whereType<Map<String, dynamic>>()
          .map(OperationHistoryItemDto.fromJson)
          .toList();

      if (items.isEmpty) {
        _state = const OperationHistoryFetchState.empty();
        return const <OperationHistoryItemDto>[];
      }

      _state = OperationHistoryFetchState.success(items.length);
      return items;
    } on TimeoutException catch (error, stackTrace) {
      _state = const OperationHistoryFetchState.error('Request timeout');
      throw OperationHistoryRepositoryException(
        'History request timed out',
        error,
        stackTrace,
      );
    } on OperationHistoryRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      _state = OperationHistoryFetchState.error(error.toString());
      throw OperationHistoryRepositoryException(
        'Unexpected history error',
        error,
        stackTrace,
      );
    }
  }

  void dispose() {
    _httpClient.close();
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

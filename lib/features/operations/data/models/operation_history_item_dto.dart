import 'package:meta/meta.dart';

/// Product data returned alongside an operation history item.
@immutable
class OperationHistoryProductDto {
  const OperationHistoryProductDto({
    required this.id,
    required this.name,
    required this.unit,
    required this.inventoryNumber,
    required this.price,
  });

  factory OperationHistoryProductDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const OperationHistoryProductDto(
        id: 0,
        name: '',
        unit: '',
        inventoryNumber: '',
        price: 0,
      );
    }

    return OperationHistoryProductDto(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      inventoryNumber: json['inv_number']?.toString() ?? '',
      price: _asDouble(json['price']),
    );
  }

  final int id;
  final String name;
  final String unit;
  final String inventoryNumber;
  final double price;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'unit': unit,
    'inv_number': inventoryNumber,
    'price': price,
  };
}

/// Raw DTO that mirrors the /api/history payload.
@immutable
class OperationHistoryItemDto {
  const OperationHistoryItemDto({
    required this.id,
    required this.product,
    required this.operationId,
    required this.operationTypeId,
    required this.operationTypeName,
    required this.counteragent,
    required this.quantity,
    required this.docDate,
    required this.docName,
    required this.docNum,
  });

  factory OperationHistoryItemDto.fromJson(Map<String, dynamic> json) {
    final operationJson =
        (json['operation'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final operationTypeJson =
        (operationJson['type'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return OperationHistoryItemDto(
      id: _asInt(json['id']),
      product: OperationHistoryProductDto.fromJson(
        json['product'] as Map<String, dynamic>?,
      ),
      operationId: _asInt(operationJson['id']),
      operationTypeId: _asInt(operationTypeJson['id']),
      operationTypeName: operationTypeJson['name']?.toString() ?? '',
      counteragent: json['counteragent']?.toString() ?? 'Не указан',
      quantity: _asDouble(json['quantity']),
      docDate: _asNullableString(json['doc_date']),
      docName: _asNullableString(json['doc_name']),
      docNum: _asNullableString(json['doc_num']),
    );
  }

  final int id;
  final OperationHistoryProductDto product;
  final int operationId;
  final int operationTypeId;
  final String operationTypeName;
  final String counteragent;
  final double quantity;
  final String? docDate;
  final String? docName;
  final String? docNum;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'product': product.toJson(),
    'operation': <String, dynamic>{
      'id': operationId,
      'type': <String, dynamic>{
        'id': operationTypeId,
        'name': operationTypeName,
      },
    },
    'counteragent': counteragent,
    'quantity': quantity,
    'doc_date': docDate,
    'doc_name': docName,
    'doc_num': docNum,
  };
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final stringValue = value.toString().trim();
  if (stringValue.isEmpty) {
    return null;
  }
  return stringValue;
}

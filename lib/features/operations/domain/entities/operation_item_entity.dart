import 'package:meta/meta.dart';

/// Direction of stock movement.
enum OperationFlow { inbound, outbound }

/// Allows customizing what operation type IDs should be treated as inbound/outbound.
class OperationTypePolarityResolver {
  const OperationTypePolarityResolver({
    this.inboundTypeIds = const <int>{},
    this.outboundTypeIds = const <int>{},
    this.defaultFlow = OperationFlow.outbound,
  });

  final Set<int> inboundTypeIds;
  final Set<int> outboundTypeIds;
  final OperationFlow defaultFlow;

  OperationFlow resolve(int operationTypeId) {
    if (inboundTypeIds.contains(operationTypeId)) {
      return OperationFlow.inbound;
    }
    if (outboundTypeIds.contains(operationTypeId)) {
      return OperationFlow.outbound;
    }
    return defaultFlow;
  }
}

/// Shared default resolver. Update inbound/outbound sets once the server contracts are documented.
const OperationTypePolarityResolver defaultPolarityResolver =
    OperationTypePolarityResolver(
      inboundTypeIds: <int>{4},
      outboundTypeIds: <int>{},
    );

@immutable
class OperationProductEntity {
  const OperationProductEntity({
    required this.id,
    required this.name,
    required this.unit,
    required this.inventoryNumber,
    required this.price,
  });

  final int id;
  final String name;
  final String unit;
  final String inventoryNumber;
  final double price;
}

@immutable
class OperationItemEntity {
  const OperationItemEntity({
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

  final int id;
  final OperationProductEntity product;
  final int operationId;
  final int operationTypeId;
  final String operationTypeName;
  final String counteragent;
  final double quantity;
  final DateTime? docDate;
  final String? docName;
  final String? docNum;

  OperationFlow flow({OperationTypePolarityResolver? resolver}) {
    return (resolver ?? defaultPolarityResolver).resolve(operationTypeId);
  }

  double signedQuantity({OperationTypePolarityResolver? resolver}) {
    final effectiveResolver = resolver ?? defaultPolarityResolver;
    final direction = effectiveResolver.resolve(operationTypeId);
    return direction == OperationFlow.inbound ? quantity : -quantity;
  }
}

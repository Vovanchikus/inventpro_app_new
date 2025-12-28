import 'package:hive/hive.dart';
part 'operation_type.g.dart';

@HiveType(typeId: 2)
class OperationType extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  OperationType({required this.id, required this.name});
}

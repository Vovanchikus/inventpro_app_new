import 'package:hive/hive.dart';
part 'operation.g.dart';

@HiveType(typeId: 3)
class Operation extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int typeId;

  @HiveField(2)
  DateTime? createdAt;

  @HiveField(3)
  DateTime? updatedAt;

  Operation({
    required this.id,
    required this.typeId,
    required this.createdAt,
    required this.updatedAt,
  });
}

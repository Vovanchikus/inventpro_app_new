import 'package:hive/hive.dart';
part 'document.g.dart';

@HiveType(typeId: 5)
class Document extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int operationId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String number;

  @HiveField(4)
  DateTime? date;

  @HiveField(5)
  String? purpose;

  @HiveField(6)
  String? filePath;

  Document({
    required this.id,
    required this.operationId,
    required this.name,
    required this.number,
    this.date,
    this.purpose,
    this.filePath,
  });
}

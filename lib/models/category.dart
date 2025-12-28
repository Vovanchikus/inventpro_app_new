import 'package:hive/hive.dart';
part 'category.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int? parentId;

  @HiveField(3)
  String slug;

  @HiveField(4)
  bool deleted;

  Category({
    required this.id,
    required this.name,
    this.parentId,
    required this.slug,
    this.deleted = false,
  });
}

class SyncProgressData {
  final String title;
  final String iconAsset; // путь к иконке для каждой модели
  int done;
  final int total;

  SyncProgressData({
    required this.title,
    required this.iconAsset,
    required this.done,
    required this.total,
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/dashboard_card.dart';
import '../services/api_service.dart';
import '../services/overlay_service.dart';
import '../boxes/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/document.dart';
import '../models/operation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Публичный GlobalKey для MainScreen
  static final GlobalKey<HomeScreenState> globalKey =
      GlobalKey<HomeScreenState>();

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ApiService _apiService;
  bool _loading = true;

  // Количество элементов для карточек
  int _productsCount = 0;
  int _operationsCount = 0;
  int _documentsCount = 0;
  int _categoriesCount = 0;

  // Анимации чисел
  late final AnimationController _productsController;
  late final AnimationController _operationsController;
  late final AnimationController _documentsController;
  late final AnimationController _categoriesController;

  // Автосинхронизация один раз
  static bool _hasSynced = false;

  @override
  void initState() {
    super.initState();

    _apiService = ApiService(baseUrl: 'http://192.168.0.108');

    // Создаем контроллеры для анимации чисел
    _productsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _operationsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _documentsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _categoriesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _initHiveAndSync();
  }

  Future<void> _initHiveAndSync() async {
    // Открываем все боксы параллельно
    await Future.wait([
      if (!Hive.isBoxOpen(HiveBoxes.products))
        Hive.openBox<Product>(HiveBoxes.products),
      if (!Hive.isBoxOpen(HiveBoxes.operations))
        Hive.openBox<Operation>(HiveBoxes.operations),
      if (!Hive.isBoxOpen(HiveBoxes.documents))
        Hive.openBox<Document>(HiveBoxes.documents),
      if (!Hive.isBoxOpen(HiveBoxes.categories))
        Hive.openBox<Category>(HiveBoxes.categories),
      if (!Hive.isBoxOpen(HiveBoxes.operationTypes))
        Hive.openBox(HiveBoxes.operationTypes),
      if (!Hive.isBoxOpen(HiveBoxes.operationProducts))
        Hive.openBox(HiveBoxes.operationProducts),
    ]);

    // Сразу обновляем количество из локального хранилища
    _updateCounts();

    // Автосинхронизация только один раз при первом запуске
    if (!_hasSynced) {
      _hasSynced = true;
      _syncData();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Метод для синхронизации данных с сервером
  Future<void> _syncData() async {
    setState(() => _loading = true);

    try {
      final status = await _apiService.syncAll();

      if (status == SyncStatus.success) {
        OverlayService.showMessage(
          context,
          'Синхронизация завершена',
          type: ToastType.success,
        );
      } else if (status == SyncStatus.info) {
        OverlayService.showMessage(
          context,
          'Нет новых данных для синхронизации',
          type: ToastType.info,
        );
      } else {
        OverlayService.showMessage(
          context,
          'Сервер недоступен. Синхронизация отменена',
          type: ToastType.error,
        );
      }
    } catch (e) {
      OverlayService.showMessage(
        context,
        'Синхронизация не удалась\n$e',
        type: ToastType.error,
      );
    } finally {
      _updateCounts();
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Вызов ручной синхронизации
  Future<void> manualSync() async => await _syncData();

  void _updateCounts() {
    final productBox = Hive.box<Product>(HiveBoxes.products);
    final operationBox = Hive.box<Operation>(HiveBoxes.operations);
    final documentBox = Hive.box<Document>(HiveBoxes.documents);
    final categoryBox = Hive.box<Category>(HiveBoxes.categories);

    _animateCount(
      _productsController,
      _productsCount,
      productBox.length,
      (val) => _productsCount = val,
    );
    _animateCount(
      _operationsController,
      _operationsCount,
      operationBox.length,
      (val) => _operationsCount = val,
    );
    _animateCount(
      _documentsController,
      _documentsCount,
      documentBox.length,
      (val) => _documentsCount = val,
    );
    _animateCount(
      _categoriesController,
      _categoriesCount,
      categoryBox.length,
      (val) => _categoriesCount = val,
    );
  }

  void _animateCount(
    AnimationController controller,
    int from,
    int to,
    Function(int) onUpdate,
  ) {
    controller.reset();
    late Animation<int> anim;
    anim =
        IntTween(begin: from, end: to).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (mounted) setState(() => onUpdate(anim.value));
        });
    controller.forward();
  }

  /// Плавная анимация появления карточек (staggered)
  Widget _animatedCard(Widget card, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + index * 120),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: card,
    );
  }

  @override
  void dispose() {
    _productsController.dispose();
    _operationsController.dispose();
    _documentsController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общая информация',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _animatedCard(
                        DashboardCard(
                          title: "Товаров",
                          count: _productsCount,
                          iconUrl: "assets/icons/box.svg",
                          iconColor: AppColors.brand,
                          iconBgColor: AppColors.bgBrand,
                        ),
                        0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _animatedCard(
                        DashboardCard(
                          title: "Операций",
                          count: _operationsCount,
                          iconUrl: "assets/icons/arrow-right-left-simple.svg",
                          iconColor: AppColors.success,
                          iconBgColor: AppColors.bgSuccess,
                        ),
                        1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _animatedCard(
                        DashboardCard(
                          title: "Документов",
                          count: _documentsCount,
                          iconUrl: "assets/icons/file-list.svg",
                          iconColor: AppColors.error,
                          iconBgColor: AppColors.bgError,
                        ),
                        2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _animatedCard(
                        DashboardCard(
                          title: "Категорий",
                          count: _categoriesCount,
                          iconUrl: "assets/icons/grid-category.svg",
                          iconColor: AppColors.neutral400,
                          iconBgColor: AppColors.neutral300,
                        ),
                        3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ApiService _apiService;
  bool _loading = true;

  // Значения для карточек
  int _productsCount = 0;
  int _operationsCount = 0;
  int _documentsCount = 0;
  int _categoriesCount = 0;

  // Анимации чисел
  late AnimationController _productsController;
  late AnimationController _operationsController;
  late AnimationController _documentsController;
  late AnimationController _categoriesController;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: 'https://192.168.0.108');

    // Контроллеры для анимации
    _productsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _operationsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _documentsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _categoriesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _initHiveAndSync();
  }

  Future<void> _initHiveAndSync() async {
    // Открываем боксы
    if (!Hive.isBoxOpen(HiveBoxes.products)) {
      await Hive.openBox<Product>(HiveBoxes.products);
    }
    if (!Hive.isBoxOpen(HiveBoxes.operations)) {
      await Hive.openBox<Operation>(HiveBoxes.operations);
    }
    if (!Hive.isBoxOpen(HiveBoxes.documents)) {
      await Hive.openBox<Document>(HiveBoxes.documents);
    }
    if (!Hive.isBoxOpen(HiveBoxes.categories)) {
      await Hive.openBox<Category>(HiveBoxes.categories);
    }
    if (!Hive.isBoxOpen(HiveBoxes.operationTypes)) {
      await Hive.openBox(HiveBoxes.operationTypes);
    }
    if (!Hive.isBoxOpen(HiveBoxes.operationProducts)) {
      await Hive.openBox(HiveBoxes.operationProducts);
    }

    // Загружаем локальные данные сразу
    _updateCounts();

    try {
      // Полная синхронизация через существующий метод
      await _apiService.syncAll();

      // После синхронизации пересчитываем количество категорий
      _updateCounts();

      OverlayService.showMessage(
        context,
        'Синхронизация завершена',
        type: ToastType.success,
      );
    } catch (e) {
      OverlayService.showMessage(
        context,
        'Синхронизация не удалась \n$e',
        type: ToastType.error,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

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
    // создаём переменную заранее
    late Animation<int> anim;
    anim = IntTween(begin: from, end: to).animate(controller)
      ..addListener(() {
        setState(() {
          onUpdate(anim.value);
        });
      });
    controller.forward();
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
                      child: DashboardCard(
                        title: "Товаров",
                        count: _productsCount,
                        iconUrl: "assets/icons/box.svg",
                        iconColor: AppColors.brand,
                        iconBgColor: AppColors.bgBrand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardCard(
                        title: "Операций",
                        count: _operationsCount,
                        iconUrl: "assets/icons/arrow-right-left-simple.svg",
                        iconColor: AppColors.success,
                        iconBgColor: AppColors.bgSuccess,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardCard(
                        title: "Документов",
                        count: _documentsCount,
                        iconUrl: "assets/icons/file-list.svg",
                        iconColor: AppColors.error,
                        iconBgColor: AppColors.bgError,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardCard(
                        title: "Категорий",
                        count: _categoriesCount,
                        iconUrl: "assets/icons/grid-category.svg",
                        iconColor: AppColors.neutral400,
                        iconBgColor: AppColors.neutral300,
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

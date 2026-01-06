import 'dart:async';
import 'package:flutter/material.dart';
import 'package:testing_app/services/config.dart';
import 'package:testing_app/services/image_sync_service.dart';
import '../theme/colors.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/sync_modal.dart';
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

  static final GlobalKey<HomeScreenState> globalKey =
      GlobalKey<HomeScreenState>();

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ApiService _apiService;
  bool _loading = true;

  int _productsCount = 0;
  int _operationsCount = 0;
  int _documentsCount = 0;
  int _categoriesCount = 0;

  late final AnimationController _productsController;
  late final AnimationController _operationsController;
  late final AnimationController _documentsController;
  late final AnimationController _categoriesController;

  static bool _hasSynced = false;

  @override
  void initState() {
    super.initState();

    _apiService = ApiService(baseUrl: Config.baseUrl);

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
      if (!Hive.isBoxOpen(HiveBoxes.productImages))
        Hive.openBox(HiveBoxes.productImages),
    ]);

    _updateCounts();

    // 🔹 Только первый вход запускает синхронизацию
    if (!_hasSynced) {
      _hasSynced = true;
      await _syncData();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 🔄 Основная функция синхронизации
  Future<void> _syncData() async {
    setState(() => _loading = true);

    // Подготовка нотификаторов для модалки
    final steps = ValueNotifier<Map<String, double>>({
      'Категории': 0.0,
      'Типы операций': 0.0,
      'Товары': 0.0,
      'Операции': 0.0,
      'История': 0.0,
      'Документы': 0.0,
      'Фото': 0.0,
    });
    final statusText = ValueNotifier<String>('Инициализация...');
    final isError = ValueNotifier<bool>(false);

    // Показываем модалку (не закрываем по нажатию вне)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SyncModal(steps: steps, statusText: statusText, isError: isError),
    );

    try {
      statusText.value = 'Проверка сервера...';

      // Категории
      statusText.value = 'Синхронизируем категории...';
      steps.value = {...steps.value, 'Категории': 0.2};
      await _apiService.syncCategories(noTimeout: true);
      steps.value = {...steps.value, 'Категории': 1.0};

      // Типы операций
      statusText.value = 'Синхронизируем типы операций...';
      steps.value = {...steps.value, 'Типы операций': 0.2};
      await _apiService.syncOperationTypes(noTimeout: true);
      steps.value = {...steps.value, 'Типы операций': 1.0};

      // Товары
      statusText.value = 'Синхронизируем товары...';
      steps.value = {...steps.value, 'Товары': 0.1};
      await _apiService.syncProducts(noTimeout: true);
      steps.value = {...steps.value, 'Товары': 1.0};

      // Операции
      statusText.value = 'Синхронизируем операции...';
      steps.value = {...steps.value, 'Операции': 0.1};
      await _apiService.syncOperations(noTimeout: true);
      steps.value = {...steps.value, 'Операции': 1.0};

      // История операций (operation products)
      statusText.value = 'Синхронизируем историю операций...';
      steps.value = {...steps.value, 'История': 0.1};
      await _apiService.syncOperationProducts(noTimeout: true);
      steps.value = {...steps.value, 'История': 1.0};

      // Документы
      statusText.value = 'Синхронизируем документы...';
      steps.value = {...steps.value, 'Документы': 0.1};
      await _apiService.syncDocuments(noTimeout: true);
      steps.value = {...steps.value, 'Документы': 1.0};

      // Фото
      statusText.value = 'Синхронизируем фото...';
      steps.value = {...steps.value, 'Фото': 0.0};
      await ImageSyncService.syncAllImages();
      steps.value = {...steps.value, 'Фото': 1.0};

      statusText.value = 'Готово';

      OverlayService.showMessage(
        context,
        'Синхронизация завершена',
        type: ToastType.success,
      );
    } catch (e) {
      isError.value = true;
      statusText.value = 'Синхронизация не удалась\n$e';
      OverlayService.showMessage(
        context,
        'Синхронизация не удалась\n$e',
        type: ToastType.error,
      );
    } finally {
      _updateCounts();
      if (mounted) setState(() => _loading = false);

      // Закрываем модалку при успешном завершении. При ошибке оставляем пользователю кнопку "Закрыть".
      if (!isError.value) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    }
  }

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

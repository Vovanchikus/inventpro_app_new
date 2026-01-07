import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../boxes/hive_boxes.dart';
import '../models/notification_model.dart';
import '../models/product_image.dart';

import '../theme/colors.dart';
import '../widgets/app_bottom_bar.dart';

import 'home_screen.dart';
import 'images_sync_center_screen.dart';
import 'warehouse_screen.dart';
import 'operation_history_screen.dart';
import 'qr_screen.dart';
import 'notifications_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final GlobalKey<State<WarehouseScreen>> warehouseKey =
      GlobalKey<State<WarehouseScreen>>();
  final GlobalKey<HomeScreenState> homeKey = HomeScreen.globalKey;

  final List<String> titles = ['Главная', 'Склад', 'История', 'Документы'];

  late final AnimationController _syncController;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Плавное ускорение/торможение стрелок
    _rotationAnimation =
        Tween<double>(begin: 0, end: 6.28319 * 3) // x3 скорость
            .animate(
              CurvedAnimation(parent: _syncController, curve: Curves.linear),
            );

    // Открываем box уведомлений (если ещё не открыт)
    if (!Hive.isBoxOpen('notificationsBox')) {
      Hive.openBox('notificationsBox').then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _syncController.dispose();
    super.dispose();
  }

  Widget _buildSyncCenterShortcut() {
    if (!Hive.isBoxOpen(HiveBoxes.productImages)) {
      Hive.openBox<ProductImage>(HiveBoxes.productImages).then((_) {
        if (mounted) setState(() {});
      });
      return IconButton(
        icon: const Icon(Icons.notifications_none_outlined),
        color: AppColors.textTitle,
        onPressed: _openSyncCenter,
      );
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box<ProductImage>(
        HiveBoxes.productImages,
      ).listenable(),
      builder: (context, Box<ProductImage> box, _) {
        final counter = _unsyncedCounter(box);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined),
              color: AppColors.textTitle,
              onPressed: _openSyncCenter,
            ),
            if (counter > 0)
              Positioned(
                right: 4,
                top: 6,
                child: _Badge(label: counter > 99 ? '99+' : '$counter'),
              ),
          ],
        );
      },
    );
  }

  int _unsyncedCounter(Box<ProductImage> box) {
    var total = 0;
    for (final image in box.values) {
      if (image.isSynced) continue;
      total += 1;
    }
    return total;
  }

  void _openSyncCenter() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImagesSyncCenterScreen()));
  }

  /// ==========================
  /// Кнопка синхронизации
  /// ==========================
  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: () async {
        if (homeKey.currentState == null) return;

        _syncController.repeat(); // запускаем вращение

        try {
          await homeKey.currentState!.manualSync();
        } catch (_) {
          // Ошибки игнорируем, больше не меняем иконку
        } finally {
          _syncController.reset(); // останавливаем вращение
        }
      },
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ===== Облако =====
            SvgPicture.string(
              '''
<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path fill-rule="evenodd" clip-rule="evenodd" d="M4.24988 11C4.24988 6.71979 7.71967 3.25 11.9999 3.25C15.7586 3.25 18.8914 5.92521 19.5999 9.47575C21.997 10.169 23.7499 12.3791 23.7499 15C23.7499 18.1756 21.1755 20.75 17.9999 20.75H4.99988C2.37653 20.75 0.249878 18.6234 0.249878 16C0.249878 13.6298 1.98596 11.665 4.25589 11.3079C4.25189 11.2057 4.24988 11.1031 4.24988 11ZM11.9999 4.75C8.5481 4.75 5.74988 7.54822 5.74988 11C5.74988 11.3041 5.77154 11.6026 5.81329 11.8944C5.84442 12.1119 5.7786 12.3321 5.63321 12.4969C5.48783 12.6616 5.2775 12.7543 5.0578 12.7505C5.03845 12.7502 5.01914 12.75 4.99988 12.75C3.20495 12.75 1.74988 14.2051 1.74988 16C1.74988 17.7949 3.20495 19.25 4.99988 19.25H17.9999C20.3471 19.25 22.2499 17.3472 22.2499 15C22.2499 12.9271 20.7651 11.1994 18.8007 10.8252C18.4825 10.7646 18.2391 10.5064 18.1973 10.1852C17.7985 7.11868 15.1752 4.75 11.9999 4.75Z" fill="currentColor"/>
</svg>
''',
              width: 28,
              height: 28,
              color: AppColors.textTitle,
            ),

            // ===== Вращающиеся стрелки =====
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (_, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  alignment: Alignment.center, // вращаем вокруг центра стрелок
                  child: child,
                );
              },
              child: SvgPicture.string(
                '''
<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M15.6666 8.58325C15.2524 8.58325 14.9166 8.91904 14.9166 9.33325V9.68346C14.139 8.99895 13.1183 8.58332 11.9999 8.58332C9.94092 8.58332 8.21272 9.99159 7.72246 11.8964C7.61921 12.2975 7.8607 12.7064 8.26184 12.8096C8.66298 12.9129 9.07187 12.6714 9.17512 12.2703C9.49894 11.0121 10.6419 10.0833 11.9999 10.0833C12.7232 10.0833 13.3855 10.3466 13.8957 10.7832H13.4666C13.0524 10.7832 12.7166 11.119 12.7166 11.5332C12.7166 11.9474 13.0524 12.2832 13.4666 12.2832H15.3407C15.3548 12.2836 15.3689 12.2836 15.3831 12.2832H15.6666C16.0808 12.2832 16.4166 11.9474 16.4166 11.5332V9.33325C16.4166 8.91904 16.0808 8.58325 15.6666 8.58325Z" fill="currentColor"/>
<path d="M9.08325 16.6665C9.08325 17.0807 8.74747 17.4165 8.33325 17.4165C7.91904 17.4165 7.58325 17.0807 7.58325 16.6665V14.4665C7.58325 14.2676 7.66227 14.0769 7.80292 13.9362C7.94357 13.7956 8.13434 13.7165 8.33325 13.7165H10.5333C10.9475 13.7165 11.2833 14.0523 11.2833 14.4665C11.2833 14.8808 10.9475 15.2165 10.5333 15.2165H10.1039C10.6141 15.6533 11.2766 15.9167 11.9999 15.9167C13.358 15.9167 14.501 14.9879 14.8248 13.7298C14.928 13.3286 15.3369 13.0871 15.738 13.1904C16.1392 13.2936 16.3807 13.7025 16.2774 14.1036C15.7872 16.0084 14.059 17.4167 11.9999 17.4167C10.8816 17.4167 9.8609 17.0011 9.08325 16.3166V16.6665Z" fill="currentColor"/>
</svg>
''',
                width: 28,
                height: 28,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      appBar: AppBar(
        backgroundColor: AppColors.bgApp,
        elevation: 0,
        toolbarHeight: 56,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: Text(
            titles[_currentIndex],
            key: ValueKey<int>(_currentIndex),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _currentIndex == 0
                ? _buildSyncButton()
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          _buildSyncCenterShortcut(),
          Hive.isBoxOpen('notificationsBox')
              ? ValueListenableBuilder(
                  valueListenable: Hive.box('notificationsBox').listenable(),
                  builder: (context, Box box, _) {
                    // считаем непрочитанные
                    int count = 0;
                    for (final v in box.values) {
                      if (v is NotificationModel) {
                        if (!v.isRead) count += (v.count ?? 1);
                      } else if (v is Map) {
                        if (v['isRead'] != true) {
                          final raw = v['count'];
                          int add = 1;
                          if (raw is int) {
                            add = raw;
                          } else if (raw is double) {
                            add = raw.toInt();
                          } else if (raw != null) {
                            add = int.tryParse(raw.toString()) ?? 1;
                          }
                          count += add;
                        }
                      }
                    }
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history),
                          color: AppColors.textTitle,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 4,
                            top: 6,
                            child: _Badge(label: count.toString()),
                          ),
                      ],
                    );
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.history),
                  color: AppColors.textTitle,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeScreen(key: homeKey),
          WarehouseScreen(key: warehouseKey),
          OperationHistoryScreen(),
          const Placeholder(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        onCenterTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const QrScreen()));
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

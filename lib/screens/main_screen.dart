import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../widgets/app_bottom_bar.dart';
import 'home_screen.dart';
import 'warehouse_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // GlobalKey для доступа к состоянию WarehouseScreen
  final GlobalKey<State<WarehouseScreen>> warehouseKey =
      GlobalKey<State<WarehouseScreen>>();

  // Названия вкладок
  final List<String> titles = ['Главная', 'Склад', 'История', 'Документы'];

  // Действия в AppBar
  late final List<Widget> actions = [
    SvgPicture.asset('assets/icons/cloud-reload.svg', width: 28, height: 28),
    const SizedBox.shrink(),
    const SizedBox.shrink(),
  ];

  // Экраны
  late final List<Widget> screens = [
    const HomeScreen(),
    WarehouseScreen(key: warehouseKey),
    const Placeholder(),
    const Placeholder(),
  ];

  void _onTabTap(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,

      /// ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: AppColors.bgApp,
        elevation: 0,
        toolbarHeight: 56,

        /// ===== Анимированный title =====
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
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

        /// ===== Анимированный action =====
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: actions[_currentIndex] is SizedBox
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : actions[_currentIndex],
          ),
        ],
      ),

      /// ================= BODY =================
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // свайп отключен
        children: screens,
      ),

      /// ================= BOTTOM BAR =================
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        onCenterTap: () {},
      ),
    );
  }
}

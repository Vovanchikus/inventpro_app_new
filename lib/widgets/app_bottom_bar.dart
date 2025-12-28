import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final fabDiameter = MediaQuery.of(context).size.width * 0.14;
    final fabRadius = fabDiameter / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ======================= Bottom Bar =======================
        Container(
          margin: EdgeInsets.only(left: 16, right: 16, bottom: fabRadius * 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomItem(
                iconDefault: 'assets/icons/house-door-arch.svg',
                iconActive: 'assets/icons/house-door-arch-bold.svg',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _BottomItem(
                iconDefault: 'assets/icons/box.svg',
                iconActive: 'assets/icons/box-bold.svg',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              SizedBox(width: fabDiameter + 16), // место под FAB
              _BottomItem(
                iconDefault: 'assets/icons/history-rectangle.svg',
                iconActive: 'assets/icons/history-rectangle-bold.svg',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _BottomItem(
                iconDefault: 'assets/icons/file-list.svg',
                iconActive: 'assets/icons/file-list-bold.svg',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),

        // ======================= Центральная кнопка =======================
        Positioned(
          top: -fabRadius,
          left: 0,
          right: 0,
          child: Center(
            child: _CenterButton(
              diameter: fabDiameter * 1.16,
              onTap: onCenterTap,
              icon: 'assets/icons/qr-code.svg',
            ),
          ),
        ),
      ],
    );
  }
}

// ======================= Центр. кнопка с заметной анимацией =======================
class _CenterButton extends StatefulWidget {
  final double diameter;
  final VoidCallback onTap;
  final String icon;

  const _CenterButton({
    super.key,
    required this.diameter,
    required this.onTap,
    required this.icon,
  });

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.87 : 1.0, // более заметное уменьшение
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowBrand,
                blurRadius: _isPressed ? 8 : 14, // тень меняется сильнее
                offset: Offset(0, _isPressed ? 6 : 10), // смещение тени
              ),
            ],
          ),
          width: widget.diameter,
          height: widget.diameter,
          child: Padding(
            padding: EdgeInsets.all(widget.diameter * 0.32),
            child: SvgPicture.asset(widget.icon, color: AppColors.bgLight),
          ),
        ),
      ),
    );
  }
}

// ======================= Боковые иконки =======================
class _BottomItem extends StatelessWidget {
  final String iconDefault;
  final String iconActive;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomItem({
    required this.iconDefault,
    required this.iconActive,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isActive ? iconActive : iconDefault;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

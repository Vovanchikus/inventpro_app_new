import 'package:flutter/material.dart';

class TabButtons extends StatelessWidget {
  final int activeTab;
  final void Function(int) onTabChanged;

  const TabButtons({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tabButton('Информация', 0),
        const SizedBox(width: 12),
        _tabButton('История', 1),
      ],
    );
  }

  Widget _tabButton(String text, int index) {
    final active = activeTab == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

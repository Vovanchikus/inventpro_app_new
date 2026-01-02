import 'package:flutter/material.dart';

class BackButtonWidget extends StatelessWidget {
  final double topPadding;

  const BackButtonWidget({super.key, required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 16,
      left: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
    );
  }
}

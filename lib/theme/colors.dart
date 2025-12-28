import 'package:flutter/material.dart';

/// Все цвета приложения
/// Используй: AppColors.primary, AppColors.textPrimary и т.д.
class AppColors {
  AppColors._(); // запрет создания экземпляра

  // === Основные цвета ===
  static const Color brand = Color(0xFF5B86CA);
  static const Color success = Color(0xFF48A53B);
  static const Color error = Color(0xFFE93850);

  // === Цвет Текста ===

  static const Color textTitle = Color(0xFF353566);
  static const Color textSubTitle = Color(0xFF787D89);
  static const Color textBody = Color(0xFF63686E);

  // === Фон ===
  static const Color bgApp = Color(0xFFF3F3F3);
  static const Color bgLight = Color(0xffffffff);
  static const Color bgBrand = Color(0x525B86CA);
  static const Color bgSuccess = Color(0x5248A53B);
  static const Color bgError = Color(0x52E93850);

  static const Color neutral300 = Color(0xFFDEDEE2);
  static const Color neutral400 = Color(0xFF8D919B);

  static const Color shadowBrand = Color(0x665B86CA);
}

import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/fonts.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Новый проект",
      color: AppColors.brand,
      theme: ThemeData(fontFamily: AppFonts.primary),
      home: const MainScreen(),
    );
  }
}

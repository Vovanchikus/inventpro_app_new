import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/colors.dart';
import 'theme/fonts.dart';
import 'screens/main_screen.dart';

// Импорт моделей Hive
import 'models/category.dart';
import 'models/product.dart';
import 'models/operation_type.dart';
import 'models/operation.dart';
import 'models/operation_product.dart';
import 'models/document.dart';

// Импорт Box helper
import 'boxes/hive_boxes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive
  await Hive.initFlutter();

  // Регистрация адаптеров Hive
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(ProductAdapter());
  Hive.registerAdapter(OperationTypeAdapter());
  Hive.registerAdapter(OperationAdapter());
  Hive.registerAdapter(OperationProductAdapter());
  Hive.registerAdapter(DocumentAdapter());

  // Открытие всех Box'ов
  await HiveBoxes.openAll();

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

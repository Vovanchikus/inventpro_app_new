import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hive/hive.dart';

import '../boxes/hive_boxes.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import 'product_screen.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    autoStart: true,
  );

  bool _isProcessing = false;

  Future<void> _handleCode(String code) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final box = Hive.box<Product>(HiveBoxes.products);

    final product = box.values.cast<Product?>().firstWhere(
      (p) => p?.invNumber == code,
      orElse: () => null,
    );

    if (!mounted) return;

    if (product != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductScreen(
            productId: product.id,
            title: product.name,
            inventoryNumber: product.invNumber,
            price: product.price,
            quantity: product.quantity,
            total: product.sum,
            images: const [],
            categoryPath: '',
          ),
        ),
      );

      _isProcessing = false;
      _cameraController.start();
    } else {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Товар не найден'),
          content: Text('QR-код "$code" не найден в базе.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _isProcessing = false;
                _cameraController.start();
              },
              child: const Text('Продолжить'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Сканер QR'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  _handleCode(code);
                  break;
                }
              }
            },
          ),

          /// рамка сканирования
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.brand, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../models/sync_progress_data.dart';

class SyncProgressModal extends StatelessWidget {
  final List<SyncProgressData> items;

  const SyncProgressModal({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Синхронизация данных',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final percent = item.total == 0
                  ? 0
                  : (item.done / item.total * 100).clamp(0, 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      item.iconAsset,
                      width: 24,
                      height: 24,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.title} (${item.done}/${item.total})',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: item.total == 0
                                  ? 0
                                  : item.done / item.total,
                              minHeight: 8,
                              backgroundColor: AppColors.neutral300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${percent.toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

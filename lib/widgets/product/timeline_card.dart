import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/colors.dart';

class TimelineCard extends StatelessWidget {
  final Map<String, dynamic> h;
  final bool isFirst;
  final bool isLast;

  const TimelineCard({
    super.key,
    required this.h,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    const double dotSize = 12;
    const double lineWidth = 2;
    const double spacing = 12;

    String dateStr = '-';
    final date = h['date'] as DateTime?;
    if (date != null) dateStr = DateFormat('dd.MM.yyyy').format(date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dotSize,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: lineWidth, color: Colors.blue),
                  )
                else
                  const Spacer(),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: lineWidth, color: Colors.blue),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: spacing),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(h['description'] ?? ''),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

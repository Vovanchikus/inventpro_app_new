import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:testing_app/theme/colors.dart';

class DashboardCard extends StatefulWidget {
  final String title;
  final int count;
  final String iconUrl;
  final Color iconColor;
  final Color iconBgColor;

  const DashboardCard({
    super.key,
    required this.title,
    required this.count,
    required this.iconUrl,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconBgColor, // фон контейнера
                    borderRadius: BorderRadius.circular(
                      24,
                    ), // радиус скругления
                  ),
                  child: SvgPicture.asset(
                    widget.iconUrl,
                    width: 24,
                    height: 24,
                    color: widget.iconColor,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                    Text(
                      widget.title,
                      style: TextStyle(fontSize: 15, color: AppColors.textBody),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/dashboard_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Общая информация',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    title: "Товаров",
                    count: 789,
                    iconUrl: "assets/icons/box.svg",
                    iconColor: AppColors.brand,
                    iconBgColor: AppColors.bgBrand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCard(
                    title: "Операций",
                    count: 258,
                    iconUrl: "assets/icons/arrow-right-left-simple.svg",
                    iconColor: AppColors.success,
                    iconBgColor: AppColors.bgSuccess,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    title: "Документов",
                    count: 126,
                    iconUrl: "assets/icons/file-list.svg",
                    iconColor: AppColors.error,
                    iconBgColor: AppColors.bgError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCard(
                    title: "Категорий",
                    count: 26,
                    iconUrl: "assets/icons/grid-category.svg",
                    iconColor: AppColors.neutral400,
                    iconBgColor: AppColors.neutral300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

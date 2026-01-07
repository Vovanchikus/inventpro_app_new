import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/photo_sync_status.dart';
import '../../models/product_sync_card_model.dart';
import '../../theme/colors.dart';

class ProductSyncCard extends StatelessWidget {
  const ProductSyncCard({
    super.key,
    required this.data,
    this.onRetry,
    this.onDetails,
    this.isRetrying = false,
  });

  final ProductSyncCardModel data;
  final VoidCallback? onRetry;
  final VoidCallback? onDetails;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(data.aggregatedStatus);
    final statusLabel = _statusLabel(data.aggregatedStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Preview(imagePath: data.previewImagePath),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(label: statusLabel, color: statusColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatsRow(data: data),
          const SizedBox(height: 12),
          _ProgressSection(progress: data.progress, total: data.totalImages),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isRetrying ? null : onRetry,
                  child: isRetrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Повторить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Подробнее'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(PhotoSyncStatus status) {
    switch (status) {
      case PhotoSyncStatus.pending:
        return Colors.orange;
      case PhotoSyncStatus.uploading:
        return AppColors.brand;
      case PhotoSyncStatus.error:
        return AppColors.error;
      case PhotoSyncStatus.synced:
        return AppColors.success;
      case PhotoSyncStatus.paused:
        return Colors.blueGrey;
    }
  }

  String _statusLabel(PhotoSyncStatus status) {
    switch (status) {
      case PhotoSyncStatus.pending:
        return 'Ожидает запуска';
      case PhotoSyncStatus.uploading:
        return 'Идёт синхронизация';
      case PhotoSyncStatus.error:
        return 'Есть ошибки';
      case PhotoSyncStatus.synced:
        return 'Все фото синхронизированы';
      case PhotoSyncStatus.paused:
        return 'Приостановлено';
    }
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    Widget child;

    if (imagePath == null) {
      child = _PlaceholderIcon(icon: Icons.photo_library_outlined);
    } else if (imagePath!.startsWith('http')) {
      child = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imagePath!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _PlaceholderIcon(icon: Icons.broken_image_outlined),
        ),
      );
    } else {
      final file = File(imagePath!);
      if (file.existsSync()) {
        child = ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
        );
      } else {
        child = _PlaceholderIcon(icon: Icons.image_not_supported_outlined);
      }
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: AppColors.bgApp,
      ),
      child: child,
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.neutral400, size: 32);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final ProductSyncCardModel data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      children: [
        _StatChip(label: 'Всего', value: data.totalImages.toString()),
        _StatChip(label: 'Ожидают', value: data.pendingCount.toString()),
        _StatChip(label: 'Загружаются', value: data.uploadingCount.toString()),
        _StatChip(label: 'Ошибки', value: data.errorCount.toString()),
        _StatChip(label: 'Готово', value: data.syncedCount.toString()),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSubTitle),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress, required this.total});

  final double progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Общий прогресс',
              style: TextStyle(fontSize: 14, color: AppColors.textSubTitle),
            ),
            Text(
              total == 0 ? 'Нет фото' : '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : progress,
            minHeight: 8,
            backgroundColor: AppColors.bgApp,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }
}

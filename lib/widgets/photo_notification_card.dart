import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/notifications_viewmodel.dart';
import '../models/notification_model.dart';

class PhotoNotificationCard extends StatelessWidget {
  final NotificationCardData data;
  const PhotoNotificationCard({super.key, required this.data});

  String _compactTime(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(ts);
    if (diff.inDays == 1) return 'вчера';
    return DateFormat('dd.MM.y').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Left icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.icon, color: data.iconColor, size: 22),
            ),

            const SizedBox(width: 12),

            // Center content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: data.iconColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            data.statusLabel,
                            style: TextStyle(
                              color: data.iconColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (data.onRetry != null &&
                          (data.model.status == NotificationStatus.pending ||
                              data.model.status == NotificationStatus.error))
                        TextButton(
                          onPressed: () async {
                            await data.onRetry!();
                          },
                          child: const Text('Повторить'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right time
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _compactTime(data.timestamp),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

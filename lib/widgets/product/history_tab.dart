import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'timeline_card.dart';

class HistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final bool loading;

  const HistoryTab({super.key, required this.history, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filtered = history
        .where((h) => (h['title']?.isNotEmpty ?? false))
        .toList();
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'История отсутствует',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((h) {
        final index = filtered.indexOf(h);
        final isFirst = index == 0;
        final isLast = index == filtered.length - 1;
        return TimelineCard(h: h, isFirst: isFirst, isLast: isLast);
      }).toList(),
    );
  }
}

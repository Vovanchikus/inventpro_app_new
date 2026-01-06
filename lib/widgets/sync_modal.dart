import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

class SyncModal extends StatelessWidget {
  final ValueNotifier<Map<String, double>> steps;
  final ValueNotifier<String> statusText;
  final ValueNotifier<bool> isError;

  const SyncModal({
    Key? key,
    required this.steps,
    required this.statusText,
    required this.isError,
  }) : super(key: key);

  double _computeOverall(Map<String, double> m) {
    if (m.isEmpty) return 0.0;
    final sum = m.values.fold<double>(0.0, (p, e) => p + e);
    return (sum / m.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: ValueListenableBuilder<bool>(
        valueListenable: isError,
        builder: (context, error, _) {
          return Text(error ? 'Ошибка синхронизации' : 'Синхронизация');
        },
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Map<String, double>>(
              valueListenable: steps,
              builder: (context, map, _) {
                final overall = _computeOverall(map);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: overall, minHeight: 6),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView(
                        children: map.entries.map((e) {
                          final name = e.key;
                          final value = e.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(name)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(value * 100).toStringAsFixed(0)}%',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: value,
                                  minHeight: 6,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: statusText,
              builder: (context, text, _) {
                return Text(text, textAlign: TextAlign.center);
              },
            ),
          ],
        ),
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: isError,
          builder: (context, error, _) {
            if (!error) return const SizedBox.shrink();
            return TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            );
          },
        ),
      ],
    );
  }
}

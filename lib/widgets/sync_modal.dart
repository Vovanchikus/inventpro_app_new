import 'package:flutter/material.dart';
import 'dart:math' as math;

class SyncModal extends StatefulWidget {
  final ValueNotifier<Map<String, double>> steps;
  final ValueNotifier<String> statusText;
  final ValueNotifier<bool> isError;

  const SyncModal({
    Key? key,
    required this.steps,
    required this.statusText,
    required this.isError,
  }) : super(key: key);

  @override
  _SyncModalState createState() => _SyncModalState();
}

class _SyncModalState extends State<SyncModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lastOverall = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _computeOverall(Map<String, double> m) {
    if (m.isEmpty) return 0.0;
    final sum = m.values.fold<double>(0.0, (p, e) => p + e);
    return (sum / m.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated icon with reactive color and subtle scale based on overall progress
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: widget.steps,
                builder: (context, map, _) {
                  final overall = _computeOverall(map);
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.isError,
                    builder: (context, error, __) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) {
                          return Transform.rotate(
                            angle: _controller.value * 2 * math.pi,
                            child: child,
                          );
                        },
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 1.0 + _lastOverall * 0.08,
                            end: 1.0 + overall * 0.08,
                          ),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          onEnd: () => _lastOverall = overall,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sync,
                              size: 36,
                              color: error
                                  ? Colors.red
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 14),

              const Text(
                'Синхронизация',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // Percentage text with smooth tween
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: widget.steps,
                builder: (context, map, _) {
                  final overall = _computeOverall(map);
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: _lastOverall, end: overall),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    onEnd: () => _lastOverall = overall,
                    builder: (context, value, _) {
                      final pctStr = (value * 100).toStringAsFixed(0);
                      return Text(
                        '$pctStr%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              // Current step description with animated switch
              ValueListenableBuilder<String>(
                valueListenable: widget.statusText,
                builder: (context, text, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      final inAnim = Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(
                        position: inAnim,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Text(
                      text,
                      key: ValueKey<String>(text),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: widget.isError,
            builder: (context, error, _) {
              if (!error) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              );
            },
          ),
        ],
      ),
    );
  }
}

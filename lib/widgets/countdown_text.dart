import 'dart:async';

import 'package:flutter/material.dart';

import '../models/tv_session_line.dart';
import '../theme/app_colors.dart';

/// Ticks once a second to repaint elapsed/remaining text for a single
/// session line. Purely local — never triggers a network refetch.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.line});

  final TvSessionLine line;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final pausedSeconds = line.totalPausedSeconds ?? 0;
    final rawElapsed =
        _now.difference(line.startTime) - Duration(seconds: pausedSeconds);
    final elapsed = rawElapsed.isNegative ? Duration.zero : rawElapsed;

    Duration? remaining;
    int? allowedSeconds;
    if (line.plannedDurationMinutes != null) {
      allowedSeconds =
          (line.plannedDurationMinutes! + (line.gracePeriodMinutes ?? 0)) * 60;
      remaining = Duration(seconds: allowedSeconds) - elapsed;
    }
    final isOvertime = remaining != null && remaining.isNegative;

    final progress = allowedSeconds != null && allowedSeconds > 0
        ? (elapsed.inSeconds / allowedSeconds).clamp(0.0, 1.0)
        : null;
    final urgencyColor = _urgencyColor(progress, isOvertime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timeBlock(Icons.timer_outlined, 'Elapsed', _format(elapsed), Colors.white),
            if (remaining != null) ...[
              const SizedBox(width: 14),
              isOvertime
                  ? _overtimeBadge(_format(remaining.abs()))
                  : _timeBlock(
                      Icons.hourglass_bottom,
                      'Remaining',
                      _format(remaining),
                      urgencyColor,
                    ),
            ],
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              width: 160,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(urgencyColor),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _urgencyColor(double? progress, bool isOvertime) {
    if (isOvertime) return AppColors.overtime;
    if (progress == null) return AppColors.live;
    if (progress >= 0.85) return AppColors.overtime;
    if (progress >= 0.6) return AppColors.theatre;
    return AppColors.live;
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _timeBlock(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _overtimeBadge(String overBy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.overtime.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.overtime, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.overtime.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 16, color: AppColors.overtime),
          const SizedBox(width: 6),
          Text(
            'OVERTIME +$overBy',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.overtime,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

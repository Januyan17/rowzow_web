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
    final referenceNow = line.endTime ?? _now;
    final rawElapsed =
        referenceNow.difference(line.startTime) - Duration(seconds: pausedSeconds);
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
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.timer_outlined,
                label: 'ELAPSED',
                value: _format(elapsed),
                valueColor: Colors.white,
                accentColor: Colors.white,
              ),
            ),
            if (remaining != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: isOvertime
                    ? _StatTile(
                        icon: Icons.warning_rounded,
                        label: 'OVERTIME',
                        value: '+${_format(remaining.abs())}',
                        valueColor: AppColors.overtime,
                        accentColor: AppColors.overtime,
                        highlighted: true,
                      )
                    : _StatTile(
                        icon: Icons.hourglass_bottom,
                        label: 'REMAINING',
                        value: _format(remaining),
                        valueColor: urgencyColor,
                        accentColor: urgencyColor,
                      ),
              ),
            ],
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              width: double.infinity,
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
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// A labelled time readout (elapsed/remaining/overtime), styled as a small
/// filled tile so the stats read as distinct "cards" instead of bare text
/// floating in empty space.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.accentColor,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color accentColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: highlighted ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: highlighted
            ? Border.all(color: accentColor.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

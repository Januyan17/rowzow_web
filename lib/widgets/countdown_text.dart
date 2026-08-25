import 'package:flutter/material.dart';

import '../models/tv_active_session.dart';
import '../theme/app_colors.dart';

/// Elapsed / remaining readout for one active session.
///
/// Stateless by design: [now] is driven by the board's single [SecondTicker]
/// and every figure is derived on the client from `start_time`,
/// `planned_duration_minutes`, `total_paused_seconds` and `paused_at`. The
/// server is never asked how much time is left.
class CountdownText extends StatelessWidget {
  const CountdownText({
    super.key,
    required this.session,
    required this.now,
    this.dimmed = false,
  });

  final TvActiveSession session;
  final DateTime now;

  /// Occupied tiles recede so the free stations read first, so the timers
  /// are toned down too. Overtime is the deliberate exception — it stays
  /// loud, because it is the one thing staff must notice from across the
  /// room.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final elapsed = session.elapsedAt(now);
    final remaining = session.remainingAt(now);
    final progress = session.progressAt(now);
    final isOvertime = remaining != null && remaining.isNegative;
    final paused = session.isPaused;

    // A paused session's figures are frozen, so drain the urgency colours
    // too — a red bar that isn't moving reads as a fault on a wall screen.
    // The time left is the point of the tile, so it keeps full urgency
    // colour even while the surrounding card is receded. ELAPSED is the
    // quieter half — it is history, not something anyone has to act on.
    final urgency = paused
        ? Colors.white54
        : _urgencyColor(progress, isOvertime);
    final elapsedColor = paused
        ? Colors.white60
        : (dimmed ? Colors.white70 : Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.timer_outlined,
                label: 'ELAPSED',
                value: _format(elapsed),
                valueColor: elapsedColor,
                accentColor: Colors.white,
              ),
            ),
            if (remaining != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: isOvertime && !paused
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
                        value: isOvertime
                            ? '+${_format(remaining.abs())}'
                            : _format(remaining),
                        valueColor: urgency,
                        accentColor: urgency,
                        // Tinted and outlined so the live timer reads as the
                        // active element next to the muted ELAPSED tile.
                        highlighted: !paused,
                      ),
              ),
            ] else ...[
              const SizedBox(width: 10),
              const Expanded(
                child: _StatTile(
                  icon: Icons.all_inclusive,
                  label: 'NO LIMIT',
                  value: 'Open',
                  valueColor: Colors.white70,
                  accentColor: Colors.white,
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
                valueColor: AlwaysStoppedAnimation(urgency),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Green with time to spare, amber past 60%, orange past 85%, red once it
  /// has actually run over.
  Color _urgencyColor(double? progress, bool isOvertime) {
    if (isOvertime) return AppColors.overtime;
    if (progress == null) return AppColors.live;
    if (progress >= 0.85) return AppColors.warning;
    if (progress >= 0.6) return AppColors.theatre;
    return AppColors.live;
  }

  static String _format(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final h = clamped.inHours;
    final m = clamped.inMinutes.remainder(60);
    final s = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// A labelled time readout, styled as a small filled tile so the stats read
/// as distinct cards rather than bare text floating in empty space.
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
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

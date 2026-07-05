import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Countdown strip for a not-yet-released game. Purely decorative — ticks
/// locally once a second and never touches session data or Supabase.
class UpcomingGameCountdown extends StatefulWidget {
  UpcomingGameCountdown({
    super.key,
    this.title = 'Grand Theft Auto VI',
    this.icon = Icons.local_police,
    DateTime? releaseDate,
  }) : releaseDate = releaseDate ?? DateTime(2026, 11, 12);

  final String title;
  final IconData icon;
  final DateTime releaseDate;

  @override
  State<UpcomingGameCountdown> createState() => _UpcomingGameCountdownState();
}

class _UpcomingGameCountdownState extends State<UpcomingGameCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.releaseDate.difference(DateTime.now());
    final released = remaining.isNegative;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        final badge = Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 7 : 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.theatre.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            released ? 'OUT NOW' : 'COMING SOON',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.theatre,
              letterSpacing: 0.6,
            ),
          ),
        );

        final titleRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: AppColors.theatre, size: isNarrow ? 18 : 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: isNarrow ? 15 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        final countdownText = Text(
          released ? 'Available now' : _format(remaining),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isNarrow ? 13 : 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: isNarrow ? 10 : 0),
          constraints: BoxConstraints(minHeight: isNarrow ? 0 : 64),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          // Mobile keeps the badge/title and countdown on separate lines so
          // neither gets cramped or clipped on narrow screens; web/tablet
          // keeps everything on one row like the popular-games banner.
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [badge, const SizedBox(width: 10), Expanded(child: titleRow)]),
                    const SizedBox(height: 8),
                    countdownText,
                  ],
                )
              : Row(
                  children: [
                    badge,
                    const SizedBox(width: 16),
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    countdownText,
                  ],
                ),
        );
      },
    );
  }

  static String _format(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }
}

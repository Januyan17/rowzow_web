import 'package:flutter/material.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';
import '../models/tv_session_line.dart';
import '../theme/app_colors.dart';
import 'countdown_text.dart';
import 'session_activity_sheet.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.ps5Stations,
  });

  final TvSession session;
  final List<Ps5Station> ps5Stations;

  @override
  Widget build(BuildContext context) {
    final lines = session.openLines;
    final accent = lines.isNotEmpty
        ? AppColors.forServiceType(lines.first.serviceType)
        : AppColors.ps5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final padding = isCompact ? 14.0 : 18.0;
        final avatarRadius = isCompact ? 17.0 : 20.0;
        final nameFontSize = isCompact ? 18.0 : 22.0;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: avatarRadius,
                              backgroundColor: accent.withValues(alpha: 0.18),
                              child: Text(
                                _initial(session.customerName),
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 15 : 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                session.customerName ?? 'Guest',
                                style: TextStyle(
                                  fontSize: nameFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (session.lines.length > 1)
                              _ViewActivityButton(
                                compact: isCompact,
                                onTap: () => showSessionActivitySheet(
                                  context,
                                  session,
                                  ps5Stations,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final line in lines) ...[
                          _LineSection(line: line, ps5Stations: ps5Stations),
                          if (line != lines.last)
                            const Divider(
                              height: 24,
                              color: AppColors.cardBorder,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initial(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

/// Entry point into the full per-line activity log. Collapses to an
/// icon-only tap target on narrow/mobile cards so it never pushes the
/// customer name off-screen.
class _ViewActivityButton extends StatelessWidget {
  const _ViewActivityButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.history, size: 18, color: Colors.white60),
        tooltip: 'View activity',
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.history, size: 16),
      label: const Text('Activity'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({required this.line, required this.ps5Stations});

  final TvSessionLine line;
  final List<Ps5Station> ps5Stations;

  @override
  Widget build(BuildContext context) {
    final stopped = line.endTime != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ServiceBadge(type: line.serviceType, muted: stopped),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._detailChips(),
                  _chip(
                    Icons.schedule_outlined,
                    'Started ${_formatStart(line.startTime)}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stopped) _StoppedSummary(line: line) else CountdownText(line: line),
      ],
    );
  }

  String _formatStart(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  List<Widget> _detailChips() {
    switch (line.serviceType) {
      case ServiceType.ps5:
        final units = line.ps5Units ?? 1;
        final controllers = line.ps5ControllersByUnit?.join(', ');
        final stations = (line.ps5StationIndices ?? const [])
            .map(
              (i) => i >= 0 && i < ps5Stations.length
                  ? ps5Stations[i].label
                  : 'PS5 ${i + 1}',
            )
            .join(', ');
        return [
          _chip(Icons.tv, '$units console${units == 1 ? '' : 's'}'),
          if (controllers != null)
            _chip(Icons.sports_esports_outlined, controllers),
          if (stations.isNotEmpty) _chip(Icons.place_outlined, stations),
        ];
      case ServiceType.theatre:
        final persons = line.theatrePersons ?? line.quantity;
        final hours = line.theatreHours;
        return [
          if (persons != null)
            _chip(
              Icons.groups_outlined,
              '$persons person${persons == 1 ? '' : 's'}',
            ),
          if (hours != null) _chip(Icons.schedule, '${hours}h'),
        ];
      case ServiceType.vr:
      case ServiceType.simulator:
        final games = num.tryParse(line.games ?? '');
        return [
          if (games != null)
            _chip(
              Icons.videogame_asset_outlined,
              '$games game${games == 1 ? '' : 's'}',
            ),
        ];
    }
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.type, this.muted = false});

  final ServiceType type;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (type) {
      ServiceType.ps5 => (Icons.sports_esports, 'PS5'),
      ServiceType.vr => (Icons.vrpano, 'VR'),
      ServiceType.simulator => (Icons.directions_car, 'SIM'),
      ServiceType.theatre => (Icons.theaters, 'THEATRE'),
    };
    final color = muted ? Colors.white24 : AppColors.forServiceType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: muted
            ? null
            : LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        color: muted ? Colors.white.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: muted
            ? null
            : [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: muted ? Colors.white54 : Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: muted ? Colors.white54 : Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, clearly-labelled state for a service line that has already
/// ended — deliberately small so a stopped line never competes visually
/// with the live ELAPSED/REMAINING tiles of sessions that are still running.
class _StoppedSummary extends StatelessWidget {
  const _StoppedSummary({required this.line});

  final TvSessionLine line;

  @override
  Widget build(BuildContext context) {
    final pausedSeconds = line.totalPausedSeconds ?? 0;
    final played =
        line.endTime!.difference(line.startTime) -
        Duration(seconds: pausedSeconds);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stop_circle_outlined,
            size: 14,
            color: Colors.white38,
          ),
          const SizedBox(width: 6),
          Text(
            'Stopped · played ${_format(played)}',
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final h = clamped.inHours;
    final m = clamped.inMinutes.remainder(60);
    final s = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

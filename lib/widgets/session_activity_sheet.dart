import 'package:flutter/material.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';
import '../models/tv_session_line.dart';
import '../theme/app_colors.dart';

/// Opens a mobile-first activity log for [session] — every service line it
/// has ever had, not just the ones still open. Lets staff see what a
/// customer switched through (e.g. PS5 → PS5 again) even after each
/// individual line has ended.
Future<void> showSessionActivitySheet(
  BuildContext context,
  TvSession session,
  List<Ps5Station> ps5Stations,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 480 ? screenWidth : 480,
              maxHeight: screenHeight * 0.82,
            ),
            child: _ActivitySheetBody(
              session: session,
              ps5Stations: ps5Stations,
            ),
          ),
        ),
      );
    },
  );
}

class _ActivitySheetBody extends StatelessWidget {
  const _ActivitySheetBody({required this.session, required this.ps5Stations});

  final TvSession session;
  final List<Ps5Station> ps5Stations;

  @override
  Widget build(BuildContext context) {
    final lines = [...session.lines]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity · ${session.customerName ?? 'Guest'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lines.length} service${lines.length == 1 ? '' : 's'} on this session',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              shrinkWrap: true,
              itemCount: lines.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _ActivityRow(line: lines[index], ps5Stations: ps5Stations),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.line, required this.ps5Stations});

  final TvSessionLine line;
  final List<Ps5Station> ps5Stations;

  @override
  Widget build(BuildContext context) {
    final stopped = line.endTime != null;
    final pausedSeconds = line.totalPausedSeconds ?? 0;
    final duration =
        (line.endTime ?? DateTime.now()).difference(line.startTime) -
        Duration(seconds: pausedSeconds);
    final color = stopped
        ? Colors.white38
        : AppColors.forServiceType(line.serviceType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(line.serviceType), size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelFor(line.serviceType, line, ps5Stations),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusPill(stopped: stopped),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _detail(Icons.play_circle_outline, _formatTime(line.startTime)),
              _detail(
                stopped ? Icons.stop_circle_outlined : Icons.timer_outlined,
                stopped ? _formatTime(line.endTime!) : 'Still running',
              ),
              _detail(Icons.hourglass_bottom, _formatDuration(duration)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white38),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  IconData _iconFor(ServiceType type) => switch (type) {
    ServiceType.ps5 => Icons.sports_esports,
    ServiceType.vr => Icons.vrpano,
    ServiceType.simulator => Icons.directions_car,
    ServiceType.theatre => Icons.theaters,
  };

  String _labelFor(
    ServiceType type,
    TvSessionLine line,
    List<Ps5Station> ps5Stations,
  ) {
    switch (type) {
      case ServiceType.ps5:
        final stations = (line.ps5StationIndices ?? const [])
            .map(
              (i) => i >= 0 && i < ps5Stations.length
                  ? ps5Stations[i].label
                  : 'PS5 ${i + 1}',
            )
            .join(', ');
        return stations.isEmpty ? 'PS5' : 'PS5 · $stations';
      case ServiceType.vr:
        return 'VR';
      case ServiceType.simulator:
        return 'Simulator';
      case ServiceType.theatre:
        return 'Theatre';
    }
  }

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  String _formatDuration(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final h = clamped.inHours;
    final m = clamped.inMinutes.remainder(60);
    final s = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.stopped});

  final bool stopped;

  @override
  Widget build(BuildContext context) {
    final color = stopped ? Colors.white38 : AppColors.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stopped ? 'STOPPED' : 'ACTIVE',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

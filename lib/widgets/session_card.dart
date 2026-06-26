import 'package:flutter/material.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';
import '../models/tv_session_line.dart';
import '../theme/app_colors.dart';
import 'countdown_text.dart';

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
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: accent.withValues(alpha: 0.18),
                        child: Text(
                          _initial(session.customerName),
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.customerName ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final line in lines) ...[
                    _LineSection(line: line, ps5Stations: ps5Stations),
                    if (line != lines.last) const Divider(
                      height: 20,
                      color: AppColors.cardBorder,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({required this.line, required this.ps5Stations});

  final TvSessionLine line;
  final List<Ps5Station> ps5Stations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ServiceBadge(type: line.serviceType),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _detailChips(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CountdownText(line: line),
      ],
    );
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
            _chip(Icons.groups_outlined, '$persons person${persons == 1 ? '' : 's'}'),
          if (hours != null) _chip(Icons.schedule, '${hours}h'),
        ];
      case ServiceType.vr:
      case ServiceType.simulator:
        final controllers = line.quantity;
        final games = num.tryParse(line.games ?? '');
        return [
          if (controllers != null)
            _chip(
              Icons.sports_esports_outlined,
              '$controllers controller${controllers == 1 ? '' : 's'}',
            ),
          if (games != null) _chip(Icons.videogame_asset_outlined, '$games game${games == 1 ? '' : 's'}'),
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
  const _ServiceBadge({required this.type});

  final ServiceType type;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (type) {
      ServiceType.ps5 => (Icons.sports_esports, 'PS5'),
      ServiceType.vr => (Icons.vrpano, 'VR'),
      ServiceType.simulator => (Icons.directions_car, 'SIM'),
      ServiceType.theatre => (Icons.theaters, 'THEATRE'),
    };
    final color = AppColors.forServiceType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

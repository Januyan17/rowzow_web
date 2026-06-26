import 'package:flutter/material.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';
import '../models/tv_session_line.dart';
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
    return Card(
      color: const Color(0xFF1B1B1F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.customerName ?? 'Guest',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              _LineRow(line: line, ps5Stations: ps5Stations),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.ps5Stations});

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
              child: Text(
                _details(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CountdownText(line: line),
      ],
    );
  }

  String _details() {
    switch (line.serviceType) {
      case ServiceType.ps5:
        final units = line.ps5Units ?? 1;
        final controllers = line.ps5ControllersByUnit?.join(', ') ?? '-';
        final stations = (line.ps5StationIndices ?? const [])
            .map(
              (i) => i >= 0 && i < ps5Stations.length
                  ? ps5Stations[i].label
                  : 'PS5 ${i + 1}',
            )
            .join(', ');
        return '$units console${units == 1 ? '' : 's'} · '
            'controllers: $controllers'
            '${stations.isNotEmpty ? ' · $stations' : ''}';
      case ServiceType.theatre:
        final persons = line.theatrePersons ?? line.quantity;
        final hours = line.theatreHours;
        return '${persons ?? '-'} person${(persons ?? 0) == 1 ? '' : 's'}'
            '${hours != null ? ' · ${hours}h' : ''}';
      case ServiceType.vr:
      case ServiceType.simulator:
        final controllers = line.quantity;
        final games = num.tryParse(line.games ?? '');
        return [
          if (controllers != null)
            '$controllers controller${controllers == 1 ? '' : 's'}',
          if (games != null) '$games game${games == 1 ? '' : 's'}',
        ].join(' · ');
    }
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.type});

  final ServiceType type;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (type) {
      ServiceType.ps5 => (Colors.blue, Icons.sports_esports, 'PS5'),
      ServiceType.vr => (Colors.purple, Icons.vrpano, 'VR'),
      ServiceType.simulator => (Colors.green, Icons.directions_car, 'SIM'),
      ServiceType.theatre => (Colors.amber, Icons.theaters, 'THEATRE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/tv_session_line.dart';

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
    if (line.plannedDurationMinutes != null) {
      final allowedSeconds =
          (line.plannedDurationMinutes! + (line.gracePeriodMinutes ?? 0)) * 60;
      remaining = Duration(seconds: allowedSeconds) - elapsed;
    }
    final isOvertime = remaining != null && remaining.isNegative;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _timeBlock('Elapsed', _format(elapsed)),
        if (remaining != null) ...[
          const SizedBox(width: 16),
          isOvertime
              ? _overtimeBadge(_format(remaining.abs()))
              : _timeBlock('Remaining', _format(remaining)),
        ],
      ],
    );
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _timeBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _overtimeBadge(String overBy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'OVERTIME +$overBy',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

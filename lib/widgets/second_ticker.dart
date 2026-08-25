import 'dart:async';

import 'package:flutter/material.dart';

/// Rebuilds its subtree once a second with the current wall-clock time.
///
/// The board keeps one ticker at the top rather than a Timer inside every
/// countdown, so a screen full of stations still only wakes once a second.
/// Purely local: ticking repaints, it never triggers a refetch.
class SecondTicker extends StatefulWidget {
  const SecondTicker({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

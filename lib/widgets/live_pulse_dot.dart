import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small breathing dot used next to "LIVE" / active-session indicators.
class LivePulseDot extends StatefulWidget {
  const LivePulseDot({super.key, this.color = AppColors.live, this.size = 10});

  final Color color;
  final double size;

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6 - (t * 0.4)),
                blurRadius: 4 + (t * 10),
                spreadRadius: t * 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

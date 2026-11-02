import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'bouncing_football.dart';
import 'space_skirmish.dart';

/// Full-screen ambient backdrop: slow aurora light, a twinkling star field,
/// faint orbit rings and a few drifting controller-button glyphs.
///
/// Everything is painted in code — no image assets — and kept at low
/// opacity so it never competes with the tiles for attention. The animated
/// layer sits behind a [RepaintBoundary] so it never forces the board
/// itself to repaint.
class GamingBackdrop extends StatefulWidget {
  const GamingBackdrop({super.key});

  @override
  State<GamingBackdrop> createState() => _GamingBackdropState();
}

class _GamingBackdropState extends State<GamingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.background),
        ),
        RepaintBoundary(
          child: CustomPaint(painter: _BackdropPainter(_controller)),
        ),
        const SpaceSkirmish(),
        const BouncingFootball(),
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  // Fixed seeds so the scene looks the same on every load.
  static final _stars = List.generate(90, (i) {
    final r = math.Random(i * 104729 + 7);
    return (
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 0.6 + r.nextDouble() * 1.4,
      phase: r.nextDouble(),
    );
  });

  static final _glyphs = List.generate(10, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      kind: i % 4,
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 16 + r.nextDouble() * 22,
      speed: 0.3 + r.nextDouble() * 0.5,
      phase: r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    _paintAurora(canvas, size, t);
    _paintOrbits(canvas, size, t);
    _paintStars(canvas, size, t);
    _paintGlyphs(canvas, size, t);
  }

  void _paintAurora(Canvas canvas, Size size, double t) {
    final a = t * 2 * math.pi;
    void glow(Offset c, double radius, Color color) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    final r = size.longestSide * 0.55;
    glow(
      Offset(
        size.width * (0.18 + 0.08 * math.sin(a)),
        size.height * (0.05 + 0.06 * math.cos(a)),
      ),
      r,
      AppColors.ps5.withValues(alpha: 0.14),
    );
    glow(
      Offset(
        size.width * (0.85 + 0.06 * math.cos(a)),
        size.height * (0.25 + 0.08 * math.sin(a)),
      ),
      r * 0.85,
      AppColors.auroraViolet.withValues(alpha: 0.11),
    );
    glow(
      Offset(
        size.width * (0.45 + 0.10 * math.sin(a + 1.5)),
        size.height * 1.0,
      ),
      r,
      AppColors.auroraCyan.withValues(alpha: 0.07),
    );

    // A soft ribbon of light sweeping across the upper third.
    final ribbon = Path();
    final baseY = size.height * 0.32;
    ribbon.moveTo(0, baseY);
    for (var x = 0.0; x <= size.width; x += 24) {
      final y =
          baseY +
          math.sin(x / size.width * 2 * math.pi + a) * size.height * 0.06 +
          math.sin(x / size.width * 5 * math.pi - a * 2) * size.height * 0.015;
      ribbon.lineTo(x, y);
    }
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
        ..shader = LinearGradient(
          colors: [
            AppColors.auroraCyan.withValues(alpha: 0),
            AppColors.auroraCyan.withValues(alpha: 0.07),
            AppColors.auroraViolet.withValues(alpha: 0.08),
            AppColors.auroraViolet.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  /// Large concentric rings centred off-screen bottom-right, like a planet's
  /// orbit lines, with a small light travelling along each.
  void _paintOrbits(Canvas canvas, Size size, double t) {
    final c = Offset(size.width * 1.02, size.height * 1.08);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 1; i <= 4; i++) {
      final radius = size.shortestSide * (0.35 + i * 0.22);
      canvas.drawCircle(c, radius, ring);
      final angle = math.pi + (t * (i.isEven ? -1 : 1) * 2 * math.pi / i) + i;
      final p = c + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        p,
        2.2,
        Paint()
          ..color = AppColors.auroraCyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  void _paintStars(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final s in _stars) {
      final twinkle = 0.5 + 0.5 * math.sin((t * 6 + s.phase) * 2 * math.pi);
      paint.color = Colors.white.withValues(alpha: 0.08 + 0.22 * twinkle);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
    }
  }

  void _paintGlyphs(Canvas canvas, Size size, double t) {
    for (final g in _glyphs) {
      // Drift upwards and wrap, with a slow side-to-side sway.
      final progress = (g.y - t * g.speed + g.phase) % 1.0;
      final y = progress * (size.height + 80) - 40;
      final x = g.x * size.width + math.sin((t + g.phase) * 2 * math.pi) * 14;
      // Fade in from the bottom edge and out towards the top.
      final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.05 * fade);

      canvas.save();
      canvas.translate(x, y);
      final s = g.size / 2;
      switch (g.kind) {
        case 0:
          canvas.drawPath(
            Path()
              ..moveTo(0, -s)
              ..lineTo(s * 0.9, s * 0.65)
              ..lineTo(-s * 0.9, s * 0.65)
              ..close(),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, s * 0.85, paint);
        case 2:
          canvas.drawLine(Offset(-s * 0.7, -s * 0.7), Offset(s * 0.7, s * 0.7), paint);
          canvas.drawLine(Offset(s * 0.7, -s * 0.7), Offset(-s * 0.7, s * 0.7), paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s * 1.5, height: s * 1.5),
              Radius.circular(s * 0.2),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

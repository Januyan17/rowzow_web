import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A football bouncing around the backdrop: it drops, squashes on each
/// landing, rebounds off the screen edges, spins with its travel, and gets
/// a fresh kick (with speed lines) whenever it runs out of bounce.
///
/// Lives behind the cards, never takes input, and is hidden when the
/// platform asks for reduced motion.
class BouncingFootball extends StatefulWidget {
  const BouncingFootball({super.key});

  @override
  State<BouncingFootball> createState() => _BouncingFootballState();
}

class _BouncingFootballState extends State<BouncingFootball>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _Ball();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      _sim.step(dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _sim.size = constraints.biggest;
            return CustomPaint(painter: _BallPainter(_sim));
          },
        ),
      ),
    );
  }
}

class _Ball extends ChangeNotifier {
  final _rand = math.Random(9);

  Size size = Size.zero;
  Offset pos = Offset.zero;
  Offset vel = Offset.zero;
  double spin = 0;

  /// 1 right after a landing, easing back to 0 — drives the squash.
  double squash = 0;

  /// 1 right after a kick, fading — drives the speed lines.
  double kick = 0;
  bool _placed = false;

  double get radius => (size.shortestSide * 0.028).clamp(14.0, 30.0);
  double get floor => size.height - radius - 6;

  void step(double dt) {
    if (size.isEmpty) return;
    if (!_placed) {
      _placed = true;
      pos = Offset(size.width * 0.15, size.height * 0.3);
      _kick();
    }
    final g = size.height * 1.6;
    vel += Offset(0, g) * dt;
    pos += vel * dt;
    spin += vel.dx / radius * dt;
    squash = math.max(0, squash - dt * 6);
    kick = math.max(0, kick - dt * 1.8);

    // Ceiling, just in case.
    if (pos.dy < radius && vel.dy < 0) {
      pos = Offset(pos.dx, radius);
      vel = Offset(vel.dx, -vel.dy * 0.6);
    }
    // Side walls.
    if (pos.dx < radius && vel.dx < 0) {
      pos = Offset(radius, pos.dy);
      vel = Offset(-vel.dx * 0.85, vel.dy);
    } else if (pos.dx > size.width - radius && vel.dx > 0) {
      pos = Offset(size.width - radius, pos.dy);
      vel = Offset(-vel.dx * 0.85, vel.dy);
    }
    // Floor: bounce with a little energy lost each time, and kick again
    // once the bounces get small.
    if (pos.dy > floor && vel.dy > 0) {
      pos = Offset(pos.dx, floor);
      squash = (vel.dy / (size.height * 1.4)).clamp(0.2, 1.0);
      vel = Offset(vel.dx * 0.92, -vel.dy * 0.78);
      if (vel.dy.abs() < size.height * 0.55) _kick();
    }
    notifyListeners();
  }

  void _kick() {
    // Aim back towards the middle so it keeps crossing the screen.
    final towardsCentre = pos.dx < size.width / 2 ? 1.0 : -1.0;
    final dir = _rand.nextDouble() < 0.8 ? towardsCentre : -towardsCentre;
    // Launch just hard enough to peak somewhere in the upper part of the
    // screen, never above it: v = sqrt(2·g·rise).
    final peakY = size.height * (0.12 + _rand.nextDouble() * 0.28);
    final rise = math.max(pos.dy - peakY, radius);
    final up = math.sqrt(2 * size.height * 1.6 * rise);
    vel = Offset(dir * size.width * (0.18 + _rand.nextDouble() * 0.22), -up);
    kick = 1;
  }
}

class _BallPainter extends CustomPainter {
  _BallPainter(this.sim) : super(repaint: sim);

  final _Ball sim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = sim.radius;
    final p = sim.pos;

    // Soft shadow on the floor, tighter and darker as the ball nears it.
    final height = ((sim.floor - p.dy) / sim.floor).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, sim.floor + r + 2),
        width: r * (2.4 - height * 1.2),
        height: r * 0.45,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * (1 - height * 0.7))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Speed lines streaming behind a fresh kick.
    if (sim.kick > 0 && sim.vel.distance > 1) {
      final back = -sim.vel / sim.vel.distance;
      final side = Offset(-back.dy, back.dx);
      final line = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35 * sim.kick);
      for (final k in [-0.6, 0.0, 0.6]) {
        final start = p + back * r * 1.2 + side * r * k;
        canvas.drawLine(
          start,
          start + back * r * (1.6 + (k == 0 ? 0.8 : 0)),
          line,
        );
      }
    }

    canvas.save();
    canvas.translate(p.dx, p.dy + r * 0.25 * sim.squash);
    // Squash on landing: wider and flatter, preserving the feel of mass.
    canvas.scale(1 + 0.22 * sim.squash, 1 - 0.25 * sim.squash);

    final ball = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFE4E8F2), Color(0xFF9AA3B8)],
          stops: [0, 0.55, 1],
        ).createShader(ball),
    );

    // Classic panels: a pentagon in the middle and five around it,
    // turning with the spin and clipped to the ball.
    canvas.save();
    canvas.clipPath(Path()..addOval(ball));
    canvas.rotate(sim.spin);
    final patch = Paint()..color = const Color(0xFF151827);
    Path pentagon(Offset c, double size, double rot) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = rot + i * 2 * math.pi / 5 - math.pi / 2;
        final pt = c + Offset(math.cos(a), math.sin(a)) * size;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path..close();
    }

    canvas.drawPath(pentagon(Offset.zero, r * 0.36, 0), patch);
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..color = const Color(0xFF151827).withValues(alpha: 0.6);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(dir * r * 0.36, dir * r * 0.7, seam);
      canvas.drawPath(pentagon(dir * r * 0.98, r * 0.3, a + math.pi), patch);
    }
    canvas.restore();

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BallPainter oldDelegate) => oldDelegate.sim != sim;
}

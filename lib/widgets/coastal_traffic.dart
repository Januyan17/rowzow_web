import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Night traffic on the coastal highway along the bottom of the GTA
/// banner: sports cars, muscle cars and motorbikes in two lanes, with
/// headlight glow, taillights, spinning wheels and the odd wheelie.
///
/// Decorative only — never takes input, and parks when the platform asks
/// for reduced motion.
class CoastalTraffic extends StatefulWidget {
  const CoastalTraffic({super.key, required this.roadTopFrac});

  /// Where the road starts, as a fraction of the banner height; it runs
  /// to the bottom edge.
  final double roadTopFrac;

  @override
  State<CoastalTraffic> createState() => _CoastalTrafficState();
}

class _CoastalTrafficState extends State<CoastalTraffic>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _Traffic();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      _sim.step(dt);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _sim
              ..size = constraints.biggest
              ..roadTopFrac = widget.roadTopFrac;
            return CustomPaint(painter: _TrafficPainter(_sim));
          },
        ),
      ),
    );
  }
}

enum _Kind { sports, muscle, bike }

class _Vehicle {
  _Vehicle(this.kind, this.lane, this.x, this.speed, this.color);

  final _Kind kind;

  /// 0 = far lane (drives left, smaller), 1 = near lane (drives right).
  final int lane;
  double x;
  final double speed;
  final Color color;
  double wheel = 0;

  /// Motorbikes only: 0 → 1 front wheel lift.
  double wheelie = 0;
  double wheelieIn = 0;
}

class _Traffic extends ChangeNotifier {
  final _rand = math.Random(17);

  Size size = Size.zero;
  double roadTopFrac = 0.83;
  double time = 0;

  final vehicles = <_Vehicle>[];
  final _spawnIn = [0.4, 1.4];

  static const palette = [
    Color(0xFFFF3DCB),
    Color(0xFF5EE7FF),
    Color(0xFFFF9F5A),
    Color(0xFFFFD54A),
    Color(0xFF8B7BFF),
  ];

  double get roadTop => size.height * roadTopFrac;
  double get roadBottom => size.height;

  /// Ground line for each lane.
  double laneY(int lane) => lane == 0
      ? roadTop + (roadBottom - roadTop) * 0.42
      : roadBottom - (roadBottom - roadTop) * 0.06;

  /// Vehicle scale per lane: the far lane reads smaller.
  /// Vehicles are ~30 units tall: the near lane fills most of the road,
  /// the far lane half of it.
  double scaleFor(int lane) =>
      (roadBottom - roadTop) * (lane == 0 ? 0.62 : 1.05) / 30;

  void step(double dt) {
    if (size.isEmpty) return;
    time += dt;
    for (var lane = 0; lane < 2; lane++) {
      _spawnIn[lane] -= dt;
      if (_spawnIn[lane] <= 0) {
        _spawn(lane);
        _spawnIn[lane] = 1.6 + _rand.nextDouble() * 2.6;
      }
    }
    for (final v in vehicles) {
      final dir = v.lane == 1 ? 1.0 : -1.0;
      v.x += dir * v.speed * dt;
      v.wheel += v.speed * dt / (8 * scaleFor(v.lane)) * dir;
      if (v.kind == _Kind.bike) {
        v.wheelieIn -= dt;
        if (v.wheelieIn <= 0 && v.wheelie == 0) {
          v.wheelieIn = 99; // once per pass
          v.wheelie = 0.001;
        }
        if (v.wheelie > 0) {
          v.wheelie = math.min(1, v.wheelie + dt * 2);
        }
      }
    }
    vehicles.removeWhere((v) => v.x < -120 || v.x > size.width + 120);
    notifyListeners();
  }

  void _spawn(int lane) {
    final r = _rand.nextDouble();
    final kind = r < 0.4 ? _Kind.sports : (r < 0.7 ? _Kind.muscle : _Kind.bike);
    final base = size.width / 7; // crosses in ~7s, faster for sports & bikes
    final speed =
        base *
        switch (kind) {
          _Kind.sports => 1.5 + _rand.nextDouble() * 0.6,
          _Kind.muscle => 1.1 + _rand.nextDouble() * 0.4,
          _Kind.bike => 1.7 + _rand.nextDouble() * 0.6,
        } *
        (lane == 0 ? 0.8 : 1);
    final x = lane == 1 ? -100.0 : size.width + 100;
    // Don't spawn on top of a slower car still near the entry.
    final blocked = vehicles.any(
      (v) => v.lane == lane && (v.x - x).abs() < 140,
    );
    if (blocked) return;
    vehicles.add(
      _Vehicle(kind, lane, x, speed, palette[_rand.nextInt(palette.length)])
        ..wheelieIn = kind == _Kind.bike && _rand.nextDouble() < 0.5
            ? 0.8 + _rand.nextDouble() * 1.5
            : 99,
    );
  }
}

class _TrafficPainter extends CustomPainter {
  _TrafficPainter(this.sim) : super(repaint: sim);

  final _Traffic sim;

  static const _ink = Color(0xFF0A0818);

  @override
  void paint(Canvas canvas, Size size) {
    // Far lane first so near traffic passes in front.
    for (final lane in [0, 1]) {
      for (final v in sim.vehicles.where((v) => v.lane == lane)) {
        _vehicle(canvas, v);
      }
    }
  }

  void _vehicle(Canvas canvas, _Vehicle v) {
    final s = sim.scaleFor(v.lane);
    final dir = v.lane == 1 ? 1.0 : -1.0;
    final dim = v.lane == 0 ? 0.7 : 1.0;
    canvas.save();
    canvas.translate(v.x, sim.laneY(v.lane));
    canvas.scale(dir * s, s);

    // Headlight glow spilling onto the road ahead.
    final beam = Rect.fromLTWH(18, -14, 90, 16);
    canvas.drawPath(
      Path()
        ..moveTo(40, -9)
        ..lineTo(110, -16)
        ..lineTo(110, 2)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF1C9).withValues(alpha: 0.5 * dim),
            const Color(0xFFFFF1C9).withValues(alpha: 0),
          ],
        ).createShader(beam),
    );

    switch (v.kind) {
      case _Kind.sports:
        _car(canvas, v, dim, low: true);
      case _Kind.muscle:
        _car(canvas, v, dim, low: false);
      case _Kind.bike:
        _bike(canvas, v, dim);
    }
    canvas.restore();
  }

  /// Car in car units: ~80 long, facing +x, wheels on the ground at y=0.
  void _car(Canvas canvas, _Vehicle v, double dim, {required bool low}) {
    final body = low
        ? (Path()
            ..moveTo(-38, -6)
            ..lineTo(-36, -13)
            ..lineTo(-14, -15)
            ..lineTo(-2, -24)
            ..lineTo(14, -24)
            ..lineTo(26, -15)
            ..lineTo(40, -12)
            ..lineTo(42, -6)
            ..close())
        : (Path()
            ..moveTo(-38, -6)
            ..lineTo(-38, -16)
            ..lineTo(-18, -17)
            ..lineTo(-10, -28)
            ..lineTo(12, -28)
            ..lineTo(20, -17)
            ..lineTo(38, -16)
            ..lineTo(40, -6)
            ..close());
    canvas.drawPath(
      body.shift(const Offset(0.8, -0.8)),
      Paint()..color = v.color.withValues(alpha: dim),
    );
    canvas.drawPath(body, Paint()..color = _ink);
    // Window glint.
    canvas.drawPath(
      low
          ? (Path()
              ..moveTo(-10, -16)
              ..lineTo(0, -22)
              ..lineTo(12, -22)
              ..lineTo(20, -16)
              ..close())
          : (Path()
              ..moveTo(-15, -17)
              ..lineTo(-9, -26)
              ..lineTo(10, -26)
              ..lineTo(15, -17)
              ..close()),
      Paint()..color = v.color.withValues(alpha: 0.35 * dim),
    );
    _wheel(canvas, const Offset(-24, -6), 6.5, v.wheel, v.color, dim);
    _wheel(canvas, const Offset(26, -6), 6.5, v.wheel, v.color, dim);
    _lights(canvas, const Offset(40, -11), const Offset(-37, -11), dim);
  }

  /// Motorbike with a crouched rider; can pop a wheelie about the rear axle.
  void _bike(Canvas canvas, _Vehicle v, double dim) {
    final lift = Curves.easeOut.transform(v.wheelie) * 0.35;
    canvas.save();
    canvas.translate(-16, -6);
    canvas.rotate(-lift);
    canvas.translate(16, 6);

    final ink = Paint()..color = _ink;
    final rim = Paint()..color = v.color.withValues(alpha: dim);
    void frame(Paint p) {
      canvas.drawPath(
        Path()
          ..moveTo(-18, -9)
          ..lineTo(-4, -16)
          ..lineTo(12, -17)
          ..lineTo(18, -10)
          ..lineTo(4, -8)
          ..close(),
        p,
      );
      // Rider: tucked torso, helmet, arm to the bars, leg to the peg.
      canvas.drawPath(
        Path()
          ..moveTo(-8, -16)
          ..lineTo(2, -30)
          ..lineTo(10, -30)
          ..lineTo(4, -16)
          ..close(),
        p,
      );
      canvas.drawCircle(const Offset(10, -33), 4.5, p);
      final limb = Paint()
        ..color = p.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(6, -27), const Offset(15, -19), limb);
      canvas.drawLine(const Offset(-4, -16), const Offset(2, -9), limb);
    }

    canvas.save();
    canvas.translate(0.8, -0.8);
    frame(rim);
    canvas.restore();
    frame(ink);
    // Visor glint.
    canvas.drawRect(
      const Rect.fromLTWH(11, -35, 4, 2),
      Paint()..color = v.color.withValues(alpha: 0.9 * dim),
    );
    _wheel(canvas, const Offset(-16, -6), 6, v.wheel, v.color, dim);
    _wheel(canvas, const Offset(18, -6), 6, v.wheel, v.color, dim);
    _lights(canvas, const Offset(19, -14), const Offset(-19, -11), dim);
    canvas.restore();
  }

  void _wheel(
    Canvas canvas,
    Offset c,
    double r,
    double spin,
    Color color,
    double dim,
  ) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF05040C));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.6 * dim),
    );
    final spoke = Paint()
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.35 * dim);
    for (var i = 0; i < 3; i++) {
      final a = spin + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * (r - 1.5);
      canvas.drawLine(c - d, c + d, spoke);
    }
  }

  void _lights(Canvas canvas, Offset head, Offset tail, double dim) {
    canvas.drawCircle(
      head,
      4.5,
      Paint()
        ..color = const Color(0xFFFFF6DA).withValues(alpha: dim)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      tail,
      3.8,
      Paint()
        ..color = const Color(0xFFFF2E4D).withValues(alpha: dim)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_TrafficPainter oldDelegate) => oldDelegate.sim != sim;
}

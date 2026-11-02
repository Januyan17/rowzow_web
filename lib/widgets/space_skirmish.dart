import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';

/// Ambient backdrop scene: a small starfighter makes a pass across the
/// screen every so often, firing laser bolts at drifting drones that burst
/// into sparks and a shockwave ring, then respawn.
///
/// Purely decorative. It lives behind the tiles, never takes input, is
/// drawn at low intensity so it never competes with the timers, and stays
/// off entirely when the platform asks for reduced motion.
class SpaceSkirmish extends StatefulWidget {
  const SpaceSkirmish({super.key});

  @override
  State<SpaceSkirmish> createState() => _SpaceSkirmishState();
}

class _SpaceSkirmishState extends State<SpaceSkirmish>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _Skirmish();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      // Clamp so a backgrounded tab doesn't teleport everything on return.
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
            return CustomPaint(
              size: constraints.biggest,
              painter: _SkirmishPainter(_sim),
            );
          },
        ),
      ),
    );
  }
}

class _Drone {
  _Drone(this.pos, this.vel, this.radius, this.spin);

  Offset pos;
  Offset vel;
  final double radius;
  final double spin;
  double angle = 0;
  bool alive = true;

  /// 0 → 1 fade-in after a respawn.
  double appear = 1;
  double respawnIn = 0;
}

class _Bolt {
  _Bolt(this.pos, this.vel);

  Offset pos;
  final Offset vel;
  double life = 1.1;
}

class _Spark {
  _Spark(this.pos, this.vel, this.life, this.color);

  Offset pos;
  Offset vel;
  double life;
  final double maxLife = 1;
  final Color color;
}

class _Ring {
  _Ring(this.pos);

  final Offset pos;
  double t = 0;
}

/// The whole scene's state, stepped once per frame. Notifies its painter
/// directly so a frame never rebuilds a widget.
class _Skirmish extends ChangeNotifier {
  final _rand = math.Random(7);

  Size size = Size.zero;

  final drones = <_Drone>[];
  final bolts = <_Bolt>[];
  final sparks = <_Spark>[];
  final rings = <_Ring>[];

  static const _passDuration = 13.0;
  static const _passGap = 7.0;

  /// Seconds into the current pass + gap cycle. Starts a little in so the
  /// first pass begins soon after the board opens.
  double _cycle = _passDuration + _passGap - 2.0;
  bool _leftToRight = true;
  double _laneY = 0.3;
  double _fireCooldown = 0;

  /// Seconds left on the muzzle flash at the ship's nose.
  double muzzle = 0;

  /// Scene clock, for effects like the engine flicker.
  double time = 0;

  Offset? shipPos;
  double shipHeading = 0;

  void step(double dt) {
    if (size.isEmpty) return;
    if (drones.isEmpty) _seedDrones();
    time += dt;

    _stepShip(dt);
    _stepDrones(dt);
    _stepBolts(dt);
    _stepEffects(dt);
    notifyListeners();
  }

  void _seedDrones() {
    for (var i = 0; i < 5; i++) {
      drones.add(_newDrone(randomPlace: true));
    }
  }

  _Drone _newDrone({bool randomPlace = false}) {
    final w = size.width;
    final h = size.height;
    final pos = randomPlace
        ? Offset(_rand.nextDouble() * w, h * (0.15 + _rand.nextDouble() * 0.75))
        : Offset(
            _rand.nextBool() ? -30 : w + 30,
            h * (0.15 + _rand.nextDouble() * 0.75),
          );
    final speed = 10 + _rand.nextDouble() * 16;
    final dir = _rand.nextDouble() * 2 * math.pi;
    return _Drone(
      pos,
      Offset(math.cos(dir), math.sin(dir)) * speed,
      9 + _rand.nextDouble() * 8,
      (_rand.nextDouble() - 0.5) * 1.6,
    );
  }

  void _stepShip(double dt) {
    _cycle += dt;
    if (_cycle >= _passDuration + _passGap) {
      _cycle = 0;
      _leftToRight = !_leftToRight;
      _laneY = 0.18 + _rand.nextDouble() * 0.64;
    }
    if (_cycle > _passDuration) {
      shipPos = null;
      return;
    }

    final w = size.width;
    final h = size.height;
    final p = _cycle / _passDuration;
    // Ease in and out of the screen edges so the pass feels piloted.
    final eased = p < 0.5
        ? 2 * p * p
        : 1 - math.pow(-2 * p + 2, 2).toDouble() / 2;
    final xFrac = _leftToRight ? eased : 1 - eased;
    final x = -80 + xFrac * (w + 160);
    final wobble = math.sin(_cycle * 1.3) * h * 0.06;
    final y = h * _laneY + wobble;

    final prev = shipPos;
    shipPos = Offset(x, y);
    if (prev != null && (shipPos! - prev).distance > 0.01) {
      shipHeading = (shipPos! - prev).direction;
    } else {
      shipHeading = _leftToRight ? 0 : math.pi;
    }

    _fireCooldown -= dt;
    muzzle = math.max(0, muzzle - dt);
    if (_fireCooldown <= 0) _tryFire();
  }

  void _tryFire() {
    final ship = shipPos!;
    final forward = Offset(math.cos(shipHeading), math.sin(shipHeading));
    _Drone? best;
    var bestDist = double.infinity;
    for (final d in drones) {
      if (!d.alive || d.appear < 1) continue;
      final to = d.pos - ship;
      final dist = to.distance;
      // Only shoot at drones roughly ahead and within range.
      final ahead = (to.dx * forward.dx + to.dy * forward.dy) / dist;
      if (dist < 520 && ahead > 0.55 && dist < bestDist) {
        best = d;
        bestDist = dist;
      }
    }
    if (best == null) return;

    final nose = ship + forward * 16;
    // Lead the target a little so slow drones are actually hit.
    final aim = best.pos + best.vel * (bestDist / 900);
    final dir = (aim - nose) / (aim - nose).distance;
    bolts.add(_Bolt(nose, dir * 900));
    muzzle = 0.08;
    _fireCooldown = 0.35 + _rand.nextDouble() * 0.3;
  }

  void _stepDrones(double dt) {
    final w = size.width;
    final h = size.height;
    for (final d in drones) {
      if (!d.alive) {
        d.respawnIn -= dt;
        if (d.respawnIn <= 0) {
          final fresh = _newDrone();
          d
            ..pos = fresh.pos
            ..vel = fresh.vel
            ..alive = true
            ..appear = 0;
        }
        continue;
      }
      d.appear = math.min(1, d.appear + dt * 0.8);
      d.pos += d.vel * dt;
      d.angle += d.spin * dt;
      // Wrap around the edges with a margin so they drift back in.
      if (d.pos.dx < -40) d.pos = Offset(w + 40, d.pos.dy);
      if (d.pos.dx > w + 40) d.pos = Offset(-40, d.pos.dy);
      if (d.pos.dy < -40) d.pos = Offset(d.pos.dx, h + 40);
      if (d.pos.dy > h + 40) d.pos = Offset(d.pos.dx, -40);
    }
  }

  void _stepBolts(double dt) {
    for (final b in bolts) {
      b.pos += b.vel * dt;
      b.life -= dt;
      for (final d in drones) {
        if (!d.alive || d.appear < 1) continue;
        if ((b.pos - d.pos).distance < d.radius + 3) {
          b.life = 0;
          _explode(d);
          break;
        }
      }
    }
    bolts.removeWhere((b) => b.life <= 0);
  }

  void _explode(_Drone d) {
    d.alive = false;
    d.respawnIn = 3 + _rand.nextDouble() * 3;
    rings.add(_Ring(d.pos));
    const colors = [
      AppColors.auroraCyan,
      AppColors.auroraViolet,
      AppColors.sunsetOrange,
    ];
    for (var i = 0; i < 16; i++) {
      final a = _rand.nextDouble() * 2 * math.pi;
      final speed = 50 + _rand.nextDouble() * 170;
      sparks.add(
        _Spark(
          d.pos,
          Offset(math.cos(a), math.sin(a)) * speed + d.vel,
          0.5 + _rand.nextDouble() * 0.5,
          colors[i % colors.length],
        ),
      );
    }
  }

  void _stepEffects(double dt) {
    for (final s in sparks) {
      s.pos += s.vel * dt;
      s.vel *= math.pow(0.08, dt).toDouble(); // drag
      s.life -= dt;
    }
    sparks.removeWhere((s) => s.life <= 0);
    for (final r in rings) {
      r.t += dt / 0.55;
    }
    rings.removeWhere((r) => r.t >= 1);
  }
}

class _SkirmishPainter extends CustomPainter {
  _SkirmishPainter(this.sim) : super(repaint: sim);

  final _Skirmish sim;

  static const _glowBlur = MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in sim.drones) {
      if (d.alive) _drone(canvas, d);
    }
    for (final r in sim.rings) {
      _ring(canvas, r);
    }
    for (final s in sim.sparks) {
      _spark(canvas, s);
    }
    for (final b in sim.bolts) {
      _bolt(canvas, b);
    }
    final ship = sim.shipPos;
    if (ship != null) _ship(canvas, ship, sim.shipHeading);
  }

  /// Hexagonal drone: an outlined hull with a pulsing core.
  void _drone(Canvas canvas, _Drone d) {
    final alpha = 0.35 * d.appear;
    canvas.save();
    canvas.translate(d.pos.dx, d.pos.dy);
    canvas.rotate(d.angle);
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final p = Offset(math.cos(a), math.sin(a)) * d.radius;
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    canvas.drawPath(
      hex,
      Paint()..color = AppColors.auroraViolet.withValues(alpha: alpha * 0.25),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppColors.auroraViolet.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      Offset.zero,
      d.radius * 0.28,
      Paint()
        ..color = AppColors.overtime.withValues(alpha: alpha * 1.4)
        ..maskFilter = _glowBlur,
    );
    canvas.restore();
  }

  /// Sleek dart-shaped fighter with a flickering engine trail.
  void _ship(Canvas canvas, Offset pos, double heading) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(heading);
    // Drawn at 1.4× so it still reads on a wall TV across the room.
    canvas.scale(1.4);

    // Engine trail.
    final flicker = 0.75 + 0.25 * math.sin(sim.time * 25);
    canvas.drawRect(
      Rect.fromLTWH(-70, -2.5, 62, 5),
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.auroraCyan.withValues(alpha: 0),
            AppColors.auroraCyan.withValues(alpha: 0.45 * flicker),
          ],
        ).createShader(const Rect.fromLTWH(-70, -2.5, 62, 5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      const Offset(-9, 0),
      5 * flicker,
      Paint()
        ..color = AppColors.auroraCyan.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final hull = Path()
      ..moveTo(18, 0)
      ..lineTo(-10, -10)
      ..lineTo(-5, 0)
      ..lineTo(-10, 10)
      ..close();
    canvas.drawPath(
      hull,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8F6FF), Color(0xFF7FA8D8)],
        ).createShader(const Rect.fromLTWH(-10, -10, 28, 20))
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawPath(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.auroraCyan.withValues(alpha: 0.8),
    );
    // Cockpit.
    canvas.drawCircle(
      const Offset(4, 0),
      2,
      Paint()..color = AppColors.auroraCyan,
    );

    if (sim.muzzle > 0) {
      canvas.drawCircle(
        const Offset(20, 0),
        6 * (sim.muzzle / 0.08),
        Paint()
          ..color = AppColors.auroraCyan.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.restore();
  }

  void _bolt(Canvas canvas, _Bolt b) {
    final dir = b.vel / b.vel.distance;
    final tail = b.pos - dir * 22;
    canvas.drawLine(
      tail,
      b.pos,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.auroraCyan.withValues(alpha: 0.35)
        ..maskFilter = _glowBlur,
    );
    canvas.drawLine(
      tail,
      b.pos,
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _spark(Canvas canvas, _Spark s) {
    final t = (s.life / s.maxLife).clamp(0.0, 1.0);
    canvas.drawCircle(
      s.pos,
      1.2 + 1.4 * t,
      Paint()..color = s.color.withValues(alpha: 0.8 * t),
    );
  }

  void _ring(Canvas canvas, _Ring r) {
    final ease = 1 - math.pow(1 - r.t, 3).toDouble();
    canvas.drawCircle(
      r.pos,
      6 + 46 * ease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - r.t) + 0.5
        ..color = AppColors.auroraCyan.withValues(alpha: 0.6 * (1 - r.t)),
    );
    // Brief core flash.
    if (r.t < 0.3) {
      canvas.drawCircle(
        r.pos,
        14 * (1 - r.t / 0.3),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - r.t / 0.3))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_SkirmishPainter oldDelegate) => oldDelegate.sim != sim;
}

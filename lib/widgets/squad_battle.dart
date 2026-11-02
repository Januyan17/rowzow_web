import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import 'glass_panel.dart';
import 'soldier_figure.dart';

part 'squad_battle_vehicles.dart';

/// Decorative "match in progress" strip: Team Blue behind sandbags on the
/// left, Team Orange behind crates on the right, popping up from cover to
/// trade tracer fire across the middle.
///
/// Most shots strike cover (sparks and dust) or sail overhead. Now and then
/// an exposed soldier is hit: a short blood spray, a fall, and after a few
/// seconds he fades out and respawns behind cover, scored on the VS badge
/// like a multiplayer match. Behind them a tank per side shells no-man's
/// land and a transport plane drops paratroopers (see
/// `squad_battle_vehicles.dart`). Never takes input, and holds still when
/// the platform asks for reduced motion.
class SquadBattle extends StatefulWidget {
  const SquadBattle({super.key, this.height = 110});

  final double height;

  @override
  State<SquadBattle> createState() => _SquadBattleState();
}

class _SquadBattleState extends State<SquadBattle>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _Battle();
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
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: panelShape(
              20,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A1024), Color(0xFF171A33), Color(0xFF22192C)],
            ),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: panelShape(20)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _sim.layout(constraints.biggest);
                      return CustomPaint(painter: _BattlePainter(_sim));
                    },
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: ValueListenableBuilder<(int, int)>(
                    valueListenable: _sim.score,
                    builder: (context, score, _) => _VsBadge(score: score),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.score});

  /// (Team Blue, Team Orange) eliminations.
  final (int, int) score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.ps5.withValues(alpha: 0.35),
            AppColors.sunsetOrange.withValues(alpha: 0.35),
          ],
        ),
        shape: panelShape(
          20,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${score.$1}', style: _scoreStyle(AppColors.ps5)),
          const SizedBox(width: 8),
          const Text(
            'VS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text('${score.$2}', style: _scoreStyle(AppColors.sunsetOrange)),
        ],
      ),
    );
  }
}

TextStyle _scoreStyle(Color color) => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: Color.lerp(color, Colors.white, 0.35),
  fontFeatures: const [FontFeature.tabularFigures()],
);

enum _Stance { cover, aim, fire, down }

class _Soldier {
  _Soldier({required this.x, required this.team, required this.crouchFirer});

  /// Feet position as a fraction of the strip width.
  final double x;

  /// 0 = Team Blue (faces right), 1 = Team Orange (faces left).
  final int team;

  /// Fires kneeling over the cover instead of standing up.
  final bool crouchFirer;

  _Stance stance = _Stance.cover;
  double timer = 0;
  double shotIn = 0;
  int burstLeft = 0;
  double recoil = 0;
  double flash = 0;
  double phase = 0;

  /// Seconds since he went down, and since he came back.
  double downFor = 0;
  double spawnFade = 1;

  /// Pose he was in when hit, held through the fall.
  bool fellCrouched = false;

  bool get alive => stance != _Stance.down;

  /// Head and shoulders above the cover, so the other side can hit him.
  bool get exposed =>
      stance == _Stance.fire || (stance == _Stance.aim && !crouchFirer);

  bool get crouched => stance == _Stance.down
      ? fellCrouched
      : stance == _Stance.cover || crouchFirer;
}

class _Tracer {
  _Tracer(
    this.pos,
    this.vel,
    this.team,
    this.hitX,
    this.hitsCover, {
    this.victim,
  });

  Offset pos;
  final Offset vel;
  final int team;

  /// Screen x where it reaches the far side's cover.
  final double hitX;
  final bool hitsCover;

  /// Set when this round is the one that drops an enemy.
  final _Soldier? victim;
  double life = 1.2;
}

/// A blood droplet in flight; becomes a [_Splat] when it lands.
class _Drop {
  _Drop(this.pos, this.vel, this.size);

  Offset pos;
  Offset vel;
  final double size;
}

/// A stain on the ground that dries up and fades.
class _Splat {
  _Splat(this.pos, this.width);

  final Offset pos;
  final double width;
  double life = 4.5;
}

class _Spark {
  _Spark(this.pos, this.vel, this.life, this.color, {this.dust = false});

  Offset pos;
  Offset vel;
  double life;
  final double maxLife = 0.6;
  final Color color;
  final bool dust;
}

class _Battle extends ChangeNotifier {
  final _rand = math.Random(23);

  Size size = Size.zero;
  bool _wide = true;
  List<_Soldier> soldiers = const [];
  final tracers = <_Tracer>[];
  final sparks = <_Spark>[];
  final drops = <_Drop>[];
  final splats = <_Splat>[];
  final mists = <_Spark>[];
  double time = 0;

  /// (Team Blue, Team Orange) eliminations. Separate from the per-frame
  /// repaint so the badge only rebuilds when someone is actually hit.
  final score = ValueNotifier<(int, int)>((0, 0));

  final vehicles = _Vehicles();

  static const blood = Color(0xFFB0102C);

  /// Seconds a fallen soldier stays down before fading, then before he
  /// respawns.
  static const _lieFor = 2.6;
  static const _fadeFor = 0.6;
  static const _respawnAfter = 4.2;

  static const teamColors = [AppColors.ps5, AppColors.sunsetOrange];

  /// Cover sits at these fractions of the width, nearer the centre than
  /// each squad.
  double coverX(int team) =>
      team == 0 ? (_wide ? 0.27 : 0.33) : (_wide ? 0.73 : 0.67);

  /// Standing figure height in pixels.
  double get figureScale => size.height * 0.62 / 100;
  double get groundY => size.height * 0.88;

  /// Cover height in figure units — low enough that a kneeling rifle
  /// clears it.
  static const coverHeight = 40.0;

  void layout(Size s) {
    if (s == size) return;
    size = s;
    final wide = s.width >= 600;
    if (wide == _wide && soldiers.isNotEmpty) return;
    _wide = wide;
    // Phones get two a side so the figures don't crowd each other.
    final blue = wide ? [0.07, 0.14, 0.21] : [0.08, 0.22];
    soldiers = [
      for (var i = 0; i < blue.length; i++)
        _Soldier(x: blue[i], team: 0, crouchFirer: i == 1),
      for (var i = 0; i < blue.length; i++)
        _Soldier(x: 1 - blue[i], team: 1, crouchFirer: i == 0),
    ];
    for (final s in soldiers) {
      s.timer = 0.4 + _rand.nextDouble() * 2.5;
      s.phase = _rand.nextDouble() * 6;
    }
    vehicles.reset();
  }

  void step(double dt) {
    if (size.isEmpty || soldiers.isEmpty) return;
    time += dt;
    for (final s in soldiers) {
      _stepSoldier(s, dt);
    }
    for (final t in tracers) {
      t.pos += t.vel * dt;
      t.life -= dt;
      final reached = t.team == 0 ? t.pos.dx >= t.hitX : t.pos.dx <= t.hitX;
      if (!reached) continue;
      final victim = t.victim;
      if (victim != null) {
        t.life = 0;
        // He may have ducked while the round was in flight — then it
        // strikes his cover instead.
        if (victim.alive && victim.exposed) {
          _kill(victim, t.pos, t.team);
        } else {
          _impact(t.pos, t.team);
        }
      } else if (t.hitsCover) {
        t.life = 0;
        _impact(Offset(t.hitX, t.pos.dy), t.team);
      }
    }
    tracers.removeWhere(
      (t) => t.life <= 0 || t.pos.dx < -40 || t.pos.dx > size.width + 40,
    );
    for (final p in sparks) {
      p.vel += Offset(0, p.dust ? -10 : 160) * dt;
      p.vel *= math.pow(p.dust ? 0.3 : 0.15, dt).toDouble();
      p.pos += p.vel * dt;
      p.life -= dt;
    }
    sparks.removeWhere((p) => p.life <= 0);
    _stepBlood(dt);
    vehicles.step(this, dt);
    notifyListeners();
  }

  void _stepSoldier(_Soldier s, double dt) {
    s.recoil = math.max(0, s.recoil - dt * 9);
    s.flash = math.max(0, s.flash - dt);
    s.spawnFade = math.min(1, s.spawnFade + dt / 0.5);
    s.timer -= dt;
    switch (s.stance) {
      case _Stance.down:
        s.downFor += dt;
        if (s.downFor >= _respawnAfter) {
          s.stance = _Stance.cover;
          s.timer = 1.0 + _rand.nextDouble() * 1.5;
          s.spawnFade = 0;
        }
      case _Stance.cover:
        if (s.timer <= 0) {
          s.stance = _Stance.aim;
          s.timer = 0.35;
        }
      case _Stance.aim:
        if (s.timer <= 0) {
          s.stance = _Stance.fire;
          s.timer = 1.0 + _rand.nextDouble() * 1.2;
          s.shotIn = 0;
          s.burstLeft = 0;
        }
      case _Stance.fire:
        s.shotIn -= dt;
        if (s.shotIn <= 0) {
          if (s.burstLeft == 0) s.burstLeft = 3 + _rand.nextInt(3);
          _fire(s);
          s.burstLeft--;
          s.shotIn = s.burstLeft > 0 ? 0.1 : 0.45 + _rand.nextDouble() * 0.3;
        }
        if (s.timer <= 0) {
          s.stance = _Stance.cover;
          s.timer = 1.2 + _rand.nextDouble() * 2.4;
        }
    }
  }

  /// Screen position of a soldier's muzzle.
  Offset muzzleOf(_Soldier s) {
    final m = SoldierFigure.muzzleFor(crouch: s.crouched);
    final dir = s.team == 0 ? 1.0 : -1.0;
    return Offset(
      s.x * size.width + dir * m.dx * figureScale,
      groundY + m.dy * figureScale,
    );
  }

  void _fire(_Soldier s) {
    s.recoil = 1;
    s.flash = 0.05;
    final from = muzzleOf(s);
    final dir = s.team == 0 ? 1.0 : -1.0;

    // Now and then a round finds an exposed enemy — but never while that
    // side already has someone down, so neither squad empties out.
    final enemies = soldiers.where((e) => e.team != s.team);
    final victims = enemies.where((e) => e.exposed).toList();
    if (victims.isNotEmpty &&
        enemies.every((e) => e.alive) &&
        _rand.nextDouble() < 0.08) {
      final v = victims[_rand.nextInt(victims.length)];
      final chest = Offset(
        v.x * size.width,
        groundY + (v.crouched ? -50 : -64) * figureScale,
      );
      final vel = (chest - from) / (chest - from).distance * 900;
      tracers.add(_Tracer(from, vel, s.team, chest.dx, false, victim: v));
      return;
    }

    final targetCover = coverX(1 - s.team) * size.width;
    final coverTop = groundY - coverHeight * figureScale;
    // Roughly two in three rounds smack into the far cover; the rest sail
    // over the defenders' heads and off the edge.
    final hits = _rand.nextDouble() < 0.66;
    final aimY = hits
        ? coverTop + (4 + _rand.nextDouble() * (coverHeight - 10)) * figureScale
        : coverTop - (40 + _rand.nextDouble() * 40) * figureScale;
    final to = Offset(
      hits ? targetCover : (dir > 0 ? size.width + 40 : -40),
      aimY,
    );
    final v = (to - from) / (to - from).distance * 900;
    // Stop at the face of the cover nearest the shooter: the crates'
    // left edge, or the sandbags' right edge.
    final face = s.team == 0
        ? targetCover - 0.9 * 30 * figureScale
        : targetCover + 1.75 * 22 * figureScale;
    tracers.add(_Tracer(from, v, s.team, face, hits));
  }

  void _kill(_Soldier v, Offset at, int shooterTeam) {
    v
      ..fellCrouched = v.crouched
      ..stance = _Stance.down
      ..downFor = 0
      ..flash = 0
      ..recoil = 0;
    final (blue, orange) = score.value;
    score.value = shooterTeam == 0 ? (blue + 1, orange) : (blue, orange + 1);

    // Spray carries on in the direction the round was travelling.
    final dir = shooterTeam == 0 ? 1.0 : -1.0;
    for (var i = 0; i < 14; i++) {
      final a = -0.9 + _rand.nextDouble() * 1.2;
      final speed = 50 + _rand.nextDouble() * 120;
      drops.add(
        _Drop(
          at,
          Offset(math.cos(a) * dir, math.sin(a)) * speed,
          0.8 + _rand.nextDouble() * 1.3,
        ),
      );
    }
    mists.add(_Spark(at, Offset(dir * 14, -4), 0.5, blood, dust: true));
  }

  void _stepBlood(double dt) {
    for (final d in drops) {
      d.vel += const Offset(0, 320) * dt;
      d.pos += d.vel * dt;
      if (d.pos.dy >= groundY) {
        splats.add(
          _Splat(
            Offset(d.pos.dx, groundY),
            (2 + d.size * 2.5) * figureScale * 1.6,
          ),
        );
      }
    }
    drops.removeWhere((d) => d.pos.dy >= groundY);
    for (final m in mists) {
      m.pos += m.vel * dt;
      m.life -= dt;
    }
    mists.removeWhere((m) => m.life <= 0);
    for (final sp in splats) {
      sp.life -= dt;
    }
    splats.removeWhere((sp) => sp.life <= 0);
  }

  @override
  void dispose() {
    score.dispose();
    super.dispose();
  }

  void _impact(Offset at, int shooterTeam) {
    final dir = shooterTeam == 0
        ? -1.0
        : 1.0; // sparks kick back towards the shooter
    for (var i = 0; i < 6; i++) {
      final a = (_rand.nextDouble() - 0.5) * 1.6;
      final speed = 40 + _rand.nextDouble() * 90;
      sparks.add(
        _Spark(
          at,
          Offset(math.cos(a) * dir, math.sin(a) - 0.4) * speed,
          0.25 + _rand.nextDouble() * 0.3,
          const Color(0xFFFFD58A),
        ),
      );
    }
    sparks.add(
      _Spark(at, Offset(dir * 8, -6), 0.6, const Color(0xFFB9A79A), dust: true),
    );
  }
}

class _BattlePainter extends CustomPainter {
  _BattlePainter(this.sim) : super(repaint: sim);

  final _Battle sim;

  static const _ink = Color(0xFF0B0A1C);

  @override
  void paint(Canvas canvas, Size size) {
    final g = sim.groundY;

    // Brief jolt when a shell lands.
    final shake = sim.vehicles.shake;
    if (shake > 0) {
      final k = shake * shake * 2.2;
      canvas.translate(
        math.sin(sim.time * 90) * k,
        math.cos(sim.time * 70) * k * 0.6,
      );
    }

    // Distant smoke haze over each side's position.
    for (var team = 0; team < 2; team++) {
      final c = Offset(
        size.width * (team == 0 ? 0.15 : 0.85),
        g - size.height * 0.2,
      );
      canvas.drawCircle(
        c,
        size.height * 1.1,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _Battle.teamColors[team].withValues(alpha: 0.16),
              _Battle.teamColors[team].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: size.height * 1.1)),
      );
    }

    // Ground.
    canvas.drawRect(
      Rect.fromLTRB(0, g, size.width, size.height),
      Paint()..color = const Color(0xFF0E0C1E),
    );
    canvas.drawLine(
      Offset(0, g),
      Offset(size.width, g),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.10),
    );

    sim.vehicles.paintSky(canvas, sim);
    sim.vehicles.paintGround(canvas, sim);

    for (final sp in sim.splats) {
      final a = (sp.life / 1.5).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: sp.pos,
          width: sp.width,
          height: sp.width * 0.3,
        ),
        Paint()..color = _Battle.blood.withValues(alpha: 0.7 * a),
      );
    }

    for (final t in sim.tracers) {
      _tracer(canvas, t);
    }

    for (final s in sim.soldiers) {
      _soldier(canvas, s);
    }

    _sandbags(canvas, sim.coverX(0) * size.width, g);
    _crates(canvas, sim.coverX(1) * size.width, g);

    for (final m in sim.mists) {
      final a = (m.life / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        m.pos,
        (6 + (1 - a) * 8) * sim.figureScale * 1.6,
        Paint()
          ..color = _Battle.blood.withValues(alpha: 0.35 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    final dropPaint = Paint()..color = _Battle.blood;
    for (final d in sim.drops) {
      canvas.drawCircle(d.pos, d.size * sim.figureScale * 1.6, dropPaint);
    }

    for (final p in sim.sparks) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        p.dust ? 4 + (1 - a) * 6 : 1.2,
        Paint()
          ..color = p.color.withValues(alpha: (p.dust ? 0.25 : 0.9) * a)
          ..maskFilter = p.dust
              ? const MaskFilter.blur(BlurStyle.normal, 3)
              : null,
      );
    }
  }

  void _soldier(Canvas canvas, _Soldier s) {
    final scale = sim.figureScale;
    final color = _Battle.teamColors[s.team];
    // Fades out after lying down a while, and back in on respawn.
    final down = !s.alive;
    final opacity = down
        ? (1 - (s.downFor - _Battle._lieFor) / _Battle._fadeFor).clamp(0.0, 1.0)
        : s.spawnFade;
    if (opacity <= 0) return;

    canvas.save();
    canvas.translate(s.x * sim.size.width, sim.groundY);
    canvas.scale(s.team == 0 ? scale : -scale, scale);
    final breathe = down ? 0.0 : math.sin(sim.time * 1.6 + s.phase) * 0.6;

    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    if (down) {
      // Topple backwards about the heels, settling onto the ground.
      final fall = Curves.easeIn.transform((s.downFor / 0.55).clamp(0.0, 1.0));
      canvas.translate(-6 * fall, -5 * fall);
      canvas.rotate(-math.pi / 2 * fall);
    }

    // Team-coloured rim, then the dark silhouette on top.
    canvas.save();
    canvas.translate(1.2, -0.6);
    SoldierFigure.paint(
      canvas,
      color.withValues(alpha: 0.75),
      breathe: breathe,
      recoil: s.recoil,
      crouch: s.crouched,
    );
    canvas.restore();
    SoldierFigure.paint(
      canvas,
      _ink,
      breathe: breathe,
      recoil: s.recoil,
      crouch: s.crouched,
    );
    SoldierFigure.paintFlash(
      canvas,
      SoldierFigure.muzzleFor(crouch: s.crouched) + Offset(-1.6 * s.recoil, 0),
      s.flash / 0.05,
      0.9,
      color,
    );
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  void _tracer(Canvas canvas, _Tracer t) {
    final dir = t.vel / t.vel.distance;
    final tail = t.pos - dir * 22;
    final color = _Battle.teamColors[t.team];
    canvas.drawLine(
      tail,
      t.pos,
      Paint()
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawLine(
      tail,
      t.pos,
      Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(color, Colors.white, 0.7)!,
    );
  }

  /// Team Blue's low wall of stacked sandbags.
  void _sandbags(Canvas canvas, double cx, double g) {
    final s = sim.figureScale;
    final bagW = 22 * s;
    final bagH = 10 * s;
    final fill = Paint()..color = const Color(0xFF1A1830);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.ps5.withValues(alpha: 0.35);
    final rows = (_Battle.coverHeight / 10).floor();
    for (var r = 0; r < rows; r++) {
      final count = 4 - (r >= rows - 1 ? 1 : 0);
      final y = g - (r + 1) * bagH;
      final startX =
          cx - count * bagW / 2 + (r.isOdd ? bagW / 2 : 0) - bagW / 4;
      for (var i = 0; i < count; i++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX + i * bagW, y, bagW - 1, bagH - 0.5),
          Radius.circular(bagH / 2),
        );
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, edge);
      }
    }
  }

  /// Team Orange's stacked supply crates.
  void _crates(Canvas canvas, double cx, double g) {
    final s = sim.figureScale;
    final big = 30 * s;
    final small = 18 * s;
    final fill = Paint()..color = const Color(0xFF1C1726);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.sunsetOrange.withValues(alpha: 0.4);
    void crate(Rect r) {
      canvas.drawRect(r, fill);
      canvas.drawRect(r, edge);
      canvas.drawLine(r.topLeft, r.bottomRight, edge);
      canvas.drawLine(r.topRight, r.bottomLeft, edge);
    }

    crate(Rect.fromLTWH(cx - big * 0.9, g - big, big, big));
    crate(
      Rect.fromLTWH(cx + big * 0.1, g - big * 0.85, big * 0.85, big * 0.85),
    );
    crate(Rect.fromLTWH(cx - big * 0.35, g - big - small, small, small));
  }

  @override
  bool shouldRepaint(_BattlePainter oldDelegate) => oldDelegate.sim != sim;
}

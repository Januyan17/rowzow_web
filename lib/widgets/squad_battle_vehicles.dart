part of 'squad_battle.dart';

/// Background set-pieces for [SquadBattle]: a tank per side lobbing shells
/// into no-man's land, and a transport plane that crosses now and then to
/// drop paratroopers behind its own lines.
///
/// On every pass the other side's launcher fires a homing missile once
/// the plane crosses the centre line: a sky blast, the airframe breaking in
/// two and tumbling down on fire, and the pilot ejecting under a chute.
///
/// Everything here is drawn smaller than the riflemen and sits behind them,
/// so it reads as depth rather than competing with the firefight. Shells
/// only ever land in open ground between the lines.
class _Vehicles {
  final _rand = math.Random(31);

  final tanks = [_Tank(0), _Tank(1)];
  final shells = <_Shell>[];
  final blasts = <_Blast>[];
  final debris = <_Spark>[];
  final smoke = <_Smoke>[];
  final scorches = <_Splat>[];
  final paras = <_Para>[];
  final missiles = <_Missile>[];
  final wrecks = <_Wreck>[];

  /// Seconds left on each side's launch flash.
  final launchFlash = [0.0, 0.0];

  _Plane? plane;

  /// Seconds until the next fly-over, and which side it serves.
  double _planeIn = 3;
  int _planeTeam = 0;

  /// Strip shake from the last explosion, 1 → 0.
  double shake = 0;

  /// Tank size relative to a rifleman; phones get a smaller one so it
  /// fits between the cover and the centre line.
  double tankScale(_Battle b) => b._wide ? 0.6 : 0.45;

  void reset() {
    tanks[0].fireIn = 2.5;
    tanks[1].fireIn = 5.5;
  }

  /// Tanks hold the open ground just forward of their own cover, a little
  /// up the "far" ground so they read as behind the riflemen.
  Offset tankPos(_Battle b, int team) => Offset(
    b.size.width *
        (team == 0 ? (b._wide ? 0.36 : 0.42) : (b._wide ? 0.64 : 0.58)),
    farGroundY(b),
  );

  /// Ground line for the background layer.
  double farGroundY(_Battle b) => b.groundY - b.size.height * 0.05;

  double get _paraFall => 4.5;

  void step(_Battle b, double dt) {
    shake = math.max(0, shake - dt * 3.5);
    _stepTanks(b, dt);
    _stepShells(b, dt);
    _stepEffects(dt);
    _stepPlane(b, dt);
    _stepMissiles(b, dt);
    _stepWrecks(b, dt);
    _stepParas(b, dt);
  }

  void _stepTanks(_Battle b, double dt) {
    for (final t in tanks) {
      t.recoil = math.max(0, t.recoil - dt * 2.5);
      t.blast = math.max(0, t.blast - dt);
      t.fireIn -= dt;
      if (t.fireIn > 0) continue;
      t.fireIn = 6 + _rand.nextDouble() * 4;
      t.recoil = 1;
      t.blast = 0.12;

      final dir = t.team == 0 ? 1.0 : -1.0;
      final s = b.figureScale * tankScale(b);
      final muzzle = tankPos(b, t.team) + Offset(dir * 66 * s, -31 * s);
      // Into open ground between the covers, never onto a position.
      final spread = b._wide ? 0.10 : 0.04;
      final landX =
          b.size.width * (0.5 - spread / 2 + _rand.nextDouble() * spread);
      shells.add(_Shell(muzzle, Offset(landX, b.groundY), t.team));
      smoke.add(_Smoke(muzzle + Offset(dir * 4, 0), 0.9, size: 0.6));
    }
  }

  void _stepShells(_Battle b, double dt) {
    for (final s in shells) {
      s.t += dt / 0.8;
      if (s.t >= 1) _explode(b, s.to);
    }
    shells.removeWhere((s) => s.t >= 1);
  }

  void _explode(_Battle b, Offset at) {
    shake = 1;
    blasts.add(_Blast(at));
    scorches.add(_Splat(at, b.size.height * 0.45)..life = 5);
    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + (_rand.nextDouble() - 0.5) * 2.2;
      final speed = 60 + _rand.nextDouble() * 160;
      debris.add(
        _Spark(
          at,
          Offset(math.cos(a), math.sin(a)) * speed,
          0.5 + _rand.nextDouble() * 0.5,
          i.isEven ? const Color(0xFF3A2A22) : const Color(0xFFFFB25A),
        ),
      );
    }
    for (var i = 0; i < 3; i++) {
      smoke.add(
        _Smoke(
          at + Offset((_rand.nextDouble() - 0.5) * 16, -4.0 - i * 5),
          1.6 + i * 0.3,
        ),
      );
    }
  }

  void _stepEffects(double dt) {
    for (final bl in blasts) {
      bl.t += dt / 0.45;
    }
    blasts.removeWhere((bl) => bl.t >= 1);
    for (final d in debris) {
      d.vel += const Offset(0, 300) * dt;
      d.pos += d.vel * dt;
      d.life -= dt;
    }
    debris.removeWhere((d) => d.life <= 0);
    for (final sm in smoke) {
      sm.t += dt / sm.duration;
      sm.pos += const Offset(4, -14) * dt;
    }
    launchFlash[0] = math.max(0, launchFlash[0] - dt);
    launchFlash[1] = math.max(0, launchFlash[1] - dt);
    smoke.removeWhere((sm) => sm.t >= 1);
    for (final sc in scorches) {
      sc.life -= dt;
    }
    scorches.removeWhere((sc) => sc.life <= 0);
  }

  void _stepPlane(_Battle b, double dt) {
    final p = plane;
    if (p == null) {
      _planeIn -= dt;
      if (_planeIn <= 0) {
        plane = _Plane(_planeTeam, _paraDropsFor(b, _planeTeam));
        _planeTeam = 1 - _planeTeam;
      }
      return;
    }
    p.t += dt / 8;
    final x = planeX(b, p);
    // Drop each jumper as the plane passes over his mark.
    while (p.drops.isNotEmpty &&
        (p.team == 0 ? x >= p.drops.first : x <= p.drops.first)) {
      p.drops.removeAt(0);
      paras.add(
        _Para(
          Offset(x, planeY(b)),
          p.team,
          (_rand.nextDouble() - 0.5) * 6,
          _rand.nextDouble() * 6,
        ),
      );
    }
    // Once it's over enemy ground (its jumpers already out), the other
    // side's launcher has a go.
    final overEnemy = p.team == 0
        ? x >= b.size.width * 0.5
        : x <= b.size.width * 0.5;
    if (!p.launched && overEnemy) {
      p.launched = true;
      final side = 1 - p.team;
      final from = launcherPos(b, side) + Offset(0, -8 * _unit(b));
      launchFlash[side] = 0.15;
      // Leave the rail pitched up towards the plane rather than straight
      // up, so even on a very wide screen it arcs onto it instead of
      // overshooting its altitude.
      final toPlane = (Offset(x, planeY(b)) - from).direction;
      final up = -math.pi / 2;
      missiles.add(_Missile(from, toPlane + (up - toPlane) * 0.35));
      smoke.add(_Smoke(from, 1.1, size: 0.7));
    }
    // Safety net: never let a targeted plane slip off-screen unhit.
    final leaving = p.team == 0
        ? x >= b.size.width * 0.94
        : x <= b.size.width * 0.06;
    if (p.launched && leaving) {
      missiles.clear();
      _shootDown(b, p);
      return;
    }
    if (p.t >= 1) {
      plane = null;
      _planeIn = 9 + _rand.nextDouble() * 6;
    }
  }

  double _unit(_Battle b) => b.size.height / 110;

  /// Each side's anti-air launcher, tucked at the far edge of its ground.
  Offset launcherPos(_Battle b, int team) =>
      Offset(b.size.width * (team == 0 ? 0.025 : 0.975), farGroundY(b));

  void _stepMissiles(_Battle b, double dt) {
    final p = plane;
    for (final m in missiles) {
      m.age += dt;
      // Always well over twice the plane's speed, however wide the strip.
      final top = math.max(520 * _unit(b), (b.size.width + 140) / 8 * 2.2);
      m.speed = math.min(top, m.speed + top * 1.4 * dt);
      if (p != null) {
        // Steer towards where the plane will be, at a limited turn rate.
        // Aim ahead by however far the plane will fly before the missile
        // arrives — shrinking to nothing as it closes, so it converges on
        // the airframe instead of circling a point in front of it.
        final target = Offset(planeX(b, p), planeY(b));
        final dir = p.team == 0 ? 1.0 : -1.0;
        // Head-on (missile ahead of the plane): aim straight at it, the
        // closing speed does the rest. Chasing from behind: lead by the
        // flight time at full speed.
        final headOn = (m.pos.dx - target.dx) * dir > 0;
        final eta = (target - m.pos).distance / top;
        final planeSpeed = (b.size.width + 140) / 8;
        final lead = headOn || m.age > 1.4
            ? target
            : target + Offset(dir * planeSpeed * eta, 0);
        final want = (lead - m.pos).direction;
        var diff = want - m.heading;
        while (diff > math.pi) {
          diff -= 2 * math.pi;
        }
        while (diff < -math.pi) {
          diff += 2 * math.pi;
        }
        // Lazy arc off the rail, then ever tighter tracking, then a hard
        // lock — it is several times faster than the plane, so it can't
        // miss.
        if (m.age > 1.4) {
          m.heading = want;
        } else {
          final turn = m.age < 0.5 ? 3.2 : 9.0;
          m.heading += diff.clamp(-turn * dt, turn * dt);
        }
      }
      m.pos += Offset(math.cos(m.heading), math.sin(m.heading)) * m.speed * dt;
      m.puffIn -= dt;
      if (m.puffIn <= 0) {
        m.puffIn = 0.025;
        smoke.add(_Smoke(m.pos, 1.1, size: 0.34));
      }
      if (p != null &&
          (m.pos - Offset(planeX(b, p), planeY(b))).distance < 10 * _unit(b)) {
        m.age = 99;
        _shootDown(b, p);
      }
    }
    missiles.removeWhere(
      (m) =>
          m.age > 5 ||
          m.pos.dy < -40 ||
          m.pos.dx < -40 ||
          m.pos.dx > b.size.width + 40,
    );
  }

  void _shootDown(_Battle b, _Plane p) {
    final at = Offset(planeX(b, p), planeY(b));
    final dir = p.team == 0 ? 1.0 : -1.0;
    final u = _unit(b);
    shake = 0.7;
    blasts.add(_Blast(at, size: 1.3));
    for (var i = 0; i < 20; i++) {
      final a = _rand.nextDouble() * 2 * math.pi;
      final speed = 40 + _rand.nextDouble() * 140;
      debris.add(
        _Spark(
          at,
          Offset(math.cos(a), math.sin(a)) * speed * u +
              Offset(dir * 40 * u, 0),
          0.6 + _rand.nextDouble() * 0.6,
          i % 3 == 0 ? const Color(0xFF2A2433) : const Color(0xFFFFB25A),
        ),
      );
    }
    // The airframe snaps in two; each half keeps some of its momentum.
    wrecks
      ..add(_Wreck(at, Offset(dir * 70 * u, -10 * u), 2.4, p.team, front: true))
      ..add(
        _Wreck(at, Offset(dir * 25 * u, -25 * u), -3.0, p.team, front: false),
      );
    // Pilot punches out.
    paras.add(_Para(at - Offset(0, 4 * u), p.team, -dir * 4, 1.3));
    final (blue, orange) = b.score.value;
    b.score.value = p.team == 0 ? (blue, orange + 1) : (blue + 1, orange);
    plane = null;
    _planeIn = 9 + _rand.nextDouble() * 6;
  }

  void _stepWrecks(_Battle b, double dt) {
    for (final w in wrecks) {
      w.vel += Offset(0, 130 * _unit(b)) * dt;
      w.pos += w.vel * dt;
      w.angle += w.spin * dt;
      w.puffIn -= dt;
      if (w.puffIn <= 0) {
        w.puffIn = 0.04;
        smoke.add(_Smoke(w.pos, 1.3, size: 0.35, dark: true));
      }
      if (w.pos.dy >= farGroundY(b)) {
        w.done = true;
        shake = math.max(shake, 0.5);
        blasts.add(_Blast(Offset(w.pos.dx, farGroundY(b)), size: 0.7));
        scorches.add(
          _Splat(Offset(w.pos.dx, farGroundY(b)), b.size.height * 0.4)
            ..life = 5,
        );
      }
    }
    wrecks.removeWhere(
      (w) => w.done || w.pos.dx < -60 || w.pos.dx > b.size.width + 60,
    );
  }

  /// Plane serving Team Blue flies left→right and drops over the left;
  /// Team Orange's mirrors it.
  List<double> _paraDropsFor(_Battle b, int team) {
    final n = b.size.width >= 600 ? 3 : 2;
    final marks = [for (var i = 0; i < n; i++) 0.06 + i * 0.07];
    final xs = [for (final m in marks) (team == 0 ? m : 1 - m) * b.size.width];
    return xs;
  }

  double planeY(_Battle b) => b.size.height * 0.22;

  double planeX(_Battle b, _Plane p) {
    final x = -70 + p.t * (b.size.width + 140);
    return p.team == 0 ? x : b.size.width - x;
  }

  void _stepParas(_Battle b, double dt) {
    final fallSpeed = (farGroundY(b) - planeY(b)) / _paraFall;
    for (final p in paras) {
      p.age += dt;
      if (p.landed) {
        p.landedFor += dt;
        continue;
      }
      // A beat of free-fall before the canopy snaps open.
      final speed = p.age < 0.35 ? fallSpeed * 2.4 : fallSpeed;
      p.pos += Offset(p.drift, speed) * dt;
      if (p.pos.dy >= farGroundY(b)) {
        p.pos = Offset(p.pos.dx, farGroundY(b));
        p.landed = true;
      }
    }
    paras.removeWhere((p) => p.landedFor > 1.6);
  }

  // ---------------------------------------------------------------------
  // Painting.

  /// Plane, contrail and paratroopers — the farthest layer.
  void paintSky(Canvas canvas, _Battle b) {
    final p = plane;
    if (p != null) _paintPlane(canvas, b, p);
    for (final w in wrecks) {
      _paintWreck(canvas, b, w);
    }
    for (final m in missiles) {
      _paintMissile(canvas, b, m);
    }
    for (final para in paras) {
      _paintPara(canvas, b, para);
    }
  }

  /// Scorches, tanks, shells and explosions — behind the riflemen.
  void paintGround(Canvas canvas, _Battle b) {
    for (final sc in scorches) {
      final a = (sc.life / 2).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: sc.pos,
          width: sc.width,
          height: sc.width * 0.14,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45 * a),
      );
    }
    for (final t in tanks) {
      _paintTank(canvas, b, t);
    }
    _paintLauncher(canvas, b, 0);
    _paintLauncher(canvas, b, 1);
    for (final s in shells) {
      _paintShell(canvas, s);
    }
    for (final sm in smoke) {
      final grow = Curves.easeOut.transform(sm.t);
      canvas.drawCircle(
        sm.pos,
        b.size.height * (0.05 + 0.12 * grow) * sm.size,
        Paint()
          ..color =
              (sm.dark ? const Color(0xFF241F2C) : const Color(0xFF8C8A9A))
                  .withValues(alpha: (sm.dark ? 0.55 : 0.28) * (1 - sm.t))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    for (final bl in blasts) {
      _paintBlast(canvas, b, bl);
    }
    for (final d in debris) {
      final a = (d.life / 0.6).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromCenter(center: d.pos, width: 2.2, height: 2.2),
        Paint()..color = d.color.withValues(alpha: a),
      );
    }
  }

  void _paintTank(Canvas canvas, _Battle b, _Tank t) {
    final pos = tankPos(b, t.team);
    final s = b.figureScale * tankScale(b);
    final team = _Battle.teamColors[t.team];
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(t.team == 0 ? s : -s, s);

    canvas.save();
    canvas.translate(1.6, -0.8);
    _tankBody(canvas, team.withValues(alpha: 0.7), t);
    canvas.restore();
    _tankBody(canvas, const Color(0xFF0B0A1C), t);

    // Muzzle blast at the end of the barrel.
    if (t.blast > 0) {
      final k = t.blast / 0.12;
      final m = Offset(66 - 8 * Curves.easeOut.transform(t.recoil), -31);
      canvas.drawCircle(
        m + const Offset(8, 0),
        16 * k,
        Paint()
          ..color = const Color(0xFFFFC266).withValues(alpha: 0.8 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        m + const Offset(6, 0),
        6 * k,
        Paint()..color = const Color(0xFFFFF1C9).withValues(alpha: k),
      );
    }
    canvas.restore();
  }

  /// Tank in tank units: 100 long, facing +x, tracks on the ground at y=0.
  void _tankBody(Canvas canvas, Color color, _Tank t) {
    final fill = Paint()..color = color;
    // Tracks and road wheels.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-46, -14, 46, 0),
        const Radius.circular(7),
      ),
      fill,
    );
    // Hull.
    canvas.drawPath(
      Path()
        ..moveTo(-44, -13)
        ..lineTo(46, -13)
        ..lineTo(38, -24)
        ..lineTo(-40, -24)
        ..close(),
      fill,
    );
    // Turret and barrel recoil back together.
    final kick = Curves.easeOut.transform(t.recoil) * 8;
    canvas.save();
    canvas.translate(-kick * 0.35, 0);
    canvas.drawPath(
      Path()
        ..moveTo(-20, -24)
        ..lineTo(-16, -36)
        ..quadraticBezierTo(0, -40, 14, -35)
        ..lineTo(20, -24)
        ..close(),
      fill,
    );
    // Commander's hatch and antenna.
    canvas.drawRect(const Rect.fromLTWH(-10, -40, 9, 4), fill);
    canvas.drawLine(
      const Offset(-14, -36),
      const Offset(-20, -56),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
    canvas.translate(-kick * 0.65, 0);
    canvas.drawRect(const Rect.fromLTRB(14, -33, 64, -29), fill);
    canvas.drawRect(
      const Rect.fromLTRB(60, -34.5, 67, -27.5),
      fill,
    ); // muzzle brake
    canvas.restore();
  }

  void _paintShell(Canvas canvas, _Shell s) {
    Offset at(double t) {
      final p = Offset.lerp(s.from, s.to, t)!;
      // Lob: rise and fall over the flight.
      return p -
          Offset(0, math.sin(t * math.pi) * (s.from - s.to).distance * 0.18);
    }

    final head = at(s.t);
    final tail = at(math.max(0, s.t - 0.06));
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFB25A).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(head, 1.8, Paint()..color = const Color(0xFFFFF1C9));
  }

  void _paintBlast(Canvas canvas, _Battle b, _Blast bl) {
    final r = b.size.height * 0.30 * bl.size;
    final t = bl.t;
    // White core flash, then a rising orange fireball.
    if (t < 0.25) {
      canvas.drawCircle(
        bl.pos,
        r * 0.5 * (1 - t / 0.25) + 3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * (1 - t / 0.25))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final c = bl.pos - Offset(0, r * 0.35 * t);
    final radius = r * (0.25 + 0.55 * Curves.easeOut.transform(t));
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE6A3).withValues(alpha: 0.9 * (1 - t)),
            const Color(0xFFFF7A2E).withValues(alpha: 0.7 * (1 - t)),
            const Color(0xFFB0102C).withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  void _paintPlane(Canvas canvas, _Battle b, _Plane p) {
    final x = planeX(b, p);
    final y = planeY(b) + math.sin(p.t * 6) * 1.2;
    final dir = p.team == 0 ? 1.0 : -1.0;
    final s = b.size.height / 110 * 0.5;

    // Contrail fading out behind.
    final trail = Rect.fromLTRB(
      dir > 0 ? x - 160 : x,
      y - 1,
      dir > 0 ? x : x + 160,
      y + 1,
    );
    canvas.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: dir > 0 ? Alignment.centerLeft : Alignment.centerRight,
          end: dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.18),
          ],
        ).createShader(trail),
    );

    canvas.save();
    canvas.translate(x, y);
    canvas.scale(dir * s, s);
    _planeShape(canvas, p.team);
    // Blinking nav light.
    if ((p.t * 16).floor().isEven) {
      canvas.drawCircle(
        const Offset(-47, -14),
        2,
        Paint()
          ..color = const Color(0xFFFF4D67)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.restore();
  }

  /// Transport airframe in plane units: ~90 long, facing +x.
  void _planeShape(Canvas canvas, int team) {
    final ink = Paint()..color = const Color(0xFF1A1C33);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.25);
    // Fuselage with a tapered tail and raised fin.
    final body = Path()
      ..moveTo(40, -2)
      ..quadraticBezierTo(44, 2, 38, 5)
      ..lineTo(-30, 5)
      ..lineTo(-44, -2)
      ..lineTo(-48, -14)
      ..lineTo(-40, -14)
      ..lineTo(-30, -4)
      ..lineTo(30, -6)
      ..close();
    canvas.drawPath(body, ink);
    canvas.drawPath(body, rim);
    // Wing and engine pod.
    canvas.drawPath(
      Path()
        ..moveTo(10, -2)
        ..lineTo(-6, 10)
        ..lineTo(-14, 10)
        ..lineTo(-4, -2)
        ..close(),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2, 2, 12, 5),
        const Radius.circular(2.5),
      ),
      ink,
    );
    // Team roundel.
    canvas.drawCircle(
      const Offset(-20, 0),
      2.6,
      Paint()..color = _Battle.teamColors[team],
    );
  }

  /// One half of a downed plane, tumbling, with flames at the break.
  void _paintWreck(Canvas canvas, _Battle b, _Wreck w) {
    final s = b.size.height / 110 * 0.5;
    final dir = w.team == 0 ? 1.0 : -1.0;
    canvas.save();
    canvas.translate(w.pos.dx, w.pos.dy);
    canvas.rotate(w.angle);
    canvas.scale(dir * s, s);
    canvas.save();
    canvas.clipRect(
      w.front
          ? const Rect.fromLTRB(-4, -30, 60, 30)
          : const Rect.fromLTRB(-60, -30, -4, 30),
    );
    // Shift each half so it rotates about its own middle.
    canvas.translate(w.front ? -18 : 24, 0);
    _planeShape(canvas, w.team);
    canvas.restore();
    // Fire licking from the torn end.
    final flicker = 0.7 + 0.3 * math.sin(b.time * 40 + (w.front ? 0 : 2));
    canvas.drawCircle(
      Offset(w.front ? -20 : 20, 0),
      7 * flicker,
      Paint()
        ..color = const Color(0xFFFF8A3D).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  void _paintMissile(Canvas canvas, _Battle b, _Missile m) {
    final u = _unit(b);
    canvas.save();
    canvas.translate(m.pos.dx, m.pos.dy);
    canvas.rotate(m.heading);
    // Exhaust flare.
    canvas.drawCircle(
      Offset(-7 * u, 0),
      4 * u,
      Paint()
        ..color = const Color(0xFFFFC266).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Body with nose cone and fins.
    canvas.drawPath(
      Path()
        ..moveTo(7 * u, 0)
        ..lineTo(3 * u, -1.3 * u)
        ..lineTo(-6 * u, -1.3 * u)
        ..lineTo(-8 * u, -3 * u)
        ..lineTo(-8 * u, 3 * u)
        ..lineTo(-6 * u, 1.3 * u)
        ..lineTo(3 * u, 1.3 * u)
        ..close(),
      Paint()..color = const Color(0xFFDCE3EE),
    );
    canvas.restore();
  }

  /// Anti-air launcher: a squat base with a tilted twin-tube rack aimed at
  /// the sky over the enemy side.
  void _paintLauncher(Canvas canvas, _Battle b, int team) {
    final pos = launcherPos(b, team);
    final u = _unit(b);
    final color = _Battle.teamColors[team];
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(team == 0 ? u : -u, u);
    void shape(Paint paint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-8, -5, 8, 0),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.save();
      canvas.translate(0, -5);
      canvas.rotate(-0.95);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-2, -4.5, 16, -0.5),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-2, 0.5, 16, 4.5),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }

    canvas.save();
    canvas.translate(0.8, -0.5);
    shape(Paint()..color = color.withValues(alpha: 0.7));
    canvas.restore();
    shape(Paint()..color = const Color(0xFF0B0A1C));

    final f = launchFlash[team];
    if (f > 0) {
      canvas.drawCircle(
        const Offset(0, -6),
        9 * (f / 0.15),
        Paint()
          ..color = const Color(0xFFFFC266).withValues(alpha: 0.8 * f / 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.restore();
  }

  void _paintPara(Canvas canvas, _Battle b, _Para p) {
    final h = b.size.height;
    final unit = h / 110;
    final team = _Battle.teamColors[p.team];
    final fade = p.landed
        ? (1 - (p.landedFor - 0.6) / 1.0).clamp(0.0, 1.0)
        : 1.0;
    if (fade <= 0) return;
    final open = ((p.age - 0.35) / 0.3).clamp(0.0, 1.0);
    final sway = p.landed ? 0.0 : math.sin(p.age * 2.2 + p.phase) * 0.18 * open;

    canvas.save();
    canvas.translate(p.pos.dx, p.pos.dy);
    canvas.rotate(sway);

    final ink = Paint()
      ..color = const Color(0xFF0B0A1C).withValues(alpha: fade);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * fade)
      ..strokeWidth = 0.7;

    // Jumper, feet at the origin.
    final body = 15 * unit;
    canvas.drawCircle(Offset(0, -body + 2 * unit), 2 * unit, ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2.2 * unit, -body + 4 * unit, 4.4 * unit, 6.5 * unit),
        Radius.circular(1.5 * unit),
      ),
      ink,
    );
    final limb = Paint()
      ..color = ink.color
      ..strokeWidth = 1.8 * unit
      ..strokeCap = StrokeCap.round;
    // Legs dangle in the air, bend on landing.
    final knee = p.landed ? 2.5 * unit : 0.5 * unit;
    canvas.drawLine(
      Offset(-1 * unit, -body + 10 * unit),
      Offset(-knee, 0),
      limb,
    );
    canvas.drawLine(Offset(1 * unit, -body + 10 * unit), Offset(knee, 0), limb);
    // Arms up on the risers.
    canvas.drawLine(
      Offset(-1.5 * unit, -body + 5 * unit),
      Offset(-3.5 * unit, -body - 1 * unit),
      limb,
    );
    canvas.drawLine(
      Offset(1.5 * unit, -body + 5 * unit),
      Offset(3.5 * unit, -body - 1 * unit),
      limb,
    );

    // Canopy: pops open after free-fall, collapses on landing.
    final collapse = p.landed ? (p.landedFor / 0.6).clamp(0.0, 1.0) : 0.0;
    final size = open * (1 - collapse * 0.7);
    if (size > 0) {
      final w = 26 * unit * size;
      final top = -body - 16 * unit * size - (collapse * -12 * unit);
      final canopy = Rect.fromLTWH(-w / 2, top, w, 10 * unit * size);
      canvas.drawLine(
        Offset(-3.5 * unit, -body - 1 * unit),
        Offset(-w / 2, top + 5 * unit * size),
        line,
      );
      canvas.drawLine(
        Offset(3.5 * unit, -body - 1 * unit),
        Offset(w / 2, top + 5 * unit * size),
        line,
      );
      canvas.drawLine(Offset(0, -body), Offset(0, top + 5 * unit * size), line);
      final dome = Path()
        ..moveTo(canopy.left, canopy.bottom)
        ..quadraticBezierTo(
          canopy.left,
          canopy.top,
          canopy.center.dx,
          canopy.top,
        )
        ..quadraticBezierTo(
          canopy.right,
          canopy.top,
          canopy.right,
          canopy.bottom,
        )
        ..quadraticBezierTo(
          canopy.center.dx,
          canopy.bottom - 3 * unit * size,
          canopy.left,
          canopy.bottom,
        )
        ..close();
      canvas.drawPath(
        dome,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                team,
                Colors.white,
                0.25,
              )!.withValues(alpha: 0.85 * fade),
              team.withValues(alpha: 0.55 * fade),
            ],
          ).createShader(canopy),
      );
      // Panel seams.
      final seam = Paint()
        ..color = const Color(0xFF0B0A1C).withValues(alpha: 0.35 * fade)
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(-w / 6, canopy.top + 1.5 * unit * size),
        Offset(-w / 4, canopy.bottom - 1),
        seam,
      );
      canvas.drawLine(
        Offset(w / 6, canopy.top + 1.5 * unit * size),
        Offset(w / 4, canopy.bottom - 1),
        seam,
      );
    }
    canvas.restore();
  }
}

class _Tank {
  _Tank(this.team);

  final int team;
  double fireIn = 4;
  double recoil = 0;
  double blast = 0;
}

class _Shell {
  _Shell(this.from, this.to, this.team);

  final Offset from;
  final Offset to;
  final int team;
  double t = 0;
}

class _Blast {
  _Blast(this.pos, {this.size = 1});

  final Offset pos;
  final double size;
  double t = 0;
}

class _Missile {
  _Missile(this.pos, this.heading);

  Offset pos;
  double heading;
  double speed = 120;
  double age = 0;
  double puffIn = 0;
}

class _Wreck {
  _Wreck(this.pos, this.vel, this.spin, this.team, {required this.front});

  Offset pos;
  Offset vel;
  final double spin;
  final int team;

  /// Nose half or tail half.
  final bool front;
  double angle = 0;
  double puffIn = 0;
  bool done = false;
}

class _Smoke {
  _Smoke(this.pos, this.duration, {this.size = 1, this.dark = false});

  Offset pos;
  final double duration;
  final double size;

  /// Black smoke from burning wreckage rather than grey dust.
  final bool dark;
  double t = 0;
}

class _Plane {
  _Plane(this.team, this.drops);

  final int team;

  /// Set once the other side's missile is in the air.
  bool launched = false;

  /// Screen x positions still to drop a jumper at, in flight order.
  final List<double> drops;
  double t = 0;
}

class _Para {
  _Para(this.pos, this.team, this.drift, this.phase);

  Offset pos;
  final int team;
  final double drift;
  final double phase;
  double age = 0;
  bool landed = false;
  double landedFor = 0;
}

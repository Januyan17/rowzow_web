import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';

/// Fighting-game vignette: Blaze (fire, earth, fire-tiger form) against Gale
/// (wind, serpent form), trading punches and kicks, elemental
/// specials and shape-shifts, until a finisher ends the round.
///
/// Finishers rotate: a super-move K.O., a cyclone FATALITY (the
/// loser breaks apart into ash and light), and an ANIMALITY for each side
/// (tiger pounce, serpent coil). No blood or gore, and both fighters are
/// back whole for the next round. Purely decorative: never takes input,
/// and holds still when the platform asks for reduced motion.
class ElementalFight extends StatefulWidget {
  const ElementalFight({
    super.key,
    this.height,
    this.arena = true,
    this.groundFrac = 0.9,
    this.figureFrac = 0.64,
  });

  /// Fixed height, or null to fill the parent.
  final double? height;

  /// Paint its own night-arena backdrop. Off when it is staged inside
  /// another scene (the GTA sunset), which supplies the backdrop.
  final bool arena;

  /// Where the fighters' feet sit, as a fraction of the height.
  final double groundFrac;

  /// Standing fighter height as a fraction of the height.
  final double figureFrac;

  @override
  State<ElementalFight> createState() => _ElementalFightState();
}

class _ElementalFightState extends State<ElementalFight>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _Fight();
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
    _sim
      ..groundFrac = widget.groundFrac
      ..figureFrac = widget.figureFrac;
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        // Clipped so sparks and fireballs never spill over neighbouring
        // content in the host card.
        child: ClipRect(
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _sim.size = constraints.biggest;
                return CustomPaint(
                  painter: _FightPainter(_sim, arena: widget.arena),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Poses.

/// Joint angles for a fighter facing +x. Angles are measured from straight
/// down, positive swinging forward; elbow and knee angles are relative to
/// the upper limb. [lift] raises the whole body (jumps).
class _Pose {
  const _Pose({
    this.lean = 0.1,
    this.sB = 0.6,
    this.eB = 1.9,
    this.sF = 1.0,
    this.eF = 1.6,
    this.hB = -0.35,
    this.kB = -0.3,
    this.hF = 0.35,
    this.kF = -0.5,
    this.lift = 0,
  });

  final double lean, sB, eB, sF, eF, hB, kB, hF, kF, lift;

  static _Pose lerp(_Pose a, _Pose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return _Pose(
      lean: l(a.lean, b.lean),
      sB: l(a.sB, b.sB),
      eB: l(a.eB, b.eB),
      sF: l(a.sF, b.sF),
      eF: l(a.eF, b.eF),
      hB: l(a.hB, b.hB),
      kB: l(a.kB, b.kB),
      hF: l(a.hF, b.hF),
      kF: l(a.kF, b.kF),
      lift: l(a.lift, b.lift),
    );
  }
}

abstract final class _Poses {
  static const stance = _Pose();
  static const dash = _Pose(
    lean: 0.45,
    sF: 0.6,
    eF: 1.8,
    sB: -0.4,
    eB: 1.4,
    hF: 0.8,
    kF: -0.9,
    hB: -0.6,
    kB: -0.6,
  );
  static const punch = _Pose(
    lean: 0.25,
    sF: 1.57,
    eF: 0.05,
    sB: 0.3,
    eB: 2.1,
    hF: 0.55,
    kF: -0.3,
    hB: -0.5,
    kB: 0,
  );
  static const kick = _Pose(
    lean: -0.25,
    sF: 1.1,
    eF: 1.5,
    sB: 0.4,
    eB: 1.8,
    hF: 1.55,
    kF: 0,
    hB: -0.12,
    kB: -0.1,
  );
  static const block = _Pose(
    lean: -0.05,
    sF: 1.35,
    eF: 2.0,
    sB: 1.2,
    eB: 2.2,
    hF: 0.3,
    kF: -0.6,
    hB: -0.4,
    kB: -0.4,
  );
  static const hurt = _Pose(
    lean: -0.45,
    sF: 2.2,
    eF: 0.6,
    sB: 1.7,
    eB: 0.5,
    hF: 0.25,
    kF: -0.2,
    hB: -0.25,
    kB: -0.3,
  );
  static const cast = _Pose(
    lean: 0.2,
    sF: 1.57,
    eF: 0.1,
    sB: 1.5,
    eB: 0.2,
    hF: 0.6,
    kF: -0.4,
    hB: -0.6,
    kB: -0.1,
  );
  static const charge = _Pose(
    lean: 0.05,
    sF: 0.5,
    eF: 1.0,
    sB: 0.4,
    eB: 1.1,
    hF: 0.6,
    kF: -1.1,
    hB: -0.6,
    kB: -0.9,
  );
  static const stomp = _Pose(
    lean: 0.1,
    sF: 0.9,
    eF: 0.3,
    sB: -0.7,
    eB: 0.3,
    hF: 1.2,
    kF: -1.6,
    hB: -0.2,
    kB: -0.1,
  );
  static const jump = _Pose(
    lean: 0.15,
    sF: 1.3,
    eF: 1.4,
    sB: 0.9,
    eB: 1.6,
    hF: 1.4,
    kF: -2.0,
    hB: 0.7,
    kB: -1.8,
    lift: 34,
  );
  static const kneel = _Pose(
    lean: 0.55,
    sF: 0.25,
    eF: 0.4,
    sB: 0.1,
    eB: 0.4,
    hF: 1.45,
    kF: -1.5,
    hB: -0.1,
    kB: -2.4,
  );
  static const dazed = _Pose(
    lean: -0.2,
    sF: 0.35,
    eF: 0.5,
    sB: 0.2,
    eB: 0.6,
    hF: 0.25,
    kF: -0.35,
    hB: -0.3,
    kB: -0.4,
  );
  static const victory = _Pose(
    lean: -0.05,
    sF: 3.05,
    eF: 0.1,
    sB: 0.3,
    eB: 2.2,
    hF: 0.25,
    kF: -0.1,
    hB: -0.25,
    kB: -0.1,
  );
}

// -------------------------------------------------------------------------
// Simulation.

class _Fighter {
  _Fighter(this.name, this.color, this.facing, this.homeX);

  final String name;
  final Color color;

  /// +1 faces right (left fighter), -1 faces left.
  final double facing;
  final double homeX;

  double x = 0;
  double fromX = 0;
  double toX = 0;

  _Pose pose = _Poses.stance;
  _Pose fromPose = _Poses.stance;
  _Pose toPose = _Poses.stance;

  /// Short reactions (hurt, block, jump) override the scripted pose.
  _Pose? react;
  double reactFor = 0;

  double hp = 100;
  double shownHp = 100;
  double lagHp = 100;
  double flash = 0;

  /// Glowing hands while channelling a special.
  Color? aura;
  double auraFor = 0;

  /// 1 = fully visible. Drops while shape-shifted or broken apart.
  double visible = 1;

  /// FATALITY: 0 → 1 as the body breaks apart into ash and light.
  double dissolve = 0;
  bool dissolving = false;

  /// ANIMALITY pin: 0 → 1 as the body topples flat.
  double down = 0;
  bool toppling = false;

  void resetForRound() {
    hp = shownHp = lagHp = 100;
    react = null;
    visible = 1;
    dissolve = 0;
    dissolving = false;
    down = 0;
    toppling = false;
    aura = null;
  }
}

class _Step {
  const _Step(this.dur, {this.a, this.b, this.ax, this.bx, this.event});

  final double dur;
  final _Pose? a, b;
  final double? ax, bx;
  final void Function()? event;
}

enum _Shot { fire, tornado }

class _Projectile {
  _Projectile(
    this.kind,
    this.from,
    this.to,
    this.dur,
    this.size,
    this.onArrive,
  );

  final _Shot kind;
  final Offset from, to;
  final double dur, size;
  final VoidCallback onArrive;
  double t = 0;
  Offset get pos =>
      Offset.lerp(from, to, Curves.easeIn.transform(t.clamp(0.0, 1.0)))!;
}

class _Spike {
  _Spike(this.x, this.delay, this.height);

  final double x, height;
  double delay;
  double t = 0;
}

/// FATALITY cyclone: a giant twister that forms around the target and
/// tears them apart into ash.
class _Cyclone {
  _Cyclone(this.x, {this.life = 2.8}) : maxLife = life;

  final double x;
  double life;
  final double maxLife;
}

enum _BeastKind { snake, tiger }

/// What a shape-shift does: a hit-and-return special, or a finisher that
/// stays put until the round ends.
enum _BeastPlan { strike, pounce, coil, maul }

class _Beast {
  _Beast(this.kind, this.plan, this.owner, this.target, this.x0, this.x1)
    : x = x0;

  final _BeastKind kind;
  final _BeastPlan plan;
  final _Fighter owner, target;

  /// Start and end positions, in pixels.
  final double x0, x1;
  double x;
  double t = 0;
  double opacity = 0;

  /// Tiger: height off the ground (leap) and nose-up tilt.
  double lift = 0;
  double tilt = 0;
  bool running = false;
  double roar = 0;

  /// Snake: how far the front of the body rears up, and the bite lunge.
  double rear = 0;
  double lunge = 0;

  /// Snake ANIMALITY: 0 → 1 as the coils wrap up the target.
  double coil = 0;

  bool struck = false;
  bool done = false;
}

class _Particle {
  _Particle(
    this.pos,
    this.vel,
    this.life,
    this.color,
    this.size, {
    this.rise = 0,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final Color color;
  final double size;

  /// Vertical acceleration override: negative floats (embers), 0 = gravity.
  final double rise;
}

class _Ring {
  _Ring(this.pos, this.color, {this.big = false});

  final Offset pos;
  final Color color;
  final bool big;
  double t = 0;
}

class _Fight extends ChangeNotifier {
  final _rand = math.Random(5);

  Size size = Size.zero;
  double time = 0;

  static const blazeColor = Color(0xFFFF7A2E);
  static const galeColor = AppColors.auroraCyan;
  static const earthColor = Color(0xFFC8955A);

  final a = _Fighter('BLAZE', blazeColor, 1, 0.27);
  final b = _Fighter('GALE', galeColor, -1, 0.73);

  final projectiles = <_Projectile>[];
  final spikes = <_Spike>[];
  final particles = <_Particle>[];
  final rings = <_Ring>[];
  final cyclones = <_Cyclone>[];
  final beasts = <_Beast>[];
  final _delayed = <(double, VoidCallback)>[];

  /// Arena darkening for a FATALITY, eased towards [_dimTarget].
  double dim = 0;
  double _dimTarget = 0;

  /// Screen shake from a roar or cyclone, 1 → 0.
  double shake = 0;

  /// Fighting-game call-outs: text and seconds into its display.
  String? callout;
  double calloutT = 0;
  double calloutDur = 1;

  int round = 0;
  List<_Step> _script = const [];
  int _stepIndex = -1;
  double _stepT = 0;

  double groundFrac = 0.9;
  double figureFrac = 0.64;

  double get unit => size.height * figureFrac / 100;
  double get groundY => size.height * groundFrac;

  void step(double dt) {
    if (size.isEmpty) return;
    if (_stepIndex < 0) {
      a.x = a.fromX = a.toX = a.homeX;
      b.x = b.fromX = b.toX = b.homeX;
      _nextRound();
    }
    time += dt;
    _advanceScript(dt);
    _stepFighter(a, dt);
    _stepFighter(b, dt);
    _stepEffects(dt);
    notifyListeners();
  }

  // --- Script -----------------------------------------------------------

  void _nextRound() {
    round++;
    _script = _buildRound(round);
    _stepIndex = 0;
    _stepT = 0;
    _enter(_script.first);
  }

  void _advanceScript(double dt) {
    _stepT += dt;
    final s = _script[_stepIndex];
    final k = (_stepT / s.dur).clamp(0.0, 1.0);
    final move = Curves.easeInOut.transform(k);
    final blend = Curves.easeOut.transform(
      (_stepT / math.min(0.12, s.dur * 0.6)).clamp(0.0, 1.0),
    );
    for (final f in [a, b]) {
      f.x = lerpDouble(f.fromX, f.toX, move)!;
      f.pose = _Pose.lerp(f.fromPose, f.toPose, blend);
    }
    if (_stepT >= s.dur) {
      _stepIndex++;
      if (_stepIndex >= _script.length) {
        _nextRound();
      } else {
        _stepT = 0;
        _enter(_script[_stepIndex]);
      }
    }
  }

  void _enter(_Step s) {
    void apply(_Fighter f, _Pose? p, double? x) {
      f.fromPose = f.pose;
      if (p != null) f.toPose = p;
      f.fromX = f.x;
      if (x != null) f.toX = x;
    }

    apply(a, s.a, s.ax);
    apply(b, s.b, s.bx);
    s.event?.call();
  }

  List<_Step> _buildRound(int r) {
    const p = _Poses.stance;
    // Finishers rotate: K.O. → FATALITY → ANIMALITY (tiger) → ANIMALITY
    // (serpent), so each side wins half the rounds.
    final finisher = (r - 1) % 4;
    final blazeWins = finisher == 0 || finisher == 2;
    final loser = blazeWins ? b : a;
    return [
      _Step(
        1.1,
        a: p,
        b: p,
        ax: a.homeX,
        bx: b.homeX,
        event: () {
          a.resetForRound();
          b.resetForRound();
          beasts.clear();
          _dimTarget = 0;
          say('ROUND $r', 1.0);
        },
      ),
      _Step(0.8, event: () => say('FIGHT!', 0.8)),
      // Close the distance and trade blows.
      const _Step(0.42, a: _Poses.dash, b: _Poses.dash, ax: 0.44, bx: 0.56),
      _Step(0.22, a: _Poses.punch, b: p, event: () => hit(b, 6)),
      const _Step(0.22, a: p, b: p),
      _Step(0.26, a: p, b: _Poses.kick, event: () => hit(a, 6, blocked: true)),
      const _Step(0.2, a: p, b: p),
      _Step(0.22, a: _Poses.punch, b: p, event: () => hit(b, 6, blocked: true)),
      _Step(0.22, a: p, b: _Poses.punch, event: () => hit(a, 7)),
      _Step(0.3, a: p, b: _Poses.kick, event: () => hit(a, 8)),
      _Step(0.24, a: _Poses.kick, b: p, event: () => hit(b, 8)),
      // Break apart for specials.
      const _Step(0.45, a: _Poses.dash, b: _Poses.dash, ax: 0.25, bx: 0.75),
      const _Step(0.15, a: p, b: p),
      _Step(0.4, a: _Poses.cast, event: () => fireball(a, b)),
      const _Step(0.75, a: p),
      _Step(0.45, b: _Poses.cast, event: () => tornado(b, a)),
      const _Step(1.05, b: p),
      _Step(0.4, a: _Poses.stomp, event: () => earthSpikes(a, b)),
      const _Step(1.0, a: p),
      // Shape-shifts: Gale's serpent strike, then Blaze's tiger pounce.
      _Step(
        0.25,
        b: _Poses.charge,
        event: () => shapeShift(b, a, _BeastPlan.strike),
      ),
      const _Step(1.75, a: p),
      const _Step(0.45, a: _Poses.dash, b: _Poses.dash, ax: 0.25, bx: 0.75),
      _Step(
        0.25,
        a: _Poses.charge,
        event: () => shapeShift(a, b, _BeastPlan.pounce),
      ),
      const _Step(1.5, b: p),
      // One more exchange up close.
      const _Step(0.4, a: _Poses.dash, b: _Poses.dash, ax: 0.43, bx: 0.57),
      _Step(0.24, a: _Poses.kick, b: p, event: () => hit(b, 7, blocked: true)),
      _Step(0.22, a: p, b: _Poses.punch, event: () => hit(a, 6)),
      _Step(0.22, a: _Poses.punch, b: p, event: () => hit(b, 6)),
      const _Step(0.45, a: _Poses.dash, b: _Poses.dash, ax: 0.26, bx: 0.74),
      ...switch (finisher) {
        0 => _koFinish(),
        1 => _fatalityFinish(),
        2 => _animalityFinish(a, b, _BeastPlan.maul),
        _ => _animalityFinish(b, a, _BeastPlan.coil),
      },
      _Step(0.01, event: () => loser.hp = 0),
    ];
  }

  /// Blaze's super fireball, then a plain K.O.
  List<_Step> _koFinish() {
    const p = _Poses.stance;
    return [
      _Step(
        0.6,
        a: _Poses.charge,
        b: p,
        event: () => a
          ..aura = a.color
          ..auraFor = 0.8,
      ),
      _Step(0.45, a: _Poses.cast, event: () => superFire(a, b)),
      const _Step(0.9, a: p, b: p),
      _Step(
        2.4,
        a: _Poses.victory,
        b: _Poses.kneel,
        event: () {
          b
            ..hp = 0
            ..react = null;
          say('K.O.', 1.6);
        },
      ),
    ];
  }

  /// Gale whips up a cyclone around a dazed Blaze, who breaks apart.
  List<_Step> _fatalityFinish() {
    return [
      _Step(
        1.0,
        a: _Poses.dazed,
        b: _Poses.stance,
        event: () => say('FINISH!', 0.9),
      ),
      _Step(0.4, b: _Poses.cast, event: () => fatalityCyclone(b, a)),
      const _Step(2.3, b: _Poses.cast),
      _Step(2.4, b: _Poses.victory, event: () => say('FATALITY', 2.0)),
    ];
  }

  /// The winner shape-shifts and finishes the dazed loser as a beast.
  List<_Step> _animalityFinish(
    _Fighter winner,
    _Fighter loser,
    _BeastPlan plan,
  ) {
    final blaze = winner == a;
    return [
      _Step(
        1.0,
        a: blaze ? _Poses.stance : _Poses.dazed,
        b: blaze ? _Poses.dazed : _Poses.stance,
        event: () => say('FINISH!', 0.9),
      ),
      _Step(
        0.3,
        a: blaze ? _Poses.charge : null,
        b: blaze ? null : _Poses.charge,
        event: () => shapeShift(winner, loser, plan),
      ),
      const _Step(2.4),
      _Step(2.3, event: () => say('ANIMALITY', 2.0)),
    ];
  }

  // --- Moves ------------------------------------------------------------

  void say(String text, double dur) {
    callout = text;
    calloutT = 0;
    calloutDur = dur;
  }

  /// Where on a fighter blows and specials land.
  Offset chestOf(_Fighter f) => Offset(f.x * size.width, groundY - 62 * unit);

  Offset handsOf(_Fighter f) =>
      Offset(f.x * size.width + f.facing * 34 * unit, groundY - 70 * unit);

  void hit(
    _Fighter target,
    double dmg, {
    bool blocked = false,
    bool finisher = false,
  }) {
    final at = chestOf(target) + Offset(-target.facing * 6 * unit, 0);
    rings.add(_Ring(at, blocked ? AppColors.auroraCyan : Colors.white));
    for (var i = 0; i < 6; i++) {
      final ang = _rand.nextDouble() * 2 * math.pi;
      particles.add(
        _Particle(
          at,
          Offset(math.cos(ang), math.sin(ang)) *
              (60 + _rand.nextDouble() * 80) *
              unit,
          0.2 + _rand.nextDouble() * 0.15,
          blocked ? AppColors.auroraCyan : const Color(0xFFFFF1C9),
          1.2,
        ),
      );
    }
    if (finisher) {
      target.hp = 0;
    } else {
      target.hp = math.max(12, target.hp - (blocked ? dmg * 0.2 : dmg));
    }
    target
      ..flash = blocked ? 0 : 0.15
      ..react = blocked ? _Poses.block : _Poses.hurt
      ..reactFor = blocked ? 0.22 : 0.32;
    if (!blocked) {
      // Knock back a touch, away from the attacker.
      final shove = -target.facing * 0.015;
      target
        ..fromX += shove
        ..toX += shove
        ..x += shove;
    }
  }

  void fireball(_Fighter from, _Fighter to, {double size = 1}) {
    from
      ..aura = blazeColor
      ..auraFor = 0.4;
    projectiles.add(
      _Projectile(_Shot.fire, handsOf(from), chestOf(to), 0.7, size, () {
        _burst(chestOf(to), blazeColor, 14 * size.round());
        hit(to, 14, finisher: size > 1);
      }),
    );
  }

  void superFire(_Fighter from, _Fighter to) => fireball(from, to, size: 2);

  void tornado(_Fighter from, _Fighter to) {
    from
      ..aura = galeColor
      ..auraFor = 0.45;
    final ground = Offset(handsOf(from).dx, groundY);
    projectiles.add(
      _Projectile(
        _Shot.tornado,
        ground,
        Offset(to.x * size.width, groundY),
        1.0,
        1,
        () {
          hit(to, 12);
          final shove = -to.facing * 0.03;
          to
            ..fromX += shove
            ..toX += shove;
        },
      ),
    );
  }

  void earthSpikes(_Fighter from, _Fighter to) {
    final x0 = from.x * size.width + from.facing * 30 * unit;
    final x1 = to.x * size.width;
    const n = 6;
    for (var i = 0; i < n; i++) {
      final x = lerpDouble(x0, x1, i / (n - 1))!;
      spikes.add(_Spike(x, 0.08 + i * 0.1, (22 + i * 5) * unit));
    }
    // The target hops clear just before the last spikes break ground.
    _delayed.add((
      0.38,
      () => to
        ..react = _Poses.jump
        ..reactFor = 0.55,
    ));
  }

  // --- Finishers & shape-shifts -------------------------------------------

  /// FATALITY: the arena darkens, a giant cyclone forms around [to] and
  /// whips them around, then the body breaks apart into ash on the wind.
  void fatalityCyclone(_Fighter from, _Fighter to) {
    _dimTarget = 1;
    from
      ..aura = galeColor
      ..auraFor = 2.2;
    cyclones.add(_Cyclone(to.x * size.width));
    shake = 0.5;
    for (var i = 0; i < 4; i++) {
      _delayed.add((0.4 + i * 0.25, () => hit(to, 0, finisher: i == 3)));
    }
    _delayed.add((
      1.45,
      () {
        to
          ..react = _Poses.hurt
          ..reactFor = 9
          ..dissolving = true;
      },
    ));
    _delayed.add((3.4, () => _dimTarget = 0));
  }

  /// [owner] turns into their beast. Strike/pounce hit and turn back;
  /// coil/maul are finishers that hold until the round ends.
  void shapeShift(_Fighter owner, _Fighter target, _BeastPlan plan) {
    final kind = owner == b ? _BeastKind.snake : _BeastKind.tiger;
    final x0 = owner.x * size.width;
    final tx = target.x * size.width;
    final stopShort = switch (plan) {
      _BeastPlan.strike => 34,
      _BeastPlan.coil => 30,
      _BeastPlan.pounce => 26,
      _BeastPlan.maul => 6,
    };
    final x1 = tx - owner.facing * stopShort * unit;
    beasts.add(_Beast(kind, plan, owner, target, x0, x1));
    _morphPuff(Offset(x0, groundY - 40 * unit), owner.color);
  }

  void _morphPuff(Offset at, Color color) {
    rings.add(_Ring(at, color, big: true));
    for (var i = 0; i < 16; i++) {
      final ang = i / 16 * 2 * math.pi;
      particles.add(
        _Particle(
          at + Offset(math.cos(ang), math.sin(ang)) * 10 * unit,
          Offset(-math.sin(ang), math.cos(ang)) * 70 * unit +
              Offset(0, -20 * unit),
          0.45,
          i.isEven ? color : Colors.white,
          1.3,
          rise: -20,
        ),
      );
    }
  }

  void _stepBeast(_Beast be, double dt) {
    be.t += dt;
    final t = be.t;
    final owner = be.owner;
    final target = be.target;
    final dir = owner.facing;
    double phase(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);

    // Morph in over the first quarter second.
    be.opacity = phase(0, 0.25);
    switch (be.plan) {
      case _BeastPlan.strike:
        be.x = lerpDouble(
          be.x0,
          be.x1,
          Curves.easeInOut.transform(phase(0.25, 0.95)),
        )!;
        be.running = t > 0.25 && t < 0.95;
        be.rear =
            Curves.easeOut.transform(phase(0.95, 1.15)) *
            (1 - phase(1.35, 1.5));
        be.lunge = t < 1.3
            ? Curves.easeIn.transform(phase(1.15, 1.27))
            : 1 - phase(1.3, 1.42);
        if (!be.struck && t >= 1.25) {
          be.struck = true;
          hit(target, 12);
        }
        if (t >= 1.5) be.opacity = 1 - phase(1.5, 1.72);
        if (t >= 1.72) be.done = true;
      case _BeastPlan.pounce:
        final runEnd = lerpDouble(be.x0, be.x1, 0.45)!;
        if (t < 0.65) {
          be.x = lerpDouble(
            be.x0,
            runEnd,
            Curves.easeIn.transform(phase(0.25, 0.65)),
          )!;
        } else {
          be.x = lerpDouble(runEnd, be.x1, phase(0.65, 1.0))!;
        }
        be.running = t > 0.25 && t < 0.65;
        final leap = phase(0.65, 1.0);
        be.lift = math.sin(leap * math.pi) * 26 * unit;
        be.tilt = t > 0.65 && t < 1.0 ? (0.5 - leap) * 0.6 : 0;
        if (!be.struck && t >= 0.98) {
          be.struck = true;
          hit(target, 13);
          _burst(chestOf(target), blazeColor, 10);
        }
        if (t >= 1.2) be.opacity = 1 - phase(1.2, 1.42);
        if (t >= 1.42) be.done = true;
      case _BeastPlan.maul:
        final runEnd = lerpDouble(be.x0, be.x1, 0.5)!;
        if (t < 0.7) {
          be.x = lerpDouble(
            be.x0,
            runEnd,
            Curves.easeIn.transform(phase(0.3, 0.7)),
          )!;
        } else {
          be.x = lerpDouble(runEnd, be.x1, phase(0.7, 1.05))!;
        }
        be.running = t > 0.3 && t < 0.7;
        final leap = phase(0.7, 1.05);
        be.lift = math.sin(leap * math.pi) * 30 * unit;
        be.tilt = t > 0.7 && t < 1.05 ? (0.5 - leap) * 0.6 : 0;
        if (!be.struck && t >= 1.0) {
          be.struck = true;
          target
            ..react = _Poses.hurt
            ..reactFor = 9
            ..toppling = true
            ..flash = 0.2;
          _burst(chestOf(target), blazeColor, 14);
          shake = 0.6;
        }
        // Two roars over the pinned opponent.
        for (final at in [1.5, 2.3]) {
          if (t >= at && t - dt < at) {
            shake = 0.8;
            rings
              ..add(
                _Ring(
                  Offset(be.x + dir * 30 * unit, groundY - 34 * unit),
                  blazeColor,
                  big: true,
                ),
              )
              ..add(
                _Ring(
                  Offset(be.x + dir * 30 * unit, groundY - 34 * unit),
                  Colors.white,
                ),
              );
          }
        }
        be.roar = (t > 1.4 && t < 1.9) || (t > 2.2 && t < 2.7) ? 1 : 0;
      case _BeastPlan.coil:
        be.x = lerpDouble(
          be.x0,
          be.x1,
          Curves.easeInOut.transform(phase(0.3, 1.1)),
        )!;
        be.running = t > 0.3 && t < 1.1;
        be.rear = Curves.easeOut.transform(phase(1.1, 1.4));
        be.coil = Curves.easeInOut.transform(phase(1.1, 1.8));
        if (!be.struck && t >= 1.8) {
          be.struck = true;
          target
            ..react = _Poses.kneel
            ..reactFor = 9
            ..flash = 0.2;
          shake = 0.4;
        }
    }

    // The fighter fades out as the beast fades in, and back.
    owner.visible = 1 - be.opacity;
    if (be.done) {
      owner
        ..visible = 1
        ..x = be.x / size.width
        ..fromX = be.x / size.width
        ..toX = be.x / size.width;
      _morphPuff(Offset(be.x, groundY - 40 * unit), owner.color);
    }
  }

  void _burst(Offset at, Color color, int n) {
    rings.add(_Ring(at, color, big: true));
    for (var i = 0; i < n; i++) {
      final ang = _rand.nextDouble() * 2 * math.pi;
      particles.add(
        _Particle(
          at,
          Offset(math.cos(ang), math.sin(ang)) *
              (30 + _rand.nextDouble() * 90) *
              unit,
          0.35 + _rand.nextDouble() * 0.4,
          color,
          1.6,
          rise: -40,
        ),
      );
    }
  }

  // --- Per-frame ----------------------------------------------------------

  void _stepFighter(_Fighter f, double dt) {
    f.flash = math.max(0, f.flash - dt);
    f.auraFor = math.max(0, f.auraFor - dt);
    if (f.auraFor == 0) f.aura = null;
    if (f.react != null) {
      f.reactFor -= dt;
      if (f.reactFor <= 0) f.react = null;
    }
    if (f.toppling) f.down = math.min(1, f.down + dt / 0.4);
    if (f.dissolving && f.dissolve < 1) {
      f.dissolve = math.min(1, f.dissolve + dt / 1.0);
      f.visible = 1 - f.dissolve;
      // Ash and sparks shed from all over the body, drifting upward.
      for (var i = 0; i < 4; i++) {
        final at = Offset(
          f.x * size.width + (_rand.nextDouble() - 0.5) * 24 * unit,
          groundY - _rand.nextDouble() * 95 * unit,
        );
        particles.add(
          _Particle(
            at,
            Offset(
                  (_rand.nextDouble() - 0.5) * 30,
                  -30 - _rand.nextDouble() * 50,
                ) *
                unit,
            0.7 + _rand.nextDouble() * 0.6,
            i == 0
                ? galeColor
                : (i == 1 ? Colors.white : const Color(0xFF8A8296)),
            1.1,
            rise: -15,
          ),
        );
      }
    }
    // Health bar: the bar snaps down, a pale "damage" chunk drains after.
    f.shownHp += (f.hp - f.shownHp) * math.min(1, dt * 18);
    if (f.hp >= f.lagHp) {
      f.lagHp = f.hp;
    } else {
      f.lagHp = math.max(f.hp, f.lagHp - dt * 40);
    }
  }

  void _stepEffects(double dt) {
    calloutT += dt;
    if (calloutT > calloutDur) callout = null;
    shake = math.max(0, shake - dt * 2.5);
    dim += (_dimTarget - dim) * math.min(1, dt * 4);

    for (final c in cyclones) {
      c.life -= dt;
      if (c.life > 0.4) shake = math.max(shake, 0.25);
    }
    cyclones.removeWhere((c) => c.life <= 0);

    for (final be in beasts) {
      _stepBeast(be, dt);
    }
    beasts.removeWhere((be) => be.done);

    for (var i = _delayed.length - 1; i >= 0; i--) {
      final (t, fn) = _delayed[i];
      if (t - dt <= 0) {
        _delayed.removeAt(i);
        fn();
      } else {
        _delayed[i] = (t - dt, fn);
      }
    }

    for (final p in projectiles) {
      p.t += dt / p.dur;
      if (p.kind == _Shot.fire) {
        // Ember trail.
        for (var i = 0; i < 2; i++) {
          particles.add(
            _Particle(
              p.pos,
              Offset(
                    (_rand.nextDouble() - 0.5) * 30,
                    (_rand.nextDouble() - 0.5) * 30,
                  ) *
                  unit,
              0.3 + _rand.nextDouble() * 0.2,
              i.isEven ? const Color(0xFFFFB25A) : const Color(0xFFFF4D2E),
              1.3 * p.size,
              rise: -30,
            ),
          );
        }
      } else if (_rand.nextDouble() < 0.5) {
        particles.add(
          _Particle(
            p.pos + Offset((_rand.nextDouble() - 0.5) * 20 * unit, -2),
            Offset(
                  (_rand.nextDouble() - 0.5) * 40,
                  -20 - _rand.nextDouble() * 30,
                ) *
                unit,
            0.5,
            const Color(0xFF9A8C7A),
            1.4,
          ),
        );
      }
      if (p.t >= 1) p.onArrive();
    }
    projectiles.removeWhere((p) => p.t >= 1);

    for (final s in spikes) {
      if (s.delay > 0) {
        s.delay -= dt;
        if (s.delay <= 0) {
          for (var i = 0; i < 4; i++) {
            particles.add(
              _Particle(
                Offset(s.x, groundY),
                Offset(
                      (_rand.nextDouble() - 0.5) * 60,
                      -30 - _rand.nextDouble() * 60,
                    ) *
                    unit,
                0.45,
                earthColor,
                1.4,
              ),
            );
          }
        }
        continue;
      }
      s.t += dt;
    }
    spikes.removeWhere((s) => s.t > 0.65);

    for (final p in particles) {
      p.vel += Offset(0, p.rise == 0 ? 220 * unit : p.rise * unit) * dt;
      p.pos += p.vel * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);

    for (final r in rings) {
      r.t += dt / (r.big ? 0.4 : 0.22);
    }
    rings.removeWhere((r) => r.t >= 1);
  }
}

// -------------------------------------------------------------------------
// Painting.

class _FightPainter extends CustomPainter {
  _FightPainter(this.sim, {required this.arena}) : super(repaint: sim);

  final _Fight sim;
  final bool arena;

  static const _ink = Color(0xFF0B0A1C);

  @override
  void paint(Canvas canvas, Size size) {
    final g = sim.groundY;
    final u = sim.unit;

    if (arena) _arena(canvas, size, g);

    if (sim.dim > 0.01) _dim(canvas, size);

    canvas.save();
    if (sim.shake > 0) {
      final k = sim.shake * sim.shake * 2.5;
      canvas.translate(
        math.sin(sim.time * 90) * k,
        math.cos(sim.time * 70) * k * 0.6,
      );
    }

    for (final s in sim.spikes) {
      _spike(canvas, s, g, u);
    }
    _fighter(canvas, sim.a);
    _fighter(canvas, sim.b);
    for (final be in sim.beasts) {
      be.kind == _BeastKind.snake
          ? _snake(canvas, be, u)
          : _tiger(canvas, be, u);
    }
    for (final c in sim.cyclones) {
      _cyclone(canvas, c, u);
    }
    for (final p in sim.projectiles) {
      p.kind == _Shot.fire ? _fireball(canvas, p, u) : _tornado(canvas, p, u);
    }
    for (final p in sim.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        p.size * u * 1.6 * (0.4 + 0.6 * t),
        Paint()..color = p.color.withValues(alpha: t),
      );
    }
    for (final r in sim.rings) {
      final e = Curves.easeOut.transform(r.t);
      canvas.drawCircle(
        r.pos,
        (r.big ? 26 : 12) * u * (0.3 + e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (r.big ? 3 : 2) * (1 - r.t) + 0.5
          ..color = r.color.withValues(alpha: 0.9 * (1 - r.t)),
      );
    }

    canvas.restore();

    _hud(canvas, size);
    _callout(canvas, size);
  }

  void _arena(Canvas canvas, Size size, double g) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0F2A), Color(0xFF1C1238), Color(0xFF2A1430)],
        ).createShader(Offset.zero & size),
    );
    // Moon and a glowing ring platform under the fighters.
    final moon = Offset(size.width * 0.5, size.height * 0.32);
    canvas.drawCircle(
      moon,
      size.height * 0.5,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF8B7BFF).withValues(alpha: 0.22),
                const Color(0xFF8B7BFF).withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: moon, radius: size.height * 0.5),
            ),
    );
    canvas.drawCircle(
      moon,
      size.height * 0.13,
      Paint()..color = const Color(0xFFE6E0FF).withValues(alpha: 0.18),
    );

    canvas.drawRect(
      Rect.fromLTRB(0, g, size.width, size.height),
      Paint()..color = const Color(0xFF120C22),
    );
    final ring = Rect.fromCenter(
      center: Offset(size.width / 2, g + 2),
      width: size.width * 0.8,
      height: size.height * 0.12,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          colors: [
            _Fight.blazeColor.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0.15),
            _Fight.galeColor.withValues(alpha: 0.5),
          ],
        ).createShader(ring),
    );
    canvas.drawLine(
      Offset(0, g),
      Offset(size.width, g),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  void _fighter(Canvas canvas, _Fighter f) {
    if (f.visible <= 0.01) return;
    final u = sim.unit;
    final pose = f.react ?? f.pose;
    canvas.save();
    canvas.translate(f.x * sim.size.width, sim.groundY);
    canvas.scale(f.facing * u, u);
    if (f.visible < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: f.visible),
      );
    }
    if (f.down > 0) {
      // Topple backwards about the heels onto the ground.
      final k = Curves.easeIn.transform(f.down);
      canvas.translate(-8 * k, -5 * k);
      canvas.rotate(-math.pi / 2 * k);
    }

    final j = _Joints.solve(pose);
    canvas.save();
    canvas.translate(1.4, -0.7);
    _body(
      canvas,
      j,
      f.flash > 0 ? Colors.white : f.color.withValues(alpha: 0.8),
    );
    canvas.restore();
    _body(canvas, j, _ink);

    // Headband tails streaming behind the head.
    final flutter = math.sin(sim.time * 14 + f.facing) * 3;
    final knot = j.head + const Offset(-6, -2);
    final band = Paint()
      ..color = f.color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      j.head + const Offset(-6, -3),
      j.head + const Offset(6, -3),
      band,
    );
    canvas.drawPath(
      Path()
        ..moveTo(knot.dx, knot.dy)
        ..quadraticBezierTo(
          knot.dx - 8,
          knot.dy + flutter,
          knot.dx - 16,
          knot.dy + 2 + flutter * 1.6,
        ),
      band,
    );
    canvas.drawPath(
      Path()
        ..moveTo(knot.dx, knot.dy)
        ..quadraticBezierTo(
          knot.dx - 7,
          knot.dy + 4 - flutter,
          knot.dx - 13,
          knot.dy + 7 - flutter,
        ),
      band,
    );

    // Power glowing in the hands while channelling.
    final aura = f.aura;
    if (aura != null) {
      final pulse = 0.7 + 0.3 * math.sin(sim.time * 30);
      for (final hand in [j.handF, j.handB]) {
        canvas.drawCircle(
          hand,
          9 * pulse,
          Paint()
            ..color = aura.withValues(alpha: 0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
    if (f.visible < 1) canvas.restore();
    canvas.restore();
  }

  void _body(Canvas canvas, _Joints j, Color color) {
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    limb.strokeWidth = 9;
    canvas.drawPath(
      Path()
        ..moveTo(j.hip.dx, j.hip.dy)
        ..lineTo(j.kneeB.dx, j.kneeB.dy)
        ..lineTo(j.footB.dx, j.footB.dy),
      limb,
    );
    limb.strokeWidth = 7;
    canvas.drawPath(
      Path()
        ..moveTo(j.shoulder.dx, j.shoulder.dy)
        ..lineTo(j.elbowB.dx, j.elbowB.dy)
        ..lineTo(j.handB.dx, j.handB.dy),
      limb,
    );
    canvas.drawCircle(j.handB, 4.2, fill);

    // Torso: a tapered gi top, belt at the hips.
    final n = Offset(math.cos(j.lean), math.sin(j.lean));
    canvas.drawPath(
      Path()
        ..moveTo(j.hip.dx - n.dx * 6, j.hip.dy - n.dy * 6)
        ..lineTo(j.hip.dx + n.dx * 6, j.hip.dy + n.dy * 6)
        ..lineTo(j.shoulder.dx + n.dx * 9, j.shoulder.dy + n.dy * 9)
        ..lineTo(j.shoulder.dx - n.dx * 8, j.shoulder.dy - n.dy * 8)
        ..close(),
      fill,
    );
    canvas.drawCircle(j.head, 7, fill);

    limb.strokeWidth = 9;
    canvas.drawPath(
      Path()
        ..moveTo(j.hip.dx, j.hip.dy)
        ..lineTo(j.kneeF.dx, j.kneeF.dy)
        ..lineTo(j.footF.dx, j.footF.dy),
      limb,
    );
    limb.strokeWidth = 7;
    canvas.drawPath(
      Path()
        ..moveTo(j.shoulder.dx, j.shoulder.dy)
        ..lineTo(j.elbowF.dx, j.elbowF.dy)
        ..lineTo(j.handF.dx, j.handF.dy),
      limb,
    );
    canvas.drawCircle(j.handF, 4.2, fill);
  }

  void _fireball(Canvas canvas, _Projectile p, double u) {
    final r = 8 * u * p.size;
    final c = p.pos;
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..color = const Color(0xFFFF7A2E).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFD36E),
            Color(0xFFFF6A2E),
            Color(0x00FF3D1E),
          ],
          stops: [0, 0.3, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _tornado(Canvas canvas, _Projectile p, double u) =>
      _twister(canvas, p.pos, math.min(1.0, p.t * 4), u);

  /// FATALITY cyclone: the same twister at double size, wrapped around
  /// the target, swelling in and dying away.
  void _cyclone(Canvas canvas, _Cyclone c, double u) {
    final age = c.maxLife - c.life;
    final grow = math.min(1.0, age / 0.4) * math.min(1.0, c.life / 0.4);
    _twister(canvas, Offset(c.x, sim.groundY), grow, u * 2);
  }

  void _twister(Canvas canvas, Offset base, double grow, double u) {
    for (var i = 0; i < 6; i++) {
      final k = i / 5;
      final y = base.dy - k * 62 * u * grow;
      final w = (7 + k * 28) * u * grow;
      final sway = math.sin(sim.time * 12 + i * 0.9) * 4 * u;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(base.dx + sway, y),
          width: w * 2,
          height: w * 0.5,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color.lerp(
            _Fight.galeColor,
            Colors.white,
            k,
          )!.withValues(alpha: 0.75 - k * 0.3),
      );
    }
    // Wind streaks whipping around it.
    for (var i = 0; i < 3; i++) {
      final a = sim.time * 9 + i * 2.1;
      final y = base.dy - (14 + i * 12) * u * grow;
      final w = (14 + i * 6) * u * grow;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(base.dx, y),
          width: w * 2,
          height: w * 0.7,
        ),
        a,
        1.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _spike(Canvas canvas, _Spike s, double g, double u) {
    if (s.delay > 0) return;
    // Burst up, hold, sink back.
    final t = s.t;
    final k = t < 0.1
        ? Curves.easeOut.transform(t / 0.1)
        : (t < 0.4 ? 1.0 : 1 - (t - 0.4) / 0.25);
    final h = s.height * k.clamp(0.0, 1.0);
    if (h <= 0) return;
    final w = 9 * u;
    final path = Path()
      ..moveTo(s.x - w, g)
      ..lineTo(s.x - w * 0.2, g - h)
      ..lineTo(s.x + w * 0.35, g - h * 0.82)
      ..lineTo(s.x + w, g)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2A1F1A));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _Fight.earthColor.withValues(alpha: 0.8),
    );
  }

  /// Soft vignette that darkens the arena for a FATALITY.
  void _dim(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.max(size.width, size.height) * 0.75;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.55 * sim.dim),
            Colors.black.withValues(alpha: 0.35 * sim.dim),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// Gale's serpent form: a tapering body of overlapping segments that
  /// undulates as it slithers, rears its front third up to strike, and
  /// (ANIMALITY) coils up around its target.
  void _snake(Canvas canvas, _Beast be, double u) {
    final dir = be.owner.facing;
    final g = sim.groundY;
    const n = 26;
    final seg = 5.2 * u;
    final head = Offset(be.x + dir * be.lunge * 20 * u, 0);
    final pts = <Offset>[];
    final radii = <double>[];
    for (var i = 0; i < n; i++) {
      final r = (6.2 - 4.6 * i / n) * u;
      final wave =
          math.sin(i * 0.55 - sim.time * (be.running ? 14 : 4)) *
          (be.running ? 2.2 : 0.8) *
          u;
      var x = head.dx - dir * i * seg;
      var y = g - r - wave.abs();
      // Rear the front of the body up into an S-curve.
      if (i < 11) {
        final k = math.pow((11 - i) / 11, 1.5).toDouble();
        y -= be.rear * k * 40 * u;
        x += -dir * be.rear * math.sin(i / 11 * math.pi) * 6 * u;
      }
      pts.add(Offset(x, y));
      radii.add(r);
    }

    if (be.opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: be.opacity),
      );
    }
    final rim = Paint()..color = be.owner.color.withValues(alpha: 0.8);
    final ink = Paint()..color = _ink;
    // One smooth tapering body: round-capped strokes between neighbouring
    // points, each as wide as the body at that point.
    void bodyPass(Color color, Offset shift, double extra) {
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = n - 1; i > 0; i--) {
        stroke.strokeWidth = (radii[i] + radii[i - 1]) + extra;
        canvas.drawLine(pts[i] + shift, pts[i - 1] + shift, stroke);
      }
    }

    bodyPass(rim.color, Offset(0.9 * u, -0.7 * u), 0.8 * u);
    bodyPass(_ink, Offset.zero, 0);
    // Scale markings down the back.
    final mark = Paint()..color = be.owner.color.withValues(alpha: 0.55);
    for (var i = 2; i < n - 3; i += 3) {
      canvas.drawCircle(
        pts[i] - Offset(0, radii[i] * 0.45),
        radii[i] * 0.28,
        mark,
      );
    }

    // Wedge-shaped head, glowing eye, flicking tongue.
    final h = pts.first;
    canvas.save();
    canvas.translate(h.dx, h.dy);
    canvas.scale(dir, 1);
    final headPath = Path()
      ..moveTo(-3 * u, -4.5 * u)
      ..quadraticBezierTo(7 * u, -5 * u, 10 * u, -0.5 * u)
      ..quadraticBezierTo(7 * u, 3.5 * u, -3 * u, 4 * u)
      ..close();
    canvas.drawPath(headPath.shift(Offset(0.9 * u, -0.7 * u)), rim);
    canvas.drawPath(headPath, ink);
    canvas.drawCircle(
      Offset(4 * u, -1.8 * u),
      1.3 * u,
      Paint()
        ..color = be.owner.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    if (be.rear > 0.3 && (sim.time * 6).floor().isEven) {
      final tongue = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * u
        ..color = const Color(0xFFFF4D67);
      canvas.drawPath(
        Path()
          ..moveTo(10 * u, -0.3 * u)
          ..lineTo(15 * u, -0.3 * u)
          ..lineTo(17 * u, -2 * u)
          ..moveTo(15 * u, -0.3 * u)
          ..lineTo(17 * u, 1.4 * u),
        tongue,
      );
    }
    canvas.restore();

    if (be.coil > 0) _coils(canvas, be, u);
    if (be.opacity < 1) canvas.restore();
  }

  /// ANIMALITY: loops of the serpent wrapping up around the target from
  /// the ankles to the chest, squeezing.
  void _coils(Canvas canvas, _Beast be, double u) {
    final cx = be.target.x * sim.size.width;
    final g = sim.groundY;
    const loops = 4;
    final squeeze = be.struck ? 1 - 0.06 * math.sin(sim.time * 8).abs() : 1.0;
    for (var j = 0; j < loops; j++) {
      final k = ((be.coil * loops) - j).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final rect = Rect.fromCenter(
        center: Offset(cx, g - (8 + j * 12) * u),
        width: 30 * u * squeeze,
        height: 9 * u,
      );
      canvas.drawArc(
        rect.shift(Offset(0.9 * u, -0.7 * u)),
        0,
        math.pi * 2 * k,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7.5 * u
          ..color = be.owner.color.withValues(alpha: 0.8),
      );
      canvas.drawArc(
        rect,
        0,
        math.pi * 2 * k,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.5 * u
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
    }
  }

  /// Blaze's fire-tiger form: a running quadruped with flames streaming
  /// off its back, leaping and roaring.
  void _tiger(Canvas canvas, _Beast be, double u) {
    final dir = be.owner.facing;
    final g = sim.groundY;
    if (be.opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: be.opacity),
      );
    }
    canvas.save();
    canvas.translate(be.x, g - be.lift);
    canvas.scale(dir * u, u);

    final phase = sim.time * 16;
    final leaping = be.lift > 1;
    // Leg swing: galloping while running, stretched out mid-leap, planted
    // otherwise.
    double swing(double offset) =>
        be.running ? math.sin(phase + offset) * 0.8 : 0;
    final legs = <(double, double, double)>[
      // (hip x, upper angle, lower angle)
      (16, leaping ? 1.1 : swing(0), leaping ? 0.3 : swing(0) * 0.5),
      (
        12,
        leaping ? 0.9 : swing(math.pi),
        leaping ? 0.2 : swing(math.pi) * 0.5,
      ),
      (
        -16,
        leaping ? -1.1 : swing(math.pi / 2),
        leaping ? -0.3 : -0.4 + swing(math.pi / 2) * 0.4,
      ),
      (
        -20,
        leaping ? -0.9 : swing(-math.pi / 2),
        leaping ? -0.2 : -0.4 + swing(-math.pi / 2) * 0.4,
      ),
    ];

    void body(Paint fill, Paint limb) {
      canvas.save();
      canvas.translate(0, -30);
      canvas.rotate(-be.tilt);
      // Torso.
      canvas.drawOval(const Rect.fromLTRB(-28, -10, 26, 9), fill);
      // Head with snout and ears; jaw drops when roaring.
      canvas.drawCircle(const Offset(27, -10), 9, fill);
      canvas.drawOval(const Rect.fromLTRB(28, -10, 42, -2), fill);
      canvas.drawPath(
        Path()
          ..moveTo(21, -17)
          ..lineTo(23, -25)
          ..lineTo(27, -18)
          ..close(),
        fill,
      );
      if (be.roar > 0) {
        canvas.drawPath(
          Path()
            ..moveTo(30, -3)
            ..lineTo(42, 6)
            ..lineTo(28, 2)
            ..close(),
          fill,
        );
      }
      // Tail curling up behind.
      final sway = math.sin(sim.time * 6) * 4;
      canvas.drawPath(
        Path()
          ..moveTo(-26, -4)
          ..quadraticBezierTo(-42, -2 + sway, -46, -18 + sway),
        limb..strokeWidth = 4,
      );
      canvas.restore();
      limb.strokeWidth = 6;
      for (final (hx, up, low) in legs) {
        final hip = Offset(hx, -26);
        final knee = hip + Offset(math.sin(up) * 14, math.cos(up) * 14);
        final paw =
            knee + Offset(math.sin(up + low) * 13, math.cos(up + low) * 13);
        canvas.drawPath(
          Path()
            ..moveTo(hip.dx, hip.dy)
            ..lineTo(knee.dx, knee.dy)
            ..lineTo(paw.dx, paw.dy),
          limb,
        );
      }
    }

    Paint limbPaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(1.2, -0.8);
    body(
      Paint()..color = be.owner.color.withValues(alpha: 0.85),
      limbPaint(be.owner.color.withValues(alpha: 0.85)),
    );
    canvas.restore();
    body(Paint()..color = _ink, limbPaint(_ink));

    // Flames streaming off the back, and a glowing eye.
    canvas.save();
    canvas.translate(0, -30);
    canvas.rotate(-be.tilt);
    for (var i = 0; i < 6; i++) {
      final x = -22 + i * 9.0;
      final hgt = 7 + 6 * (0.5 + 0.5 * math.sin(sim.time * 22 + i * 1.7));
      final flame = Path()
        ..moveTo(x - 4, -8)
        ..quadraticBezierTo(x - 2, -8 - hgt * 0.6, x - 5, -8 - hgt)
        ..quadraticBezierTo(x + 2, -8 - hgt * 0.5, x + 4, -8)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFE6A3),
              _Fight.blazeColor,
              _Fight.blazeColor.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(x - 5, -8 - hgt, 9, hgt)),
      );
    }
    canvas.drawCircle(
      const Offset(31, -12),
      1.6,
      Paint()
        ..color = const Color(0xFFFFD36E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.restore();

    canvas.restore();
    if (be.opacity < 1) canvas.restore();
  }

  /// Health bars and names along the top, fighting-game style.
  void _hud(Canvas canvas, Size size) {
    final barW = size.width * 0.34;
    final barH = math.max(3.5, size.height * 0.045);
    const top = 8.0;
    const inset = 12.0;
    for (final f in [sim.a, sim.b]) {
      final left = f.facing > 0;
      final x0 = left ? inset : size.width - inset - barW;
      final track = Rect.fromLTWH(x0, top, barW, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, Radius.circular(barH / 2)),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      Rect part(double hp) {
        final w = barW * (hp / 100).clamp(0.0, 1.0);
        return left
            ? Rect.fromLTWH(x0 + barW - w, top, w, barH)
            : Rect.fromLTWH(x0, top, w, barH);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(part(f.lagHp), Radius.circular(barH / 2)),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      final fill = part(f.shownHp);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, Radius.circular(barH / 2)),
        Paint()
          ..shader = LinearGradient(
            colors: [f.color, Color.lerp(f.color, Colors.white, 0.35)!],
          ).createShader(track),
      );

      final name = TextPainter(
        text: TextSpan(
          text: f.name,
          style: TextStyle(
            color: f.color,
            fontSize: math.max(8, size.height * 0.085),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      name.paint(
        canvas,
        Offset(left ? x0 : x0 + barW - name.width, top + barH + 2),
      );
    }
  }

  void _callout(Canvas canvas, Size size) {
    final text = sim.callout;
    if (text == null) return;
    final t = sim.calloutT;
    final pop = t < 0.15 ? 1.6 - 0.6 * Curves.easeOut.transform(t / 0.15) : 1.0;
    final fade = (1 - (t - (sim.calloutDur - 0.25)) / 0.25).clamp(0.0, 1.0);
    final ko = text == 'K.O.';
    final finish = text == 'FATALITY' || text == 'ANIMALITY';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size.height * (ko ? 0.30 : (finish ? 0.24 : 0.22)),
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color:
              (ko || text == 'FATALITY'
                      ? const Color(0xFFFF5A3D)
                      : (text == 'ANIMALITY'
                            ? const Color(0xFFFFC145)
                            : Colors.white))
                  .withValues(alpha: fade),
          shadows: [
            Shadow(
              color: (ko ? const Color(0xFFFF2E2E) : const Color(0xFF8B7BFF))
                  .withValues(alpha: 0.8 * fade),
              blurRadius: 14,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.42);
    canvas.scale(pop);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FightPainter oldDelegate) =>
      oldDelegate.sim != sim || oldDelegate.arena != arena;
}

/// Forward kinematics for a [_Pose], with the lowest foot planted on the
/// ground (y = 0) unless the pose lifts off.
class _Joints {
  _Joints._(
    this.lean,
    this.hip,
    this.shoulder,
    this.head,
    this.elbowB,
    this.handB,
    this.elbowF,
    this.handF,
    this.kneeB,
    this.footB,
    this.kneeF,
    this.footF,
  );

  final double lean;
  final Offset hip,
      shoulder,
      head,
      elbowB,
      handB,
      elbowF,
      handF,
      kneeB,
      footB,
      kneeF,
      footF;

  static Offset _seg(Offset from, double angle, double len) =>
      from + Offset(math.sin(angle) * len, math.cos(angle) * len);

  static _Joints solve(_Pose p) {
    var hip = const Offset(0, -48);
    final up = Offset(math.sin(p.lean), -math.cos(p.lean));
    var kneeB = _seg(hip, p.hB, 25);
    var footB = _seg(kneeB, p.hB + p.kB, 24);
    var kneeF = _seg(hip, p.hF, 25);
    var footF = _seg(kneeF, p.hF + p.kF, 24);

    // Plant the lowest foot, then apply any jump lift.
    final drop = -math.max(footB.dy, footF.dy) - p.lift;
    final shift = Offset(0, drop);
    hip += shift;
    kneeB += shift;
    footB += shift;
    kneeF += shift;
    footF += shift;

    final shoulder = hip + up * 29;
    final head = hip + up * 40;
    final elbowB = _seg(shoulder, p.sB, 17);
    final handB = _seg(elbowB, p.sB + p.eB, 16);
    final elbowF = _seg(shoulder, p.sF, 17);
    final handF = _seg(elbowF, p.sF + p.eF, 16);
    return _Joints._(
      p.lean,
      hip,
      shoulder,
      head,
      elbowB,
      handB,
      elbowF,
      handF,
      kneeB,
      footB,
      kneeF,
      footF,
    );
  }
}

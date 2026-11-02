import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'coastal_traffic.dart';
import 'elemental_fight.dart';
import 'glass_panel.dart';

/// Countdown strip for a not-yet-released game. Purely decorative — ticks
/// locally once a second and never touches session data or Supabase.
class UpcomingGameCountdown extends StatefulWidget {
  UpcomingGameCountdown({
    super.key,
    this.title = 'Grand Theft Auto VI',
    this.icon = Icons.local_police,
    DateTime? releaseDate,
  }) : releaseDate = releaseDate ?? DateTime(2026, 11, 18);

  final String title;
  final IconData icon;
  final DateTime releaseDate;

  @override
  State<UpcomingGameCountdown> createState() => _UpcomingGameCountdownState();
}

class _UpcomingGameCountdownState extends State<UpcomingGameCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.releaseDate.difference(DateTime.now());
    final released = remaining.isNegative;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        // Wide cards stage the fight on the shoreline itself; narrower ones
        // give it an arena row underneath, still inside this card.
        final fightInScene = constraints.maxWidth >= 1100;

        final badge = PillTag(
          label: released ? 'OUT NOW' : 'COMING SOON',
          color: AppColors.theatre,
          icon: released ? Icons.bolt_rounded : Icons.hourglass_top_rounded,
          compact: isNarrow,
        );

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: isNarrow ? 18 : 24,
                ),
                const SizedBox(width: 8),
                // Shrinks rather than truncating, so the full name always
                // shows on phones.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: isNarrow ? 16 : 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                        shadows: softGlow(AppColors.sunsetOrange),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Release · ${_formatDate(widget.releaseDate)}',
              style: TextStyle(
                fontSize: isNarrow ? 10.5 : 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        );

        final countdown = released
            ? Text(
                'Available now',
                style: TextStyle(
                  fontSize: isNarrow ? 15 : 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: softGlow(AppColors.theatre),
                ),
              )
            : _SegmentedCountdown(remaining: remaining, compact: isNarrow);

        return GlassPanel(
          accent: AppColors.sunsetOrange,
          glow: 0.5,
          borderAlpha: 0.25,
          radius: 20,
          padding: EdgeInsets.zero,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1030), Color(0xFF2A1B4A), Color(0xFF5A2E4A)],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: panelShape(20)),
            child: fightInScene
                ? _scene(
                    constraints.maxWidth,
                    isNarrow,
                    badge,
                    titleBlock,
                    countdown,
                    fightInScene,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _scene(
                        constraints.maxWidth,
                        isNarrow,
                        badge,
                        titleBlock,
                        countdown,
                        fightInScene,
                      ),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.sunsetOrange.withValues(alpha: 0),
                              AppColors.sunsetOrange.withValues(alpha: 0.35),
                              AppColors.auroraCyan.withValues(alpha: 0.35),
                              AppColors.auroraCyan.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      ElementalFight(height: isNarrow ? 112 : 104),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// The sunset key art with the title and countdown laid over it, and —
  /// on wide cards — the fight staged on the shoreline between them.
  Widget _scene(
    double width,
    bool isNarrow,
    Widget badge,
    Widget titleBlock,
    Widget countdown,
    bool fightInScene,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _SunsetPainter(compact: isNarrow)),
        ),
        const Positioned.fill(
          child: CoastalTraffic(roadTopFrac: _SunsetPainter.roadFrac),
        ),
        if (fightInScene)
          Positioned(
            left: width * 0.30,
            width: width * 0.32,
            top: 0,
            bottom: 0,
            child: const ElementalFight(
              arena: false,
              groundFrac: _SunsetPainter.horizonFrac,
              figureFrac: 0.52,
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 20,
            // A taller card on wide screens gives the shoreline fight
            // and the road traffic room to read.
            vertical: fightInScene ? 28 : (isNarrow ? 12 : 18),
          ),
          // Mobile keeps the badge/title and countdown on separate
          // lines so neither gets cramped or clipped on narrow
          // screens; web/tablet keeps everything on one row.
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        badge,
                        const SizedBox(width: 10),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    const SizedBox(height: 10),
                    countdown,
                  ],
                )
              : Row(
                  children: [
                    badge,
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    countdown,
                  ],
                ),
        ),
      ],
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// DAYS / HRS / MIN / SEC readout in lit digit boxes.
class _SegmentedCountdown extends StatelessWidget {
  const _SegmentedCountdown({required this.remaining, required this.compact});

  final Duration remaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final parts = [
      ('DAYS', remaining.inDays.toString().padLeft(2, '0')),
      ('HRS', two(remaining.inHours.remainder(24))),
      ('MIN', two(remaining.inMinutes.remainder(60))),
      ('SEC', two(remaining.inSeconds.remainder(60))),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: compact ? 18 : 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          _DigitBox(label: parts[i].$1, value: parts[i].$2, compact: compact),
        ],
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 52 : 64,
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        shape: panelShape(
          12,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: softGlow(AppColors.sunsetOrange),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dusk key art: a glowing sun low over the water, a city skyline with lit
/// windows, and palm silhouettes. Static, so it paints once.
class _SunsetPainter extends CustomPainter {
  const _SunsetPainter({required this.compact});

  /// Phones stack the countdown under the title, so the scene moves to the
  /// far right and the scrim widens to keep both lines readable.
  final bool compact;

  /// Shoreline height, shared with the fight so the fighters' feet land on it.
  static const horizonFrac = 0.80;

  /// Top of the coastal road, shared with [CoastalTraffic].
  static const roadFrac = 0.83;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * horizonFrac;

    // Sun, set right of centre so it sits behind the countdown rather than
    // the title, with a wide halo.
    final sunC = Offset(w * (compact ? 0.86 : 0.64), horizon + h * 0.08);
    final sunR = h * (compact ? 0.38 : 0.55);
    canvas.drawCircle(
      sunC,
      sunR * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sunsetOrange.withValues(alpha: 0.40),
            const Color(0xFFFF6FA8).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: sunC, radius: sunR * 3.2)),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, horizon));
    canvas.drawCircle(
      sunC,
      sunR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE3A3), AppColors.sunsetOrange],
        ).createShader(Rect.fromCircle(center: sunC, radius: sunR)),
    );
    canvas.restore();

    _skyline(canvas, size, horizon);

    // Water, with the sun's reflection as a few soft shimmering strokes.
    final water = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1B45), Color(0xFF0E1230)],
        ).createShader(water),
    );
    final shimmer = Paint()
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final roadTop = h * roadFrac;
    for (var i = 0; i < 2; i++) {
      final y = horizon + 2 + i * (roadTop - horizon) / 2;
      final half = sunR * (0.9 - i * 0.25);
      shimmer
        ..strokeWidth = 1.6
        ..color = AppColors.sunsetOrange.withValues(alpha: 0.55 - i * 0.1);
      canvas.drawLine(
        Offset(sunC.dx - half, y),
        Offset(sunC.dx + half, y),
        shimmer,
      );
    }

    // Coastal highway along the bottom edge: asphalt, a glowing kerb and
    // a dashed centre line for the traffic to run on.
    final road = Rect.fromLTRB(0, roadTop, w, h);
    canvas.drawRect(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2342), Color(0xFF16122A)],
        ).createShader(road),
    );
    canvas.drawLine(
      Offset(0, roadTop),
      Offset(w, roadTop),
      Paint()
        ..strokeWidth = 1.2
        ..color = AppColors.sunsetOrange.withValues(alpha: 0.45),
    );
    final dash = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.28);
    final laneY = roadTop + (h - roadTop) * 0.55;
    for (var x = 0.0; x < w; x += 22) {
      canvas.drawLine(Offset(x, laneY), Offset(x + 11, laneY), dash);
    }

    // Legibility scrim behind the title on the left.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF0B1030).withValues(alpha: 0.92),
            const Color(0xFF0B1030).withValues(alpha: 0.55),
            const Color(0xFF0B1030).withValues(alpha: 0.0),
            const Color(0xFF0B1030).withValues(alpha: 0.35),
          ],
          stops: compact ? const [0.0, 0.5, 0.8, 1] : const [0.0, 0.32, 0.6, 1],
        ).createShader(Offset.zero & size),
    );

    if (!compact) {
      _palm(canvas, Offset(w * 0.47, horizon + 2), h * 0.9, flip: false);
      _palm(canvas, Offset(w * 0.50, horizon + 2), h * 0.6, flip: true);
    }
    _palm(
      canvas,
      Offset(w * 0.99, horizon + 2),
      h * (compact ? 0.6 : 0.95),
      flip: true,
    );
  }

  /// A row of towers along the horizon with a sprinkle of lit windows.
  void _skyline(Canvas canvas, Size size, double horizon) {
    final w = size.width;
    final h = size.height;
    final r = math.Random(42);
    final tower = Paint()..color = const Color(0xFF150F2C);
    final lit = Paint()
      ..color = const Color(0xFFFFD58A).withValues(alpha: 0.55);
    var x = w * (compact ? 0.62 : 0.30);
    while (x < w) {
      final bw = 10 + r.nextDouble() * 22;
      final bh = h * (0.08 + r.nextDouble() * (compact ? 0.16 : 0.24));
      final rect = Rect.fromLTWH(x, horizon - bh, bw, bh);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        tower,
      );
      for (var wy = rect.top + 4; wy < rect.bottom - 3; wy += 5) {
        for (var wx = rect.left + 3; wx < rect.right - 3; wx += 5) {
          if (r.nextDouble() < 0.18) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 1.6, 1.6), lit);
          }
        }
      }
      x += bw + 2 + r.nextDouble() * 6;
    }
  }

  void _palm(Canvas canvas, Offset base, double height, {required bool flip}) {
    final dir = flip ? -1.0 : 1.0;
    final paint = Paint()
      ..color = const Color(0xFF0C0920)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final top = base + Offset(dir * height * 0.18, -height);

    // Trunk: a gentle curve.
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx + dir * height * 0.02,
          base.dy - height * 0.6,
          top.dx,
          top.dy,
        ),
      paint..strokeWidth = height * 0.04,
    );

    // Fronds drooping out from the crown.
    paint.strokeWidth = height * 0.028;
    const angles = [-2.6, -2.0, -1.3, -0.6, 0.0, 0.5];
    for (final a in angles) {
      final len = height * 0.42;
      final end =
          top +
          Offset(len * math.cos(a) * dir, len * math.sin(a) * 0.5 + len * 0.35);
      final ctrl = top + Offset(len * 0.5 * math.cos(a) * dir, -len * 0.25);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SunsetPainter oldDelegate) =>
      oldDelegate.compact != compact;
}

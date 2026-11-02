import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

/// Shared rifleman silhouette used by the banner gunner and the squad
/// battle, so every figure on the board is drawn the same way.
///
/// Figure units: the standing figure is 100 tall with its feet at the
/// origin, facing +x. Mirror the canvas to face the other way.
abstract final class SoldierFigure {
  /// Muzzle position for each pose, before recoil.
  static const standingMuzzle = Offset(50, -76);
  static const crouchingMuzzle = Offset(50, -54);

  /// How far a crouch lowers everything above the hips.
  static const _crouchDrop = 22.0;

  static Offset muzzleFor({required bool crouch}) =>
      crouch ? crouchingMuzzle : standingMuzzle;

  /// Paints the soldier in a single [color] so the same call can draw both
  /// the silhouette and its rim light.
  ///
  /// [breathe] is a small -1..1 sway; [recoil] is 1 right after a shot and
  /// eases back to 0.
  static void paint(
    Canvas canvas,
    Color color, {
    double breathe = 0,
    double recoil = 0,
    bool crouch = false,
  }) {
    final fill = Paint()..color = color;
    final limb = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 9.5;
    final kick = Curves.easeOut.transform(recoil.clamp(0.0, 1.0));

    if (crouch) {
      // Kneeling: front foot planted, rear knee down on the ground.
      canvas.drawPath(
        Path()
          ..moveTo(4, -26)
          ..lineTo(17, -20)
          ..lineTo(17, -3),
        limb,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-3, -26)
          ..lineTo(-8, -4)
          ..lineTo(-22, -3),
        limb,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, -5, 11, 5),
          const Radius.circular(2),
        ),
        fill,
      );
    } else {
      // A planted firing stance, front knee bent.
      canvas.drawPath(
        Path()
          ..moveTo(4, -47)
          ..lineTo(13, -25)
          ..lineTo(17, -3),
        limb,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-3, -47)
          ..lineTo(-9, -24)
          ..lineTo(-16, -3),
        limb,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, -5, 11, 5),
          const Radius.circular(2),
        ),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-21, -5, 10, 5),
          const Radius.circular(2),
        ),
        fill,
      );
    }

    // Everything above the hips leans with the breath and rocks back on
    // recoil, pivoting at the waist.
    canvas.save();
    if (crouch) canvas.translate(0, _crouchDrop);
    canvas.translate(0, -48);
    canvas.rotate((-2.2 * kick + breathe * 0.3) * math.pi / 180);
    canvas.translate(-1.6 * kick, breathe * 0.4);
    canvas.translate(0, 48);

    // Pack.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -79, 10, 22),
        const Radius.circular(3),
      ),
      fill,
    );
    // Torso with a slight forward lean.
    canvas.drawPath(
      Path()
        ..moveTo(-7, -80)
        ..quadraticBezierTo(2, -83, 10, -79)
        ..lineTo(8, -50)
        ..lineTo(-7, -46)
        ..close(),
      fill,
    );
    // Neck and helmeted head, cheek down on the stock.
    canvas.drawRect(const Rect.fromLTWH(1, -84, 5, 6), fill);
    canvas.drawCircle(const Offset(5, -88), 6.2, fill);
    canvas.drawPath(
      Path()
        ..moveTo(-2.5, -88)
        ..quadraticBezierTo(-1, -97.5, 6, -97)
        ..quadraticBezierTo(13, -96, 13, -88)
        ..lineTo(14.5, -87)
        ..lineTo(-3, -86.5)
        ..close(),
      fill,
    );

    // Rifle, shouldered: stock, receiver, magazine, optic, barrel.
    canvas.drawPath(
      Path()
        ..moveTo(-3, -80)
        ..lineTo(4, -78.5)
        ..lineTo(34, -78.5)
        ..lineTo(34, -74)
        ..lineTo(8, -74)
        ..lineTo(-3, -71)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(18, -74.5)
        ..lineTo(23, -74.5)
        ..lineTo(25, -65)
        ..lineTo(20, -64.5)
        ..close(),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, -83, 11, 4),
        const Radius.circular(1.5),
      ),
      fill,
    );
    limb.strokeWidth = 2.2;
    canvas.drawLine(const Offset(33, -76.5), const Offset(50, -76.5), limb);

    // Arms: trigger hand on the grip, support hand on the handguard.
    limb.strokeWidth = 6.4;
    canvas.drawPath(
      Path()
        ..moveTo(0, -78)
        ..lineTo(-1, -67)
        ..lineTo(11, -72),
      limb,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8, -78)
        ..lineTo(19, -69)
        ..lineTo(30, -75),
      limb,
    );
    canvas.restore();
  }

  /// Four-point muzzle star with a warm bloom. [t] is 1 at the instant of
  /// the shot, fading to 0.
  static void paintFlash(
    Canvas canvas,
    Offset muzzle,
    double t,
    double scale,
    Color glow,
  ) {
    if (t <= 0) return;
    final s = scale * (0.6 + 0.4 * t);
    canvas.save();
    canvas.translate(muzzle.dx + 4 * s, muzzle.dy);
    canvas.drawCircle(
      Offset.zero,
      12 * s,
      Paint()
        ..color = glow.withValues(alpha: 0.55 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(14 * s, 0)
        ..lineTo(2 * s, 1.8 * s)
        ..lineTo(0, 6 * s)
        ..lineTo(-2 * s, 1.5 * s)
        ..lineTo(-4 * s, 0)
        ..lineTo(-2 * s, -1.5 * s)
        ..lineTo(0, -6 * s)
        ..lineTo(2 * s, -1.8 * s)
        ..close(),
      Paint()..color = const Color(0xFFFFF1C9).withValues(alpha: t),
    );
    canvas.restore();
  }
}

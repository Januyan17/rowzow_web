import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded shape shared by every panel, chip and pill on the board, so the
/// whole screen speaks one geometric language.
RoundedRectangleBorder panelShape(double radius, {BorderSide side = BorderSide.none}) =>
    RoundedRectangleBorder(
      side: side,
      borderRadius: BorderRadius.circular(radius),
    );

/// Frosted-glass card: a translucent fill that lets the backdrop's light
/// show through, a hairline border, and an optional soft accent glow.
///
/// No BackdropFilter blur — on a wall TV with a dozen tiles over an
/// animated background that would cost far more than it adds.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.accent = AppColors.auroraCyan,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.glow = 0.0,
    this.borderAlpha = 0.18,
    this.gradient,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 0 = no outer glow, 1 = full soft bloom.
  final double glow;
  final double borderAlpha;

  /// Replaces the default glass fill when set.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        gradient: gradient ?? glassFill(accent),
        shape: panelShape(
          radius,
          side: BorderSide(color: Color.lerp(Colors.white, accent, 0.5)!.withValues(alpha: borderAlpha)),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          if (glow > 0)
            BoxShadow(
              color: accent.withValues(alpha: 0.18 * glow),
              blurRadius: 32 * glow,
            ),
        ],
      ),
      child: child,
    );
  }
}

/// The standard glass fill: a faint accent tint top-left fading into a
/// translucent dark body.
LinearGradient glassFill(Color accent, {double tint = 0.10, double body = 0.55}) =>
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          accent.withValues(alpha: tint),
          AppColors.cardBackground.withValues(alpha: body + 0.15),
        ),
        AppColors.cardBackground.withValues(alpha: body),
      ],
    );

/// Small uppercase pill used for "POPULAR", "COMING SOON" and similar
/// banner labels.
class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: panelShape(20, side: BorderSide(color: color.withValues(alpha: 0.35))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gentle light bloom behind figures and titles — enough to feel lit,
/// never enough to smear.
List<Shadow> softGlow(Color color, {double strength = 1}) => [
  Shadow(color: color.withValues(alpha: 0.35 * strength), blurRadius: 16),
];

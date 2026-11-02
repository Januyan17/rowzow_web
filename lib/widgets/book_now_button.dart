import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';

/// "Book Now" call to action.
///
/// Opens [AppConfig.bookingUrl] in a *new* browser tab, so the board itself
/// never navigates away: a TV left on this page keeps showing live sessions
/// after someone taps the button, and a phone visitor can flip back to the
/// board without losing the booking page.
class BookNowButton extends StatelessWidget {
  const BookNowButton({super.key, this.expand = false, this.onPressed});

  /// Stretches the button across its parent (the mobile header) instead of
  /// hugging its label (the desktop header).
  final bool expand;

  /// Test seam: replaces the real browser navigation.
  final VoidCallback? onPressed;

  static Future<void> _openBookingSite() async {
    final uri = Uri.tryParse(AppConfig.bookingUrl);
    if (uri == null || uri.toString().isEmpty) return;
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      // The name that makes the browser use a new tab rather than replacing
      // the board in the current one.
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final shape = panelShape(24);
    final button = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: const LinearGradient(
          colors: [AppColors.ps5, AppColors.auroraViolet],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        shadows: [
          BoxShadow(
            color: AppColors.ps5.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _Shimmer(
        shape: shape,
        child: Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed ?? _openBookingSite,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.sports_esports_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Book Now',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      link: true,
      label: 'Book Now — opens the booking site in a new tab',
      child: Tooltip(
        message: 'Opens ${AppConfig.bookingUrl} in a new tab',
        child: expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }
}

/// A highlight that sweeps across the button every few seconds, so the call
/// to action catches the eye on a wall screen without flashing.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child, required this.shape});

  final Widget child;
  final ShapeBorder shape;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
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
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: widget.shape),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Sweep during the first 40% of the cycle, rest after.
                  final t = (_controller.value / 0.4).clamp(0.0, 1.0);
                  return FractionalTranslation(
                    translation: Offset(-1.2 + t * 2.4, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

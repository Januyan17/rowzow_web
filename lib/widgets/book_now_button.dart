import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

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
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.ps5, AppColors.vr],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ps5.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed ?? _openBookingSite,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.event_available_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
              ],
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

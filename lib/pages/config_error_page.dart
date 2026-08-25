import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Shown instead of the board when the build carries no Supabase
/// credentials, so the failure names its own cause rather than looking like
/// a dropped connection.
class ConfigErrorPage extends StatelessWidget {
  const ConfigErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (AppConfig.supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (AppConfig.supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.background),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.overtime.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.settings_ethernet,
                      size: 40,
                      color: AppColors.overtime,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Supabase config missing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This build has no ${missing.join(' or ')}, so the board '
                    'has nothing to connect to.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Text(
                      'flutter run -d chrome \\\n'
                      '  --dart-define-from-file=env/qa.json',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

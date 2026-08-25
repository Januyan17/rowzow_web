import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'pages/config_error_page.dart';
import 'pages/tv_board_page.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  // Initializing with empty credentials "succeeds" and then quietly points
  // every request at the host serving the app, so check before connecting.
  if (!AppConfig.hasSupabaseConfig) {
    runApp(const RowzowApp(missingConfig: true));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    debug: AppConfig.debugLogEnabled,
  );

  runApp(const RowzowApp());
}

class RowzowApp extends StatelessWidget {
  const RowzowApp({super.key, this.missingConfig = false});

  final bool missingConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ps5,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      ),
      home: missingConfig ? const ConfigErrorPage() : const TvBoardPage(),
    );
  }
}

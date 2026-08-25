enum AppFlavor { dev, qa, prod }

/// Compile-time configuration, supplied via `--dart-define-from-file=env/<flavor>.json`.
class AppConfig {
  AppConfig._();

  static const String _flavorName = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'dev',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Rowzow Dev',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const bool debugLogEnabled = bool.fromEnvironment(
    'APP_DEBUG_LOG',
    defaultValue: true,
  );

  /// Whether the Supabase credentials were actually supplied at build time.
  ///
  /// `Supabase.initialize` accepts an empty URL without complaining, and the
  /// client then resolves requests against a relative path on whatever host
  /// serves the app — which surfaces on the board as a misleading "unable to
  /// load live sessions". Check this first so a missing `--dart-define`
  /// reports itself as the config problem it is.
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static AppFlavor get flavor {
    switch (_flavorName) {
      case 'prod':
        return AppFlavor.prod;
      case 'qa':
        return AppFlavor.qa;
      default:
        return AppFlavor.dev;
    }
  }

  static bool get isProd => flavor == AppFlavor.prod;
}

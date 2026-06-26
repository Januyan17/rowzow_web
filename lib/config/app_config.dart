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

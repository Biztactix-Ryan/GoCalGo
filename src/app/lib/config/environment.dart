/// Build-time environment configuration.
///
/// Values are injected via `--dart-define-from-file` at build time:
/// ```
/// flutter run --dart-define-from-file=config/dev.env
/// flutter run --dart-define-from-file=config/prod.env
/// ```
class Environment {
  const Environment._();

  static const String name = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static bool get isDevelopment => name == 'development';
  static bool get isProduction => name == 'production';
}

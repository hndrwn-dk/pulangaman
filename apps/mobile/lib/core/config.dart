/// Runtime config. Override with `--dart-define=API_BASE_URL=...`.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:3000',
  );

  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// When true, login uses local `dev:<uid>` tokens (no Firebase).
  static const useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: true,
  );
}

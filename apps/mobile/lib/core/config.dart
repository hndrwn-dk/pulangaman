/// Runtime config. Override with `--dart-define=API_BASE_URL=...`.
///
/// Defaults target the Render cloud API. For local API on the Android emulator:
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3000`
/// `--dart-define=WS_BASE_URL=ws://10.0.2.2:3000`
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pulangaman-api.onrender.com',
  );

  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://pulangaman-api.onrender.com',
  );

  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// When true, login uses local `dev:<uid>` tokens (no Firebase).
  /// Default false — cloud API now verifies real Firebase ID tokens.
  /// Use `--dart-define=USE_DEV_AUTH=true` only against a local API without Firebase.
  static const useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: false,
  );
}

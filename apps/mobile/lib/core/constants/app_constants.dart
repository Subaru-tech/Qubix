/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Qubix';
  static const String appVersion = '1.0.0';
  static const String deepLinkScheme = 'qubix';

  /// Default server URL — overridden by user in server config screen.
  static const String defaultServerUrl = 'http://localhost:3000';

  /// SharedPreferences keys.
  static const String keyServerUrl = 'server_url';
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserDisplayName = 'user_display_name';
  static const String keyUserAvatar = 'user_avatar_url';
  static const String keyOnboardingComplete = 'onboarding_complete';

  /// API paths.
  static const String pathHealth = '/health';
  static const String pathRegister = '/auth/register';
  static const String pathLogin = '/auth/login';
  static const String pathMe = '/auth/me';
  static const String pathGithub = '/auth/github';
  static const String pathAgents = '/agents';
  static const String pathThreads = '/threads';

  /// WebSocket path.
  static const String pathWs = '/ws';

  /// Timeouts (milliseconds).
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 15000;
}

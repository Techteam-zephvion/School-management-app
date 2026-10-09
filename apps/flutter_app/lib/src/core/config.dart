class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

  static const neonAuthUrl = String.fromEnvironment(
    'NEON_AUTH_URL',
    defaultValue: '',
  );
}

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

  static const neonAuthUrl = String.fromEnvironment(
    'NEON_AUTH_URL',
    defaultValue: '',
  );

  static bool get isLocalDev =>
      apiBaseUrl.startsWith('http://localhost:') ||
      apiBaseUrl.startsWith('http://127.0.0.1:');

  static String get neonAuthBase {
    final trimmed = neonAuthUrl.endsWith('/')
        ? neonAuthUrl.substring(0, neonAuthUrl.length - 1)
        : neonAuthUrl;
    if (trimmed.isEmpty || trimmed.endsWith('/auth')) return trimmed;
    return '$trimmed/auth';
  }
}

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

  static const neonAuthUrl = String.fromEnvironment(
    'NEON_AUTH_URL',
    defaultValue: 'https://ep-polished-silence-b52ozwm7.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth',
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

  static bool get allowDevSignIn =>
      const bool.fromEnvironment('SCHOOLIC_ALLOW_DEV_SIGN_IN', defaultValue: true);
}

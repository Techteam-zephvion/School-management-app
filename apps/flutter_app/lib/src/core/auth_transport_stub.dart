import 'dart:convert';

import 'package:http/http.dart' as http;

final Map<String, String> _cookies = {};

void clearAuthCookies() {
  _cookies.clear();
}

Map<String, String> get currentAuthCookies => Map.unmodifiable(_cookies);

Future<Map<String, Object?>> postAuthJson(
  Uri uri,
  Map<String, Object?> body, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final response = await client.post(
    uri,
    headers: {
      'content-type': 'application/json',
      'origin': 'http://localhost:8080',
      if (_cookieHeader().isNotEmpty) 'cookie': _cookieHeader(),
    },
    body: jsonEncode(body),
  );
  _storeCookies(response);
  return _decode(response.statusCode, response.body);
}

Future<Map<String, Object?>> getAuthJson(
  Uri uri, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final response = await client.get(
    uri,
    headers: {
      'accept': 'application/json',
      'origin': 'http://localhost:8080',
      if (_cookieHeader().isNotEmpty) 'cookie': _cookieHeader(),
    },
  );
  _storeCookies(response);
  return _decode(response.statusCode, response.body);
}

Future<void> postAuth(Uri uri, {http.Client? httpClient}) async {
  final client = httpClient ?? http.Client();
  final response = await client.post(
    uri,
    headers: {
      'origin': 'http://localhost:8080',
      if (_cookieHeader().isNotEmpty) 'cookie': _cookieHeader(),
    },
  );
  _storeCookies(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw AuthTransportException(
      'Authentication request failed',
      response.statusCode,
    );
  }
  _cookies.clear();
}

Map<String, Object?> _decode(int statusCode, String body) {
  Map<String, Object?> decoded = const {};
  if (body.isNotEmpty) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        decoded = parsed.cast<String, Object?>();
      }
    } catch (_) {
      // Non-JSON response (e.g. gateway HTML error)
    }
  }

  if (statusCode >= 200 && statusCode < 300) {
    return decoded;
  }

  if (statusCode == 401) {
    final message = decoded['message'] as String? ?? decoded['error'] as String?;
    final code = decoded['code'] as String?;
    if (code == 'INVALID_EMAIL_OR_PASSWORD' ||
        (message != null && message.toLowerCase().contains('invalid email'))) {
      throw AuthTransportException('Invalid email or password.', statusCode);
    }
    throw AuthTransportException(
      message ?? 'Authentication failed. Please check your credentials.',
      statusCode,
    );
  }

  if (statusCode == 403) {
    final message = decoded['message'] as String? ?? decoded['error'] as String?;
    throw AuthTransportException(message ?? 'Access denied.', statusCode);
  }

  if (statusCode >= 500) {
    throw AuthTransportException(
      'Authentication service is currently unavailable. Please try again later.',
      statusCode,
    );
  }

  final fallback = decoded['error'] as String? ??
      decoded['message'] as String? ??
      'Authentication request failed ($statusCode)';
  throw AuthTransportException(fallback, statusCode);
}

const Set<String> _cookieAttributes = {
  'expires',
  'max-age',
  'path',
  'domain',
  'samesite',
  'secure',
  'httponly',
  'partitioned',
};

void _storeCookies(http.Response response) {
  final header = response.headers['set-cookie'];
  if (header == null || header.isEmpty) return;

  for (final cookie in header.split(',')) {
    final firstPart = cookie.split(';').first.trim();
    final separatorIndex = firstPart.indexOf('=');
    if (separatorIndex <= 0) continue;
    final key = firstPart.substring(0, separatorIndex).trim();
    if (_cookieAttributes.contains(key.toLowerCase())) continue;
    _cookies[key] = firstPart.substring(separatorIndex + 1).trim();
  }
}

String _cookieHeader() {
  return _cookies.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join('; ');
}

class AuthTransportException implements Exception {
  AuthTransportException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

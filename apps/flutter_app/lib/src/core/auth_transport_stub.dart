import 'dart:convert';

import 'package:http/http.dart' as http;

final Map<String, String> _cookies = {};

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
    headers: {if (_cookieHeader().isNotEmpty) 'cookie': _cookieHeader()},
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
  final decoded = body.isEmpty
      ? <String, Object?>{}
      : (jsonDecode(body) as Map).cast<String, Object?>();
  if (statusCode < 200 || statusCode >= 300) {
    throw AuthTransportException(
      decoded['error'] as String? ??
          decoded['message'] as String? ??
          'Authentication request failed',
      statusCode,
    );
  }
  return decoded;
}

void _storeCookies(http.Response response) {
  final header = response.headers['set-cookie'];
  if (header == null || header.isEmpty) return;

  for (final cookie in header.split(',')) {
    final firstPart = cookie.split(';').first.trim();
    final separatorIndex = firstPart.indexOf('=');
    if (separatorIndex <= 0) continue;
    _cookies[firstPart.substring(0, separatorIndex)] = firstPart.substring(
      separatorIndex + 1,
    );
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
}

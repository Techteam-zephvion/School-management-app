import 'dart:convert';

import 'package:http/http.dart' as http;

Future<Map<String, Object?>> postAuthJson(
  Uri uri,
  Map<String, Object?> body, {
  http.Client? httpClient,
}) async {
  final client = httpClient ?? http.Client();
  final response = await client.post(
    uri,
    headers: {'content-type': 'application/json'},
    body: jsonEncode(body),
  );
  return _decode(response.statusCode, response.body);
}

Future<Map<String, Object?>> getAuthJson(Uri uri, {http.Client? httpClient}) async {
  final client = httpClient ?? http.Client();
  final response = await client.get(uri, headers: {'accept': 'application/json'});
  return _decode(response.statusCode, response.body);
}

Future<void> postAuth(Uri uri, {http.Client? httpClient}) async {
  final client = httpClient ?? http.Client();
  final response = await client.post(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw AuthTransportException('Authentication request failed', response.statusCode);
  }
}

Map<String, Object?> _decode(int statusCode, String body) {
  final decoded = body.isEmpty ? <String, Object?>{} : (jsonDecode(body) as Map).cast<String, Object?>();
  if (statusCode < 200 || statusCode >= 300) {
    throw AuthTransportException(
      decoded['error'] as String? ?? decoded['message'] as String? ?? 'Authentication request failed',
      statusCode,
    );
  }
  return decoded;
}

class AuthTransportException implements Exception {
  AuthTransportException(this.message, this.statusCode);

  final String message;
  final int statusCode;
}

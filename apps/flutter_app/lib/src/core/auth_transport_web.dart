// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html';

import 'package:http/http.dart' as http;

Future<Map<String, Object?>> postAuthJson(
  Uri uri,
  Map<String, Object?> body, {
  http.Client? httpClient,
}) async {
  final request = await HttpRequest.request(
    uri.toString(),
    method: 'POST',
    requestHeaders: {'content-type': 'application/json'},
    sendData: jsonEncode(body),
    withCredentials: true,
  );
  return _decode(request.status ?? 0, request.responseText ?? '');
}

Future<Map<String, Object?>> getAuthJson(Uri uri, {http.Client? httpClient}) async {
  final request = await HttpRequest.request(
    uri.toString(),
    method: 'GET',
    requestHeaders: {'accept': 'application/json'},
    withCredentials: true,
  );
  return _decode(request.status ?? 0, request.responseText ?? '');
}

Future<void> postAuth(Uri uri, {http.Client? httpClient}) async {
  final request = await HttpRequest.request(
    uri.toString(),
    method: 'POST',
    withCredentials: true,
  );
  final status = request.status ?? 0;
  if (status < 200 || status >= 300) {
    throw AuthTransportException('Authentication request failed', status);
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

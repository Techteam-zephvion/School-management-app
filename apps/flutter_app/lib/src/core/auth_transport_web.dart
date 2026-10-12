// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html';

import 'package:http/http.dart' as http;

void clearAuthCookies() {
  // Browser manages cookie store automatically
}

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
  Map<String, Object?> decoded = const {};
  if (body.isNotEmpty) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        decoded = parsed.cast<String, Object?>();
      }
    } catch (_) {
      // Non-JSON response
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

class AuthTransportException implements Exception {
  AuthTransportException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

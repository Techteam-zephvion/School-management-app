import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_transport.dart' as auth_transport;
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<AuthSession> signInWithNeon({
    required String email,
    required String password,
  }) async {
    if (AppConfig.neonAuthUrl.isEmpty) {
      throw ApiException('NEON_AUTH_URL is not configured for this build.', 400);
    }

    final Map<String, Object?> tokenResponse;
    try {
      await auth_transport.postAuthJson(
        Uri.parse('${AppConfig.neonAuthBase}/sign-in/email'),
        {'email': email, 'password': password},
        httpClient: _httpClient,
      );

      tokenResponse = await auth_transport.getAuthJson(
        Uri.parse('${AppConfig.neonAuthBase}/token'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException catch (exception) {
      throw ApiException(exception.message, exception.statusCode);
    }
    final token = tokenResponse['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication token was not issued.', 401);
    }
    return currentUser(bearerToken: token);
  }

  Future<void> signOutWithNeon() async {
    if (AppConfig.neonAuthUrl.isEmpty) return;
    try {
      await auth_transport.postAuth(
        Uri.parse('${AppConfig.neonAuthBase}/sign-out'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException {
      // Local session cleanup should still proceed if the remote session is already gone.
    }
  }

  Future<AuthSession> currentUser({String? bearerToken, AuthSession? devSession}) async {
    final json = await getJson('/api/v1/me', bearerToken: bearerToken, devSession: devSession);
    return AuthSession(
      email: json['email'] as String,
      roles: ((json['roles'] as List?) ?? const [])
          .map((role) => AppRole.values.byName(role as String))
          .toList(),
      schoolId: json['schoolId'] as String,
      bearerToken: bearerToken,
      devNeonUserId: devSession?.devNeonUserId,
    );
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    String? bearerToken,
    AuthSession? devSession,
    AuthSession? session,
  }) async {
    final token = bearerToken ?? session?.bearerToken;
    final dev = devSession ?? (session?.devNeonUserId != null ? session : null);
    final response = await _httpClient.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(bearerToken: token, devSession: dev),
    );
    _ensureSuccess(response);
    return _decode(response);
  }

  Future<List<Map<String, Object?>>> getList(String path, {required AuthSession session}) async {
    final response = await _httpClient.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(bearerToken: session.bearerToken, devSession: session),
    );
    _ensureSuccess(response);
    return (_decodeList(response)).cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(bearerToken: session.bearerToken, devSession: session),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return _decode(response);
  }

  Future<Map<String, Object?>> putJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    final response = await _httpClient.put(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(bearerToken: session.bearerToken, devSession: session),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return _decode(response);
  }

  Future<Map<String, Object?>> deleteJson(String path, {required AuthSession session}) async {
    final response = await _httpClient.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(bearerToken: session.bearerToken, devSession: session),
    );
    _ensureSuccess(response);
    return _decode(response);
  }

  Map<String, String> _headers({String? bearerToken, AuthSession? devSession}) {
    return {
      'content-type': 'application/json',
      if (bearerToken != null) 'authorization': 'Bearer $bearerToken',
      if (devSession?.devNeonUserId != null) 'x-dev-neon-user-id': devSession!.devNeonUserId!,
      if (devSession?.devNeonUserId != null) 'x-dev-email': devSession!.email,
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.isEmpty ? <String, Object?>{} : _decode(response);
    throw ApiException(body['error'] as String? ?? 'Request failed', response.statusCode);
  }

  Map<String, Object?> _decode(http.Response response) {
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }

  List<Object?> _decodeList(http.Response response) {
    return (jsonDecode(response.body) as List).cast<Object?>();
  }
}

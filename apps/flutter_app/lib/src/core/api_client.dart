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
  ApiClient({
    http.Client? httpClient,
    this.neonAuthUrlOverride,
    this.apiBaseUrlOverride,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String? neonAuthUrlOverride;
  final String? apiBaseUrlOverride;

  String get neonAuthUrl => neonAuthUrlOverride ?? AppConfig.neonAuthUrl;
  String get apiBaseUrl => apiBaseUrlOverride ?? AppConfig.apiBaseUrl;

  String get neonAuthBase {
    final url = neonAuthUrl;
    final trimmed = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (trimmed.isEmpty || trimmed.endsWith('/auth')) return trimmed;
    return '$trimmed/auth';
  }

  Future<AuthSession> signInWithNeon({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ApiException('Email and password are required.', 400);
    }

    if (neonAuthUrl.isEmpty) {
      throw ApiException('NEON_AUTH_URL is not configured for this build.', 400);
    }

    auth_transport.clearAuthCookies();

    final Map<String, Object?> tokenResponse;
    try {
      await auth_transport.postAuthJson(
        Uri.parse('$neonAuthBase/sign-in/email'),
        {'email': normalizedEmail, 'password': password},
        httpClient: _httpClient,
      );

      tokenResponse = await auth_transport.getAuthJson(
        Uri.parse('$neonAuthBase/token'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException catch (exception) {
      throw ApiException(exception.message, exception.statusCode);
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      if (exception is ApiException) rethrow;
      throw ApiException('Unable to connect to authentication service. Please check your network.', 503);
    }

    final token = tokenResponse['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication token was not issued.', 401);
    }
    return currentUser(bearerToken: token);
  }

  Future<void> signOutWithNeon() async {
    if (neonAuthUrl.isEmpty) return;
    try {
      await auth_transport.postAuth(
        Uri.parse('$neonAuthBase/sign-out'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException {
      // Local session cleanup should still proceed if the remote session is already gone.
    } catch (_) {
      // Ignore network errors during sign-out
    } finally {
      auth_transport.clearAuthCookies();
    }
  }

  Future<AuthSession> currentUser({String? bearerToken, AuthSession? devSession}) async {
    final json = await getJson('/api/v1/me', bearerToken: bearerToken, devSession: devSession);
    return AuthSession(
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
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
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: token, devSession: dev),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<List<Map<String, Object?>>> getList(String path, {required AuthSession session}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: session.bearerToken, devSession: session),
      );
      _ensureSuccess(response);
      return (_decodeList(response)).cast<Map<String, Object?>>();
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: session.bearerToken, devSession: session),
        body: jsonEncode(body),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> putJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: session.bearerToken, devSession: session),
        body: jsonEncode(body),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> patchJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _httpClient.patch(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: session.bearerToken, devSession: session),
        body: jsonEncode(body),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> deleteJson(String path, {required AuthSession session}) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$apiBaseUrl$path'),
        headers: _headers(bearerToken: session.bearerToken, devSession: session),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
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
    String errorMessage = 'Request failed (${response.statusCode})';
    if (response.body.isNotEmpty) {
      try {
        final body = _decode(response);
        if (body['error'] is String) {
          errorMessage = body['error'] as String;
        } else if (body['message'] is String) {
          errorMessage = body['message'] as String;
        }
      } catch (_) {
        // Non-JSON response
      }
    }
    if (response.statusCode >= 500) {
      errorMessage = 'Schoolic service is currently unavailable. Please try again later.';
    }
    throw ApiException(errorMessage, response.statusCode);
  }

  Map<String, Object?> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map) return parsed.cast<String, Object?>();
    } catch (_) {}
    return const {};
  }

  List<Object?> _decodeList(http.Response response) {
    if (response.body.isEmpty) return const [];
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is List) return parsed.cast<Object?>();
    } catch (_) {}
    return const [];
  }
}

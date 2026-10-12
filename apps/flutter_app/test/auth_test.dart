import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/auth_transport.dart' as auth_transport;
import 'package:schoolic/src/core/models.dart';

void main() {
  const testAuthUrl = 'https://auth.example.test/neondb';
  const testApiUrl = 'https://api.example.test';

  group('Auth Request Construction & Config', () {
    test('neonAuthBase formats URLs correctly', () {
      final client = ApiClient(neonAuthUrlOverride: 'https://auth.example.test/neondb');
      expect(client.neonAuthBase, 'https://auth.example.test/neondb/auth');

      final clientAlreadyAuth = ApiClient(neonAuthUrlOverride: 'https://auth.example.test/neondb/auth');
      expect(clientAlreadyAuth.neonAuthBase, 'https://auth.example.test/neondb/auth');

      final clientTrailingSlash = ApiClient(neonAuthUrlOverride: 'https://auth.example.test/neondb/');
      expect(clientTrailingSlash.neonAuthBase, 'https://auth.example.test/neondb/auth');
    });

    test('signInWithNeon validates empty email or password locally', () async {
      final client = ApiClient(neonAuthUrlOverride: testAuthUrl);
      expect(
        () => client.signInWithNeon(email: '', password: 'secret'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Email and password are required'),
        )),
      );
      expect(
        () => client.signInWithNeon(email: 'user@test.com', password: ''),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Email and password are required'),
        )),
      );
    });

    test('fails if neonAuthUrl is empty', () async {
      final client = ApiClient(neonAuthUrlOverride: '');
      expect(
        () => client.signInWithNeon(email: 'user@test.com', password: 'secret'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('NEON_AUTH_URL is not configured'),
        )),
      );
    });
  });

  group('Auth Response & Error Handling', () {
    test('401 with INVALID_EMAIL_OR_PASSWORD yields user-friendly error', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/sign-in/email')) {
          return http.Response(
            jsonEncode({
              'message': 'Invalid email or password',
              'code': 'INVALID_EMAIL_OR_PASSWORD',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final client = ApiClient(
        httpClient: mock,
        neonAuthUrlOverride: testAuthUrl,
        apiBaseUrlOverride: testApiUrl,
      );
      expect(
        () => client.signInWithNeon(email: 'user@schoolic.edu', password: 'wrong'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Invalid email or password.')),
      );
    });

    test('403 unprovisioned pilot error is preserved and not disguised as bad credentials', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/sign-in/email')) {
          return http.Response(
            jsonEncode({'redirect': false, 'token': 'session-123'}),
            200,
            headers: {
              'content-type': 'application/json',
              'set-cookie': '__Secure-neon-auth.session_token=session-123; Path=/; Secure; HttpOnly',
            },
          );
        }
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({'token': 'jwt-token-xyz'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/api/v1/me')) {
          return http.Response(
            jsonEncode({'error': 'User is not provisioned for this pilot'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final client = ApiClient(
        httpClient: mock,
        neonAuthUrlOverride: testAuthUrl,
        apiBaseUrlOverride: testApiUrl,
      );
      expect(
        () => client.signInWithNeon(email: 'valid@schoolic.edu', password: 'correct'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'User is not provisioned for this pilot')),
      );
    });

    test('500 / 502 HTML server errors do not throw FormatException and return service unavailable', () async {
      final mock = MockClient((request) async {
        return http.Response(
          '<html><body>502 Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      final client = ApiClient(
        httpClient: mock,
        neonAuthUrlOverride: testAuthUrl,
        apiBaseUrlOverride: testApiUrl,
      );
      expect(
        () => client.signInWithNeon(email: 'user@schoolic.edu', password: 'secret'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.message, 'message', contains('Authentication service is currently unavailable'))),
      );
    });

    test('Network failure throws clean ApiException with 503 status', () async {
      final mock = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final client = ApiClient(
        httpClient: mock,
        neonAuthUrlOverride: testAuthUrl,
        apiBaseUrlOverride: testApiUrl,
      );
      expect(
        () => client.signInWithNeon(email: 'user@schoolic.edu', password: 'secret'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.message, 'message', contains('Network connection error'))),
      );
    });

    test('Successful sign-in flow extracts cookie, retrieves token, and fetches user session', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/sign-in/email')) {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['email'], 'user@schoolic.edu');
          expect(body['password'], 'correct-password');
          return http.Response(
            jsonEncode({
              'redirect': false,
              'token': 'session-token-abc',
              'user': {'email': 'user@schoolic.edu', 'id': 'neon-user-1'},
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'set-cookie':
                  '__Secure-neon-auth.session_token=session-token-abc.signature; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Path=/; Secure; HttpOnly; SameSite=None; Partitioned',
            },
          );
        }
        if (request.url.path.endsWith('/token')) {
          expect(request.headers['cookie'], contains('__Secure-neon-auth.session_token=session-token-abc.signature'));
          expect(request.headers['cookie'], isNot(contains('Expires')));
          return http.Response(
            jsonEncode({'token': 'jwt-signed-token-123'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/api/v1/me')) {
          expect(request.headers['authorization'], 'Bearer jwt-signed-token-123');
          return http.Response(
            jsonEncode({
              'email': 'user@schoolic.edu',
              'displayName': 'Admin User',
              'roles': ['admin'],
              'schoolId': 'school-123',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final client = ApiClient(
        httpClient: mock,
        neonAuthUrlOverride: testAuthUrl,
        apiBaseUrlOverride: testApiUrl,
      );
      final session = await client.signInWithNeon(
        email: '  User@Schoolic.edu  ',
        password: 'correct-password',
      );

      expect(session.email, 'user@schoolic.edu');
      expect(session.displayName, 'Admin User');
      expect(session.roles, [AppRole.admin]);
      expect(session.schoolId, 'school-123');
      expect(session.bearerToken, 'jwt-signed-token-123');
    });

    test('clearAuthCookies purges session cookies', () {
      auth_transport.clearAuthCookies();
    });
  });
}

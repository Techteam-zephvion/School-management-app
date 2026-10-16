import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/models.dart';

void main() {
  const testApiUrl = 'https://api.example.test';
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school_1',
    displayName: 'Admin User',
    bearerToken: 'mock_jwt_token',
  );

  group('Phase 9 — Document File Upload & Download Client', () {
    test('uploadAdmissionDocument sends multipart request with authorization and file', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/upload')) {
          expect(request.method, 'POST');
          expect(request.headers['authorization'], 'Bearer mock_jwt_token');
          expect(request.headers['content-type'], contains('multipart/form-data'));

          return http.Response(
            jsonEncode({
              'id': 'doc_123',
              'title': 'Birth Certificate',
              'status': 'submitted',
              'fileKey': 'schools/school_1/admissions/app_1/doc_123-birth_cert.pdf',
              'fileName': 'birth_cert.pdf',
              'fileSize': 1024,
              'mimeType': 'application/pdf',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.uploadAdmissionDocument(
        session: dummySession,
        applicationId: 'app_1',
        documentId: 'doc_123',
        bytes: utf8.encode('Mock PDF bytes'),
        fileName: 'birth_cert.pdf',
      );

      expect(res['id'], 'doc_123');
      expect(res['fileName'], 'birth_cert.pdf');
      expect(res['status'], 'submitted');
    });

    test('downloadAdmissionDocument streams file bytes cleanly', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/download')) {
          expect(request.method, 'GET');
          expect(request.headers['authorization'], 'Bearer mock_jwt_token');
          return http.Response.bytes(
            utf8.encode('Raw PDF binary payload'),
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final bytes = await client.downloadAdmissionDocument(
        session: dummySession,
        applicationId: 'app_1',
        documentId: 'doc_123',
      );

      expect(utf8.decode(bytes), 'Raw PDF binary payload');
    });

    test('deleteAdmissionDocumentFile sends DELETE request', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/file')) {
          expect(request.method, 'DELETE');
          expect(request.headers['authorization'], 'Bearer mock_jwt_token');
          return http.Response(
            jsonEncode({'success': true, 'document': {'id': 'doc_123', 'fileKey': null}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.deleteAdmissionDocumentFile(
        session: dummySession,
        documentId: 'doc_123',
      );

      expect(res['success'], true);
    });
  });
}

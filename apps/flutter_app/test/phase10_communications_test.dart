import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/providers.dart';
import 'package:schoolic/src/core/theme.dart';
import 'package:schoolic/src/features/admin/views/admin_communications_view.dart';
import 'package:schoolic/src/features/teacher/views/teacher_messages_view.dart';

void main() {
  const testApiUrl = 'https://api.example.test';
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school_1',
    displayName: 'Admin User',
    bearerToken: 'mock_jwt_token',
  );

  group('Phase 10 — Bulk Importer & Onboarding API Client', () {
    test('previewBulkImport sends CSV content and parses preview response', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/imports/preview')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['entity'], 'students');
          return http.Response(
            jsonEncode({
              'entity': 'students',
              'totalRows': 1,
              'validRows': 1,
              'errorRows': 0,
              'errors': [],
              'preview': [{'fullName': 'Aarav Sharma', 'rollNumber': '101'}],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.previewBulkImport(
        session: dummySession,
        entity: 'students',
        csv: 'fullName,rollNumber\nAarav Sharma,101',
      );

      expect(res['totalRows'], 1);
      expect(res['validRows'], 1);
      expect((res['preview'] as List).length, 1);
    });

    test('runOnboardingWizard submits institutional structure', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/onboarding/wizard')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['schoolName'], 'Delhi Public School');
          return http.Response(
            jsonEncode({
              'success': true,
              'academicYear': {'id': 'ay_1', 'name': '2026-2027'},
              'classesCreated': 2,
              'sectionsCreated': 4,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.runOnboardingWizard(
        session: dummySession,
        schoolName: 'Delhi Public School',
        academicYearName: '2026-2027',
        startDate: '2026-04-01',
        endDate: '2027-03-31',
        classes: [
          {'name': 'Grade 1', 'sortOrder': 1, 'sections': ['A', 'B']},
          {'name': 'Grade 2', 'sortOrder': 2, 'sections': ['A', 'B']},
        ],
      );

      expect(res['success'], true);
      expect(res['classesCreated'], 2);
    });
  });

  group('Phase 10 — Notifications & Teacher Chat API Client', () {
    test('sendNotification dispatches alert and returns notification record', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/notifications/send')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['channel'], 'whatsapp');
          expect(body['title'], 'Absence Notice');
          return http.Response(
            jsonEncode({
              'notification': {
                'id': 'notif_1',
                'channel': 'whatsapp',
                'title': 'Absence Notice',
                'status': 'sent',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.sendNotification(
        session: dummySession,
        channel: 'whatsapp',
        title: 'Absence Notice',
        body: 'Aarav was absent today.',
        recipientPhone: '+919876543210',
      );

      expect(res['notification'], isNotNull);
      expect((res['notification'] as Map)['status'], 'sent');
    });

    test('getTeacherAvailability and updateTeacherAvailability operate cleanly', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/teacher/availability') {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': 'avail_1',
                'startTime': '09:00',
                'endTime': '16:30',
                'availableDays': '1,2,3,4,5',
                'autoReplyMessage': 'Thank you for reaching out.',
                'isEnabled': true,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['startTime'], '08:30');
            return http.Response(
              jsonEncode({
                'id': 'avail_1',
                'startTime': '08:30',
                'endTime': '16:30',
                'availableDays': '1,2,3,4,5',
                'autoReplyMessage': 'Updated auto reply',
                'isEnabled': true,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final getRes = await client.getTeacherAvailability(session: dummySession);
      expect(getRes['startTime'], '09:00');

      final putRes = await client.updateTeacherAvailability(
        session: dummySession,
        startTime: '08:30',
        endTime: '16:30',
        availableDays: '1,2,3,4,5',
        autoReplyMessage: 'Updated auto reply',
        isEnabled: true,
      );
      expect(putRes['startTime'], '08:30');
    });
  });

  group('Phase 10 — UI Views Rendering', () {
    testWidgets('AdminCommunicationsView renders tab buttons and audit trail', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/notifications')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'notif_1',
                'channel': 'whatsapp',
                'recipientPhone': '+919876543210',
                'title': 'Fee Reminder',
                'body': 'Due soon: 5000 INR',
                'status': 'sent',
                'createdAt': '2026-10-15T10:00:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/onboarding/status')) {
          return http.Response(
            jsonEncode({
              'isFullySetup': true,
              'academicYearCount': 1,
              'classCount': 5,
              'studentCount': 120,
              'staffCount': 10,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final testClient = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final authController = AuthController(testClient)..session = dummySession;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: const Scaffold(
              body: AdminCommunicationsView(
                years: [{'id': 'ay_1', 'name': '2026-2027'}],
                classes: [{'id': 'cls_1', 'name': 'Grade 10'}],
                sections: [{'id': 'sec_1', 'name': 'A'}],
                reload: _dummyReload,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Communications & Onboarding'), findsOneWidget);
      expect(find.text('Bulk Importer & Setup'), findsOneWidget);
      expect(find.text('Automated Notifications & Audit'), findsOneWidget);
      expect(find.text('Setup Wizard'), findsOneWidget);
    });

    testWidgets('TeacherMessagesView renders conversations list and availability tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/availability')) {
          return http.Response(
            jsonEncode({
              'startTime': '09:00',
              'endTime': '16:30',
              'availableDays': '1,2,3,4,5',
              'autoReplyMessage': 'Thank you for reaching out.',
              'isEnabled': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/chat/conversations')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'conv_1',
                'studentName': 'Aarav Sharma',
                'parentName': 'Rajesh Sharma',
                'subject': 'Math Progress Concern',
                'status': 'open',
                'lastMessageAt': '2026-10-15T12:00:00Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final testClient = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final authController = AuthController(testClient)..session = dummySession;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: const Scaffold(
              body: TeacherMessagesView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Parent-Teacher Messaging & Hours'), findsOneWidget);
      expect(find.textContaining('Parent Messages'), findsOneWidget);
      expect(find.text('Availability & Auto-Reply'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
    });
  });
}

Future<void> _dummyReload() async {}

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
import 'package:schoolic/src/features/admin/views/admin_operations_view.dart';

void main() {
  const testApiUrl = 'https://api.example.test';
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school_1',
    displayName: 'Admin User',
    bearerToken: 'mock_jwt_token',
  );

  group('Phase 12 — Operations ApiClient Methods', () {
    test('getStudentLeaves and reviewStudentLeave send valid requests', () async {
      final mockHttp = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/admin/leaves/students') {
          expect(request.url.queryParameters['status'], 'pending');
          return http.Response(
            jsonEncode([
              {
                'id': 'leave_1',
                'studentId': 'stud_1',
                'studentName': 'Aarav Gupta',
                'admissionNumber': 'ADM-101',
                'startDate': '2026-10-20',
                'endDate': '2026-10-22',
                'reason': 'Medical leave',
                'status': 'pending',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'PUT' && request.url.path == '/api/v1/admin/leaves/students/leave_1/status') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['status'], 'approved');
          expect(body['reviewerNotes'], 'Doctor certificate verified');
          return http.Response(
            jsonEncode({'id': 'leave_1', 'status': 'approved'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final leaves = await client.getStudentLeaves(session: dummySession, status: 'pending');
      expect(leaves.length, 1);
      expect(leaves.first['studentName'], 'Aarav Gupta');

      final updated = await client.reviewStudentLeave(
        session: dummySession,
        leaveId: 'leave_1',
        status: 'approved',
        reviewerNotes: 'Doctor certificate verified',
      );
      expect(updated['status'], 'approved');
    });

    test('Transport API methods create and retrieve routes & stops', () async {
      final mockHttp = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/admin/transport/routes') {
          return http.Response(
            jsonEncode([
              {
                'id': 'route_1',
                'routeNumber': 'R-01',
                'routeName': 'North Hub Corridor',
                'startPoint': 'Indiranagar',
                'endPoint': 'School Campus',
                'totalStops': 5,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && request.url.path == '/api/v1/admin/transport/stops') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stopName'], 'Domlur Junction');
          expect(body['monthlyFeeAmount'], 1500);
          return http.Response(
            jsonEncode({'id': 'stop_1', 'stopName': 'Domlur Junction'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final routes = await client.getTransportRoutes(session: dummySession);
      expect(routes.length, 1);
      expect(routes.first['routeNumber'], 'R-01');

      final stop = await client.createTransportStop(
        session: dummySession,
        routeId: 'route_1',
        stopName: 'Domlur Junction',
        pickupTime: '07:30',
        dropTime: '15:30',
        monthlyFeeAmount: 1500,
      );
      expect(stop['stopName'], 'Domlur Junction');
    });

    test('Certificates API generates verifiable serial numbers and revokes', () async {
      final mockHttp = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/certificates') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['certificateType'], 'transfer_certificate');
          return http.Response(
            jsonEncode({
              'id': 'cert_1',
              'certificateNumber': 'TC-2026-0001',
              'verificationCode': 'SCH-TC-XYZ987',
              'status': 'valid',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && request.url.path == '/api/v1/admin/certificates/cert_1/revoke') {
          return http.Response(
            jsonEncode({'id': 'cert_1', 'status': 'revoked'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final cert = await client.issueCertificate(
        session: dummySession,
        studentId: 'stud_1',
        certificateType: 'transfer_certificate',
      );
      expect(cert['certificateNumber'], 'TC-2026-0001');

      final revoked = await client.revokeCertificate(
        session: dummySession,
        certificateId: 'cert_1',
        reason: 'Issued with clerical error',
      );
      expect(revoked['status'], 'revoked');
    });
  });

  group('Phase 12 — AdminOperationsView UI & Widgets', () {
    testWidgets('AdminOperationsView renders page header, stats strip, and switches tabs cleanly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/admin/leaves/students')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'leave_1',
                'studentId': 'stud_1',
                'studentName': 'Sneha Rao',
                'admissionNumber': 'ADM-204',
                'startDate': '2026-10-18',
                'endDate': '2026-10-19',
                'reason': 'Family function',
                'status': 'pending',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/admin/leaves/staff')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'st_leave_1',
                'staffId': 'staff_1',
                'staffName': 'Dr. Sharma',
                'staffCode': 'TCH-005',
                'leaveType': 'casual',
                'startDate': '2026-10-22',
                'endDate': '2026-10-23',
                'reason': 'Personal work',
                'status': 'approved',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/admin/transport/routes')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/admin/certificates')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/admin/calendar')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/admin/ptm/schedules')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/admin/ptm/slots')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final testClient = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authControllerProvider.overrideWith(
              (ref) => AuthController(testClient)..session = dummySession,
            ),
          ],
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: const Scaffold(
              body: AdminOperationsView(
                students: [
                  {'id': 'stud_1', 'fullName': 'Sneha Rao', 'admissionNumber': 'ADM-204'}
                ],
                staff: [
                  {'id': 'staff_1', 'fullName': 'Dr. Sharma', 'staffCode': 'TCH-005'}
                ],
                classes: [],
                sections: [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('School Operations'), findsOneWidget);
      expect(find.text('PENDING STUDENT LEAVES'), findsOneWidget);
      expect(find.text('PENDING STAFF LEAVES'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Leaves & Substitutes'), findsOneWidget);
      expect(find.text('Transport Fleet'), findsOneWidget);
      expect(find.text('Official Certificates'), findsOneWidget);
      expect(find.text('Calendar & PTM'), findsOneWidget);

      // Verify Student Leave card in Default Leaves Tab
      expect(find.text('Sneha Rao'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Switch to Transport Tab
      await tester.tap(find.text('Transport Fleet'));
      await tester.pumpAndSettle();
      expect(find.text('No transport routes configured'), findsOneWidget);

      // Switch to Official Certificates Tab
      await tester.tap(find.text('Official Certificates'));
      await tester.pumpAndSettle();
      expect(find.text('No issued certificates found'), findsOneWidget);

      // Switch to Calendar & PTM Tab
      await tester.tap(find.text('Calendar & PTM'));
      await tester.pumpAndSettle();
      expect(find.text('Institutional Calendar Events'), findsOneWidget);
      expect(find.text('PTM Schedules & Slots'), findsOneWidget);
    });
  });
}

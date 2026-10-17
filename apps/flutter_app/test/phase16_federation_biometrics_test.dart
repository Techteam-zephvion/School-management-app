import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/providers.dart';
import 'package:schoolic/src/features/admin/views/admin_federation_view.dart';
import 'package:schoolic/src/features/shared/components/command_palette.dart';
import 'package:schoolic/src/features/shared/components/status_badge.dart';

void main() {
  const dummySession = AuthSession(
    email: 'chancellor@apexeducation.org',
    roles: [AppRole.admin],
    schoolId: 'school-1',
    displayName: 'Trust Chancellor',
    bearerToken: 'mock-token',
  );

  group('Phase 16: StatusBadge Extensions', () {
    testWidgets('StatusBadge.deviceStatus renders all statuses correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.deviceStatus('online'),
                StatusBadge.deviceStatus('offline'),
                StatusBadge.deviceStatus('maintenance'),
                StatusBadge.deviceStatus('decommissioned'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(find.text('DECOMMISSIONED'), findsOneWidget);
    });

    testWidgets('StatusBadge.transferStatus renders all statuses correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.transferStatus('pending'),
                StatusBadge.transferStatus('approved'),
                StatusBadge.transferStatus('rejected'),
                StatusBadge.transferStatus('completed'),
                StatusBadge.transferStatus('cancelled'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('StatusBadge.bloomLevel renders all 6 cognitive levels correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.bloomLevel('remember'),
                StatusBadge.bloomLevel('understand'),
                StatusBadge.bloomLevel('apply'),
                StatusBadge.bloomLevel('analyze'),
                StatusBadge.bloomLevel('evaluate'),
                StatusBadge.bloomLevel('create'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('REMEMBER'), findsOneWidget);
      expect(find.text('UNDERSTAND'), findsOneWidget);
      expect(find.text('APPLY'), findsOneWidget);
      expect(find.text('ANALYZE'), findsOneWidget);
      expect(find.text('EVALUATE'), findsOneWidget);
      expect(find.text('CREATE'), findsOneWidget);
    });

    testWidgets('StatusBadge.transcriptStatus renders all statuses correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.transcriptStatus('submitted'),
                StatusBadge.transcriptStatus('processing'),
                StatusBadge.transcriptStatus('ready'),
                StatusBadge.transcriptStatus('dispatched'),
                StatusBadge.transcriptStatus('rejected'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('PROCESSING'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('DISPATCHED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
    });
  });

  group('Phase 16: CommandPaletteDialog Federation Commands', () {
    testWidgets('renders federation navigation and quick actions', (tester) async {
      String? triggeredAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CommandPaletteDialog.show(
                  context,
                  onActionSelected: (action) => triggeredAction = action,
                ),
                child: const Text('Open Palette'),
              ),
            ),
          ),
        ),
      );

      // Open palette
      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      // Search for federation
      await tester.enterText(find.byType(TextField), 'federation');
      await tester.pumpAndSettle();

      expect(find.text('Multi-Campus Federation & Biometrics'), findsOneWidget);

      // Tap navigation
      await tester.tap(find.text('Multi-Campus Federation & Biometrics'));
      await tester.pumpAndSettle();

      expect(triggeredAction, 'nav:federation');
    });

    testWidgets('renders biometric devices quick action in command palette', (tester) async {
      String? triggeredAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CommandPaletteDialog.show(
                  context,
                  onActionSelected: (action) => triggeredAction = action,
                ),
                child: const Text('Open Palette'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'biometric');
      await tester.pumpAndSettle();

      expect(find.text('Sync Biometric Gate Attendance'), findsOneWidget);

      await tester.tap(find.text('Sync Biometric Gate Attendance'));
      await tester.pumpAndSettle();

      expect(triggeredAction, 'action:federation_biometrics');
    });
  });

  group('Phase 16: AdminFederationView UI & Tab Switching', () {
    testWidgets('renders 4 tabs, trust details, and switches tabs correctly', (tester) async {
      final mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/admin/federation/trusts') {
          return http.Response(
            jsonEncode([
              {
                'id': 'trust-1',
                'name': 'Apex Education Society',
                'trustCode': 'APEX-EDU',
                'registrationNumber': 'REG/2026/099',
                'headquartersAddress': 'Apex Towers, New Delhi',
                'chairmanName': 'Dr. S. K. Roy',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/federation/transfers') {
          return http.Response(
            jsonEncode([
              {
                'id': 'trans-1',
                'transferType': 'student',
                'sourceSchoolName': 'Apex Public School North',
                'targetSchoolName': 'Apex Public School South',
                'reason': 'Family relocation',
                'status': 'approved',
                'createdAt': '2026-10-17T10:00:00.000Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/biometrics/devices') {
          return http.Response(
            jsonEncode([
              {
                'id': 'dev-1',
                'name': 'Main Gate Turnstile A',
                'deviceCode': 'GATE-TURN-01',
                'deviceType': 'turnstile_rfid',
                'ipAddress': '192.168.1.101',
                'location': 'North Perimeter Gate',
                'status': 'online',
                'lastPingAt': '2026-10-17T11:55:00.000Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/biometrics/punches') {
          return http.Response(
            jsonEncode([
              {
                'id': 'p-1',
                'punchTimestamp': '2026-10-17T08:02:14.000Z',
                'punchType': 'in',
                'cardOrTokenNumber': 'RFID-101',
                'deviceName': 'Main Gate Turnstile A',
                'userType': 'student',
                'status': 'reconciled',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/obe/course-outcomes') {
          return http.Response(
            jsonEncode([
              {
                'id': 'co-1',
                'code': 'CO-101',
                'title': 'Quantum Physics Fundamentals',
                'description': 'Understand wave-particle duality and apply uncertainty principles.',
                'bloomLevel': 'understand',
                'targetAttainmentPercent': 80,
                'weightage': 25,
                'className': 'Class 12',
                'subjectName': 'Physics',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/obe/questions') {
          return http.Response(
            jsonEncode([
              {
                'id': 'eq-1',
                'questionText': 'Calculate the de Broglie wavelength for an electron accelerated through 100V.',
                'bloomLevel': 'apply',
                'questionType': 'numerical',
                'marks': 5,
                'className': 'Class 12',
                'subjectName': 'Physics',
                'coCode': 'CO-101',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/alumni/profiles') {
          return http.Response(
            jsonEncode([
              {
                'id': 'al-1',
                'fullName': 'Vikram Rathore',
                'email': 'vikram.rathore@techcorp.io',
                'graduationYear': 2022,
                'currentOrganization': 'TechCorp Systems',
                'designation': 'Senior Software Architect',
                'mentorshipAvailable': true,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/alumni/transcripts') {
          return http.Response(
            jsonEncode([
              {
                'id': 'tr-1',
                'requestNumber': 'TR-2026-0001',
                'alumniName': 'Riya Sharma',
                'documentType': 'official_transcript',
                'copies': 2,
                'status': 'processing',
                'createdAt': '2026-10-17T09:00:00.000Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/classes') {
          return http.Response(
            jsonEncode([
              {'id': 'c-1', 'name': 'Class 12'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/subjects') {
          return http.Response(
            jsonEncode([
              {'id': 's-1', 'name': 'Physics'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.startsWith('/api/v1/admin/federation/trusts/trust-1/campuses')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'school-1',
                'name': 'Apex Public School North',
                'code': 'APEX-N',
                'studentCount': 1250,
                'staffCount': 85,
              },
              {
                'id': 'school-2',
                'name': 'Apex Public School South',
                'code': 'APEX-S',
                'studentCount': 980,
                'staffCount': 62,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.startsWith('/api/v1/admin/federation/trusts/trust-1/stats')) {
          return http.Response(
            jsonEncode({
              'campusCount': 2,
              'totalStudents': 2230,
              'totalStaff': 147,
              'consolidatedRevenueCents': 125000000,
              'currency': 'INR',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
      });

      final testApiClient = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final authController = AuthController(testApiClient)..session = dummySession;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testApiClient),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminFederationView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check main page title and tabs
      expect(find.text('Multi-Campus Federation & Biometrics'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Trust & Campuses'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Biometrics & Turnstiles'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'OBE & Question Bank'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Alumni & Transcripts'), findsOneWidget);

      // Check trust data in Trust Federation tab
      expect(find.textContaining('Apex Education Society'), findsOneWidget);
      expect(find.text('Apex Public School North'), findsOneWidget);

      // Switch to Biometrics & Turnstiles tab
      await tester.tap(find.widgetWithText(Tab, 'Biometrics & Turnstiles'));
      await tester.pumpAndSettle();

      expect(find.text('Hardware Gate Readers & Turnstiles'), findsOneWidget);
      expect(find.text('Main Gate Turnstile A'), findsNWidgets(2));
      expect(find.text('RFID-101'), findsOneWidget);

      // Switch to OBE & Question Bank tab
      await tester.tap(find.widgetWithText(Tab, 'OBE & Question Bank'));
      await tester.pumpAndSettle();

      expect(find.text('Course Learning Outcomes (CO-PO Mapping)'), findsOneWidget);
      expect(find.text('CO-101'), findsOneWidget);
      expect(find.text('Understand wave-particle duality and apply uncertainty principles.'), findsOneWidget);
      expect(find.textContaining('Calculate the de Broglie wavelength'), findsOneWidget);

      // Switch to Alumni & Transcripts tab
      await tester.tap(find.widgetWithText(Tab, 'Alumni & Transcripts'));
      await tester.pumpAndSettle();

      expect(find.text('Alumni Directory & Mentorship Network'), findsOneWidget);
      expect(find.text('Vikram Rathore'), findsOneWidget);
      expect(find.text('TR-2026-0001'), findsOneWidget);
      expect(find.text('Riya Sharma'), findsOneWidget);
    });
  });

  group('Phase 16: ApiClient Federation Methods', () {
    test('fetches and creates educational trusts and campus transfers', () async {
      final mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (request.method == 'GET' && path == '/api/v1/admin/federation/trusts') {
          return http.Response(
            jsonEncode([{'id': 'trust-1', 'name': 'Apex Education Society'}]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && path == '/api/v1/admin/federation/trusts') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'id': 'trust-2', ...body}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && path == '/api/v1/admin/federation/transfers') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'id': 'trans-1', ...body, 'status': 'pending'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'PUT' && path == '/api/v1/admin/federation/transfers/trans-1/status') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'id': 'trans-1', 'status': body['status']}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && path == '/api/v1/admin/biometrics/devices/dev-1/heartbeat') {
          return http.Response(
            jsonEncode({'id': 'dev-1', 'status': 'online'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && path == '/api/v1/admin/biometrics/punches/reconcile') {
          return http.Response(
            jsonEncode({'success': true, 'reconciledCount': 42}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST' && path == '/api/v1/admin/obe/blueprint/generate') {
          return http.Response(
            jsonEncode({
              'paperTitle': 'Physics Midterm Exam',
              'totalMarks': 50,
              'questionCount': 10,
              'questions': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'PUT' && path == '/api/v1/admin/alumni/transcripts/tr-1/status') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'id': 'tr-1', 'status': body['status']}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(jsonEncode({}), 200, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');

      // Test Trust APIs
      final trusts = await client.getEducationalTrusts(session: dummySession);
      expect(trusts.length, 1);
      expect(trusts.first['name'], 'Apex Education Society');

      final newTrust = await client.createEducationalTrust(
        session: dummySession,
        payload: {'name': 'Zenith Foundation', 'trustCode': 'ZEN-01'},
      );
      expect(newTrust['id'], 'trust-2');
      expect(newTrust['name'], 'Zenith Foundation');

      // Test Campus Transfer APIs
      final newTransfer = await client.createCampusTransfer(
        session: dummySession,
        payload: {
          'transferType': 'student',
          'studentId': 'stu-1',
          'sourceSchoolId': 'school-1',
          'targetSchoolId': 'school-2',
          'reason': 'Relocation',
        },
      );
      expect(newTransfer['id'], 'trans-1');
      expect(newTransfer['status'], 'pending');

      final updatedTransfer = await client.updateCampusTransferStatus(
        session: dummySession,
        transferId: 'trans-1',
        status: 'approved',
      );
      expect(updatedTransfer['status'], 'approved');

      // Test Biometrics Ping and Reconciliation APIs
      final ping = await client.recordDeviceHeartbeat(session: dummySession, deviceId: 'dev-1');
      expect(ping['status'], 'online');

      final recon = await client.reconcileBiometricPunches(
        session: dummySession,
        date: '2026-10-17',
      );
      expect(recon['reconciledCount'], 42);

      // Test OBE Blueprint Paper Generator API
      final paper = await client.generateBlueprintedPaper(
        session: dummySession,
        classId: 'c-1',
        subjectId: 's-1',
        totalMarks: 50,
        bloomDistribution: {'remember': 20, 'understand': 30, 'apply': 50},
      );
      expect(paper['paperTitle'], 'Physics Midterm Exam');
      expect(paper['totalMarks'], 50);

      // Test Transcript Status API
      final updatedTranscript = await client.updateTranscriptRequestStatus(
        session: dummySession,
        requestId: 'tr-1',
        status: 'dispatched',
        notes: 'TRACK-999',
      );
      expect(updatedTranscript['status'], 'dispatched');
    });
  });
}

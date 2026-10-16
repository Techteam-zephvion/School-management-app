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
import 'package:schoolic/src/features/admin/views/admin_compliance_view.dart';
import 'package:schoolic/src/features/admin/views/admin_fees_view.dart';

void main() {
  const testApiUrl = 'https://api.example.test';
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school_1',
    displayName: 'Admin User',
    bearerToken: 'mock_jwt_token',
  );

  group('Phase 11 — Enterprise Roles & AppRole Extensions', () {
    test('AppRole fromString parses accountant, admissions_officer, and principal', () {
      expect(AppRole.fromString('accountant'), AppRole.accountant);
      expect(AppRole.fromString('admissions_officer'), AppRole.admissionsOfficer);
      expect(AppRole.fromString('admissionsOfficer'), AppRole.admissionsOfficer);
      expect(AppRole.fromString('principal'), AppRole.principal);

      expect(AppRole.accountant.toRoleString(), 'accountant');
      expect(AppRole.admissionsOfficer.toRoleString(), 'admissions_officer');
      expect(AppRole.principal.toRoleString(), 'principal');
    });

    test('AuthSession role getters correctly identify institutional roles', () {
      const accountantSession = AuthSession(
        email: 'acc@schoolic.edu',
        roles: [AppRole.accountant],
        schoolId: 'sch_1',
      );
      expect(accountantSession.isAccountant, isTrue);
      expect(accountantSession.isPrincipal, isFalse);
      expect(accountantSession.isAdmissionsOfficer, isFalse);

      const admissionsSession = AuthSession(
        email: 'adm@schoolic.edu',
        roles: [AppRole.admissionsOfficer],
        schoolId: 'sch_1',
      );
      expect(admissionsSession.isAdmissionsOfficer, isTrue);
      expect(admissionsSession.isAccountant, isFalse);

      const principalSession = AuthSession(
        email: 'prin@schoolic.edu',
        roles: [AppRole.principal],
        schoolId: 'sch_1',
      );
      expect(principalSession.isPrincipal, isTrue);
    });
  });

  group('Phase 11 — DPDP & Finance ApiClient', () {
    test('listAuditLogs formats query parameters properly', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/audit-logs');
        expect(request.url.queryParameters['action'], 'delete');
        expect(request.url.queryParameters['resourceType'], 'student');
        expect(request.url.queryParameters['limit'], '20');

        return http.Response(
          jsonEncode([
            {
              'id': 'log_1',
              'action': 'delete',
              'resourceType': 'student',
              'userEmail': 'admin@schoolic.edu',
              'createdAt': '2026-10-15T10:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final logs = await client.listAuditLogs(
        session: dummySession,
        action: 'delete',
        resourceType: 'student',
        limit: 20,
      );

      expect(logs.length, 1);
      expect(logs.first['action'], 'delete');
    });

    test('recordDpdpConsent sends verifiable parental consent payload', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/dpdp/consents');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['studentId'], 'stu_1');
        expect(body['parentGuardianName'], 'Rajesh Sharma');
        expect(body['parentGuardianPhone'], '+919876543210');
        expect(body['consentType'], 'enrollment_data_processing');

        return http.Response(
          jsonEncode({
            'id': 'consent_1',
            'status': 'granted',
            'verifiedVia': 'portal_submission',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.recordDpdpConsent(
        session: dummySession,
        studentId: 'stu_1',
        parentGuardianName: 'Rajesh Sharma',
        parentGuardianPhone: '+919876543210',
        consentType: 'enrollment_data_processing',
      );

      expect(res['id'], 'consent_1');
      expect(res['status'], 'granted');
    });

    test('resolveDsrRequest submits fulfillment status and optional anonymization', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/dpdp/dsr/dsr_123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'fulfilled');
        expect(body['anonymizeStudent'], isTrue);
        expect(body['resolutionNotes'], 'Student PII stripped per parent request.');

        return http.Response(
          jsonEncode({'id': 'dsr_123', 'status': 'fulfilled'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final res = await client.resolveDsrRequest(
        session: dummySession,
        requestId: 'dsr_123',
        status: 'fulfilled',
        resolutionNotes: 'Student PII stripped per parent request.',
        anonymizeStudent: true,
      );

      expect(res['status'], 'fulfilled');
    });

    test('createFeeConcession and createFeeRefund invoke respective financial endpoints', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/fees/concessions')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Merit Scholarship');
          expect(body['value'], 20);
          return http.Response(
            jsonEncode({'id': 'conc_1', 'code': 'MERIT20'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/fees/refunds')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['amount'], 5000);
          return http.Response(
            jsonEncode({'id': 'ref_1', 'refundNumber': 'REF-001', 'amount': 5000}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: testApiUrl);
      final conc = await client.createFeeConcession(
        session: dummySession,
        name: 'Merit Scholarship',
        code: 'MERIT20',
        type: 'percentage',
        value: 20,
        category: 'merit',
      );
      expect(conc['code'], 'MERIT20');

      final refRes = await client.createFeeRefund(
        session: dummySession,
        allocationId: 'alloc_1',
        studentId: 'stu_1',
        amount: 5000,
        reason: 'Duplicate fee transfer',
      );
      expect(refRes['refundNumber'], 'REF-001');
    });
  });

  group('Phase 11 — AdminComplianceView Widgets', () {
    testWidgets('AdminComplianceView renders header, stat strip, tabs, and empty state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/dpdp/consents')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/dpdp/dsr')) {
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        } else if (request.url.path.contains('/audit-logs')) {
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
              body: AdminComplianceView(
                students: [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DPDP 2023 Compliance & Audit Logs'), findsOneWidget);
      expect(find.text('Record Consent'), findsOneWidget);
      expect(find.text('VALID CONSENTS'), findsOneWidget);
      expect(find.text('PENDING DSR REQUESTS'), findsOneWidget);
      expect(find.text('AUDITED OPERATIONS'), findsOneWidget);

      expect(find.text('Parental Consents (0)'), findsOneWidget);
      expect(find.text('Data Subject Rights (0)'), findsOneWidget);
      expect(find.text('Audit Log Trail (0)'), findsOneWidget);

      // Default tab is Consents
      expect(find.text('No parental consents recorded yet'), findsOneWidget);

      // Switch to DSR tab
      await tester.tap(find.text('Data Subject Rights (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No Data Subject Rights requests'), findsOneWidget);

      // Switch to Audit tab
      await tester.tap(find.text('Audit Log Trail (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No audit log entries recorded'), findsOneWidget);
    });
  });

  group('Phase 11 — AdminFeesView Concessions & Refunds Tabs', () {
    testWidgets('AdminFeesView navigates to Concessions and Refunds tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/fees/summary')) {
          return http.Response(
            jsonEncode({'totalBilled': 0, 'totalCollected': 0, 'outstandingDue': 0, 'overdueCount': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminFeesView(
                  years: const [],
                  classes: const [],
                  sections: const [],
                  students: const [],
                  reload: () async {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Concessions tab is present
      expect(find.text('Concessions & Waivers (0)'), findsOneWidget);
      expect(find.text('Refunds (0)'), findsOneWidget);

      // Switch to Concessions
      await tester.tap(find.text('Concessions & Waivers (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No fee concessions configured yet.'), findsOneWidget);

      // Switch to Refunds
      await tester.tap(find.text('Refunds (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No payment refunds issued yet.'), findsOneWidget);
    });
  });
}

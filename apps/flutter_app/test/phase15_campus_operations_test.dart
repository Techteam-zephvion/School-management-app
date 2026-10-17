import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/providers.dart';
import 'package:schoolic/src/features/admin/views/admin_campus_view.dart';
import 'package:schoolic/src/features/shared/components/command_palette.dart';
import 'package:schoolic/src/features/shared/components/status_badge.dart';

void main() {
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school-1',
    displayName: 'Super Admin',
    bearerToken: 'mock-token',
  );

  group('Phase 15: StatusBadge Extensions', () {
    testWidgets('StatusBadge.payrollStatus renders all statuses correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.payrollStatus('draft'),
                StatusBadge.payrollStatus('approved'),
                StatusBadge.payrollStatus('paid'),
                StatusBadge.payrollStatus('voided'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('VOID'), findsOneWidget);
    });

    testWidgets('StatusBadge.inventoryCondition renders all conditions correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.inventoryCondition('new'),
                StatusBadge.inventoryCondition('good'),
                StatusBadge.inventoryCondition('fair'),
                StatusBadge.inventoryCondition('damaged'),
                StatusBadge.inventoryCondition('under_repair'),
                StatusBadge.inventoryCondition('disposed'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('FAIR'), findsOneWidget);
      expect(find.text('DAMAGED'), findsOneWidget);
      expect(find.text('MAINTENANCE'), findsOneWidget);
      expect(find.text('DISPOSED'), findsOneWidget);
    });
  });

  group('Phase 15: CommandPaletteDialog Campus Commands', () {
    testWidgets('renders campus commands and triggers campus action callbacks', (tester) async {
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

      // Open Command Palette
      await tester.tap(find.text('Open Palette'));
      await tester.pumpAndSettle();

      expect(find.byType(CommandPaletteDialog), findsOneWidget);

      // Search for Library command
      await tester.enterText(find.byType(TextField), 'library');
      await tester.pumpAndSettle();

      expect(find.text('Library Circulation & Catalog'), findsOneWidget);

      // Trigger selection
      await tester.tap(find.text('Library Circulation & Catalog'));
      await tester.pumpAndSettle();

      expect(triggeredAction, 'action:campus_library');
    });
  });

  group('Phase 15: AdminCampusView', () {
    testWidgets('renders 5 tabs, stat strips, and switches tabs smoothly', (tester) async {
      final mockHttpClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/v1/admin/operations/library/stats') {
          return http.Response(
            jsonEncode({
              'totalTitles': 45,
              'totalCopies': 250,
              'activeLoans': 15,
              'overdueLoans': 2,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/library/books') {
          return http.Response(
            jsonEncode([
              {
                'id': 'b-1',
                'title': 'A Brief History of Time',
                'isbn': '9780553380163',
                'author': 'Stephen Hawking',
                'publisher': 'Bantam',
                'category': 'science',
                'edition': '10th',
                'rackLocation': 'Sci-04',
                'totalCopies': 6,
                'availableCopies': 5,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/library/loans') {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/inventory/items') {
          return http.Response(
            jsonEncode([
              {
                'id': 'inv-1',
                'name': 'Compound Microscope',
                'itemCode': 'BIO-MIC-01',
                'category': 'lab_equipment',
                'location': 'Lab 2',
                'condition': 'good',
                'quantity': 12,
                'unitPriceCents': 1800000,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/inventory/allocations') {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/inventory/purchase-requests') {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/payroll/records') {
          return http.Response(
            jsonEncode([
              {
                'id': 'pr-1',
                'staffId': 'st-1',
                'month': 10,
                'year': 2026,
                'basicPayCents': 5000000,
                'hraCents': 1000000,
                'allowancesCents': 500000,
                'grossPayCents': 6500000,
                'netPayCents': 5800000,
                'status': 'approved',
                'staffName': 'Dr. Sharma',
                'staffCode': 'EMP-01',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/payroll/salary-structures') {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/hostel/rooms') {
          return http.Response(
            jsonEncode([
              {
                'id': 'rm-1',
                'blockName': 'A Block',
                'roomNumber': '201',
                'roomType': 'boys',
                'capacity': 2,
                'occupiedCount': 1,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/hostel/allocations') {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/visitors/passes') {
          return http.Response(
            jsonEncode([
              {
                'id': 'gp-1',
                'visitorName': 'Anil Mehra',
                'phone': '+919876543210',
                'purpose': 'Admission enquiry',
                'badgeNumber': 'VIS-007',
                'status': 'checked_in',
                'entryTime': '2026-10-17T09:30:00.000Z',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path == '/api/v1/admin/operations/health/infirmary-visits') {
          return http.Response(
            jsonEncode([
              {
                'id': 'hv-1',
                'studentId': 'stu-1',
                'symptoms': 'Stomach pain',
                'treatmentGiven': 'Antacid and bed rest',
                'outcome': 'rest_and_monitor',
                'studentName': 'Aarav Gupta',
                'admissionNumber': 'ADM-101',
                'createdAt': '2026-10-17T11:00:00.000Z',
              }
            ]),
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
              body: AdminCampusView(
                students: [
                  {'id': 'stu-1', 'fullName': 'Aarav Gupta', 'admissionNumber': 'ADM-101'},
                ],
                staff: [
                  {'id': 'st-1', 'fullName': 'Dr. Sharma', 'staffCode': 'EMP-01', 'isTeacher': true},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and tabs
      expect(find.text('Campus Operations Ecosystem'), findsOneWidget);
      expect(find.text('Library Hub'), findsOneWidget);
      expect(find.text('Inventory & Assets'), findsOneWidget);
      expect(find.text('Staff Payroll'), findsOneWidget);
      expect(find.text('Hostel & Gate Passes'), findsOneWidget);
      expect(find.text('Student Health & Infirmary'), findsOneWidget);

      // Verify loaded book in Library Hub
      expect(find.text('A Brief History of Time'), findsOneWidget);
      expect(find.text('Stephen Hawking'), findsOneWidget);

      // Switch to Inventory Tab
      await tester.tap(find.text('Inventory & Assets'));
      await tester.pumpAndSettle();

      expect(find.text('Compound Microscope'), findsOneWidget);
      expect(find.text('BIO-MIC-01'), findsOneWidget);

      // Switch to Staff Payroll Tab
      await tester.tap(find.text('Staff Payroll'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sharma'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);

      // Switch to Hostel & Gate Passes Tab
      await tester.tap(find.text('Hostel & Gate Passes'));
      await tester.pumpAndSettle();

      expect(find.text('A Block'), findsOneWidget);
      expect(find.text('201'), findsOneWidget);
      expect(find.text('Anil Mehra'), findsOneWidget);
      expect(find.text('VIS-007'), findsOneWidget);

      // Switch to Student Health Tab
      await tester.tap(find.text('Student Health & Infirmary'));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Gupta'), findsOneWidget);
      expect(find.text('Stomach pain'), findsOneWidget);
    });
  });

  group('Phase 15: ApiClient Campus Operations Methods', () {
    test('Library methods issue and return book correctly', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/operations/library/loans/issue') {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body);
          expect(body['bookId'], 'bk-1');
          expect(body['studentId'], 'stu-1');
          return http.Response(
            jsonEncode({'id': 'loan-1', 'bookId': 'bk-1', 'status': 'issued'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/operations/library/loans/loan-1/return') {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body);
          expect(body['lateFineCents'], 5000);
          return http.Response(
            jsonEncode({'id': 'loan-1', 'status': 'returned', 'lateFineCents': 5000}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final loan = await client.issueLibraryLoan(
        session: dummySession,
        payload: {
          'bookId': 'bk-1',
          'studentId': 'stu-1',
          'dueDate': '2026-10-31',
        },
      );
      expect(loan['id'], 'loan-1');
      expect(loan['status'], 'issued');

      final returned = await client.returnLibraryLoan(
        session: dummySession,
        loanId: 'loan-1',
        payload: {'lateFineCents': 5000},
      );
      expect(returned['status'], 'returned');
      expect(returned['lateFineCents'], 5000);
    });

    test('Inventory and Payroll methods execute and parse responses', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/operations/inventory/items') {
          return http.Response(
            jsonEncode({'id': 'item-101', 'name': 'Oscilloscope', 'category': 'lab_equipment'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/operations/payroll/generate-monthly') {
          return http.Response(
            jsonEncode({
              'generatedCount': 42,
              'records': [
                {'id': 'pr-1', 'netPayCents': 5000000}
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final item = await client.createInventoryItem(
        session: dummySession,
        payload: {
          'name': 'Oscilloscope',
          'category': 'lab_equipment',
          'quantity': 5,
        },
      );
      expect(item['id'], 'item-101');
      expect(item['name'], 'Oscilloscope');

      final batch = await client.generateMonthlyPayroll(
        session: dummySession,
        payload: {
          'month': 10,
          'year': 2026,
        },
      );
      expect(batch['generatedCount'], 42);
      expect((batch['records'] as List).length, 1);
    });

    test('Hostel and Health methods create and query records', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/operations/visitors/passes') {
          return http.Response(
            jsonEncode({'id': 'gp-99', 'visitorName': 'Vikram Seth', 'badgeNumber': 'VIS-99'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/operations/health/profiles/stu-10') {
          return http.Response(
            jsonEncode({
              'id': 'hp-1',
              'studentId': 'stu-10',
              'bloodGroup': 'O_POSITIVE',
              'emergencyContactPhone': '+919123456789',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final pass = await client.createVisitorGatePass(
        session: dummySession,
        payload: {
          'visitorName': 'Vikram Seth',
          'phone': '+919876543210',
          'purpose': 'Guest Lecture',
          'badgeNumber': 'VIS-99',
        },
      );
      expect(pass['id'], 'gp-99');
      expect(pass['badgeNumber'], 'VIS-99');

      final profile = await client.getStudentHealthProfile(
        session: dummySession,
        studentId: 'stu-10',
      );
      expect(profile['bloodGroup'], 'O_POSITIVE');
      expect(profile['emergencyContactPhone'], '+919123456789');
    });
  });
}

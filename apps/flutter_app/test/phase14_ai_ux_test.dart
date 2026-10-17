import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/providers.dart';
import 'package:schoolic/src/features/admin/views/admin_insights_view.dart';
import 'package:schoolic/src/features/shared/components/command_palette.dart';
import 'package:schoolic/src/features/shared/components/status_badge.dart';
import 'package:schoolic/src/features/teacher/components/ai_draft_remarks_dialog.dart';
import 'package:schoolic/src/features/teacher/components/ai_homework_feedback_dialog.dart';

void main() {
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school-1',
    displayName: 'Super Admin',
    bearerToken: 'mock-token',
  );

  group('Phase 14: StatusBadge.riskLevel', () {
    testWidgets('renders all risk levels with appropriate tone and icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.riskLevel('critical'),
                StatusBadge.riskLevel('high'),
                StatusBadge.riskLevel('moderate'),
                StatusBadge.riskLevel('low'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CRITICAL RISK'), findsOneWidget);
      expect(find.text('HIGH RISK'), findsOneWidget);
      expect(find.text('MODERATE RISK'), findsOneWidget);
      expect(find.text('LOW RISK'), findsOneWidget);
    });
  });

  group('Phase 14: CommandPaletteDialog', () {
    testWidgets('renders search field, default commands, and filters on query', (tester) async {
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
      expect(find.text('Natural Language Analytics Query'), findsOneWidget);
      expect(find.text('Student At-Risk Early Warning System'), findsOneWidget);

      // Type search filter
      await tester.enterText(find.byType(TextField), 'defaulter');
      await tester.pumpAndSettle();

      expect(find.text('Natural Language Analytics Query'), findsOneWidget);
      expect(find.text('Record Daily Attendance'), findsNothing);

      // Select first command
      await tester.tap(find.text('Natural Language Analytics Query'));
      await tester.pumpAndSettle();

      expect(triggeredAction, 'action:nl_query');
    });
  });

  group('Phase 14: AI Drafting Dialogs', () {
    testWidgets('AiDraftRemarksDialog renders inputs and tone selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AiDraftRemarksDialog.show(
                  context,
                  initialStudentName: 'Kavya Sharma',
                  initialPercentage: '91.5%',
                ),
                child: const Text('Open Remarks Assistant'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Remarks Assistant'));
      await tester.pumpAndSettle();

      expect(find.text('AI Report Card Remarks Assistant'), findsOneWidget);
      expect(find.text('Kavya Sharma'), findsOneWidget);
      expect(find.text('91.5%'), findsOneWidget);
      expect(find.text('Encouraging'), findsOneWidget);
      expect(find.text('Constructive'), findsOneWidget);
      expect(find.text('Formal'), findsOneWidget);
      expect(find.text('Generate Remarks'), findsOneWidget);
    });

    testWidgets('AiHomeworkFeedbackDialog renders score and rubrics fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AiHomeworkFeedbackDialog.show(
                  context,
                  initialAssignmentTitle: 'Trigonometry Homework 3',
                  initialSubject: 'Mathematics',
                  initialScore: 19,
                  initialMaxScore: 20,
                ),
                child: const Text('Open Homework Assistant'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Homework Assistant'));
      await tester.pumpAndSettle();

      expect(find.text('AI Homework Feedback Generator'), findsOneWidget);
      expect(find.text('Trigonometry Homework 3'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Generate Feedback'), findsOneWidget);
    });
  });

  group('Phase 14: AdminInsightsView & Applied AI Tabs', () {
    testWidgets('AdminInsightsView renders At-Risk, NL Query, and Attendance tabs', (tester) async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/at-risk-students')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'risk-1',
                'studentId': 'stud-1',
                'studentName': 'Rahul Verma',
                'admissionNumber': 'ADM-101',
                'className': 'Class 10',
                'sectionName': 'A',
                'riskLevel': 'critical',
                'compositeScore': 85,
                'attendanceScore': 90,
                'academicScore': 80,
                'feeScore': 85,
                'factors': ['Critically low attendance (54%)', 'Failing marks in Science'],
                'status': 'active',
                'interventions': [],
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({}), 200, headers: {'content-type': 'application/json'});
      });

      final mockClient = ApiClient(
        httpClient: mockHttpClient,
        apiBaseUrlOverride: 'http://localhost:8787',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockClient),
            authControllerProvider.overrideWith(
              (ref) => AuthController(mockClient)..session = dummySession,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminInsightsView(
                  classes: [
                    {'id': 'c-1', 'name': 'Class 10'},
                  ],
                  sections: [
                    {'id': 's-1', 'classId': 'c-1', 'name': 'A'},
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Institutional Intelligence'), findsOneWidget);
      expect(find.text('At-Risk Early Warning'), findsOneWidget);
      expect(find.text('Natural Language Queries'), findsOneWidget);
      expect(find.text('Attendance AI Synthesis'), findsOneWidget);

      // Verify loaded at-risk alert
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(StatusBadge), matching: find.text('CRITICAL RISK')),
        findsOneWidget,
      );
      expect(find.text('85'), findsOneWidget);
      expect(find.text('Log Intervention'), findsOneWidget);

      // Switch to Natural Language Queries tab
      await tester.tap(find.text('Natural Language Queries'));
      await tester.pumpAndSettle();

      expect(find.text('Natural Language Database Query Engine'), findsOneWidget);
      expect(find.text('ZERO PROMPT LEAKAGE'), findsOneWidget);
      expect(find.text('Run Query'), findsOneWidget);
    });
  });

  group('Phase 14: ApiClient Applied AI Methods', () {
    test('executeNaturalLanguageQuery parses structured intent and results table', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/analytics/natural-language-query');
        final body = jsonDecode(request.body);
        expect(body['query'], 'List fee defaulters above 5000');
        return http.Response(
          jsonEncode({
            'intent': 'fee_defaulters',
            'explanation': 'Found 2 students with outstanding fees.',
            'columns': ['Student Name', 'Due Amount'],
            'data': [
              {'Student Name': 'Aarav Patel', 'Due Amount': '₹8,000'},
            ],
            'suggestedFollowUps': ['Send WhatsApp reminder'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final res = await client.executeNaturalLanguageQuery(
        session: dummySession,
        query: 'List fee defaulters above 5000',
      );

      expect(res['intent'], 'fee_defaulters');
      expect(res['explanation'], 'Found 2 students with outstanding fees.');
      expect((res['columns'] as List).length, 2);
    });

    test('draftReportCardRemarks calls teacher remarks drafting endpoint', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/teacher/ai/draft-remarks');
        final body = jsonDecode(request.body);
        expect(body['studentName'], 'Pooja Hegde');
        expect(body['tone'], 'encouraging');
        return http.Response(
          jsonEncode({
            'studentName': 'Pooja Hegde',
            'tone': 'encouraging',
            'draftRemarks': 'Pooja is an exceptionally diligent student.',
            'alternativeOptions': ['A stellar term for Pooja!'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(httpClient: mockHttpClient, apiBaseUrlOverride: 'http://localhost:8787');
      final res = await client.draftReportCardRemarks(
        session: dummySession,
        studentName: 'Pooja Hegde',
        overallPercentage: '94%',
      );

      expect(res['studentName'], 'Pooja Hegde');
      expect(res['draftRemarks'], contains('Pooja'));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schoolic/src/core/api_client.dart';
import 'package:schoolic/src/core/localization/app_localizations.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/offline/offline_attendance_manager.dart';
import 'package:schoolic/src/core/providers.dart';
import 'package:schoolic/src/features/admin/utils/report_card_pdf.dart';
import 'package:schoolic/src/features/admin/views/admin_exams_view.dart';

void main() {
  const dummySession = AuthSession(
    email: 'admin@schoolic.edu',
    roles: [AppRole.admin],
    schoolId: 'school-1',
    displayName: 'Super Admin',
    bearerToken: 'mock-token',
  );

  group('Phase 13: Regional Languages & AppLocalizations', () {
    test('AppLanguage locales and native names match supported regions', () {
      expect(AppLanguage.english.code, 'en');
      expect(AppLanguage.kannada.code, 'kn');
      expect(AppLanguage.hindi.code, 'hi');

      expect(AppLanguage.english.locale, const Locale('en'));
      expect(AppLanguage.kannada.locale, const Locale('kn'));
      expect(AppLanguage.hindi.locale, const Locale('hi'));

      expect(AppLanguage.kannada.nativeName, 'ಕನ್ನಡ');
      expect(AppLanguage.hindi.nativeName, 'हिन्दी');
      expect(AppLanguage.english.nativeName, 'English');
    });

    test('AppLocalizations returns accurate localized translations for all 3 languages', () {
      const en = AppLocalizations(AppLanguage.english);
      const kn = AppLocalizations(AppLanguage.kannada);
      const hi = AppLocalizations(AppLanguage.hindi);

      expect(en.text('academics'), 'Academics & Exams');
      expect(kn.text('academics'), 'ಶೈಕ್ಷಣಿಕ ಮತ್ತು ಪರೀಕ್ಷೆಗಳು');
      expect(hi.text('academics'), 'शैक्षणिक और परीक्षा');

      expect(en.text('attendance'), 'Attendance');
      expect(kn.text('attendance'), 'ಹಾಜರಾತಿ');
      expect(hi.text('attendance'), 'उपस्थिति');

      expect(en.text('gradingSchemes'), 'Grading Schemes');
      expect(kn.text('gradingSchemes'), 'ಶ್ರೇಣೀಕರಣ ವ್ಯವಸ್ಥೆಗಳು');
      expect(hi.text('gradingSchemes'), 'ग्रेडिंग योजनाएं');

      expect(en.text('reportCards'), 'Report Cards');
      expect(kn.text('reportCards'), 'ಪ್ರಗತಿ ಪತ್ರಗಳು');
      expect(hi.text('reportCards'), 'प्रगति पत्र (रिपोर्ट कार्ड)');

      expect(en.text('offlineMode'), 'Offline Mode');
      expect(kn.text('offlineMode'), 'ಆಫ್‌ಲೈನ್ ಮೋಡ್');
      expect(hi.text('offlineMode'), 'ऑफ़लाइन मोड');

      expect(en.text('pendingSync'), 'Pending Sync');
      expect(kn.text('pendingSync'), 'ಸಿಂಕ್ ಬಾಕಿ ಇದೆ');
      expect(hi.text('pendingSync'), 'सिंक लंबित');
    });

    testWidgets('LanguagePickerDropdown renders and can be mounted in widget tree', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: LanguagePickerDropdown(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LanguagePickerDropdown), findsOneWidget);
      expect(find.byType(DropdownButton<AppLanguage>), findsOneWidget);
    });

    testWidgets('LanguagePickerDropdown popup style renders correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: LanguagePickerDropdown(isCompact: true),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<AppLanguage>), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    });
  });

  group('Phase 13: Offline-First Attendance Storage & Serialization', () {
    test('OfflineAttendanceRecordItem correctly serializes to and from JSON', () {
      const record = OfflineAttendanceRecordItem(
        studentId: 'stud-uuid-001',
        status: 'present',
        remarks: 'Arrived on time',
      );

      final jsonMap = record.toJson();
      expect(jsonMap['studentId'], 'stud-uuid-001');
      expect(jsonMap['status'], 'present');
      expect(jsonMap['remarks'], 'Arrived on time');

      final reconstructed = OfflineAttendanceRecordItem.fromJson(jsonMap);
      expect(reconstructed.studentId, record.studentId);
      expect(reconstructed.status, record.status);
      expect(reconstructed.remarks, record.remarks);
    });

    test('OfflineAttendanceBatch serialization preserves all student records and timestamps', () {
      final now = DateTime.now();
      final batch = OfflineAttendanceBatch(
        clientBatchId: 'batch-test-999',
        academicYearId: 'year-2026',
        classId: 'class-10',
        sectionId: 'sec-a',
        kind: 'daily',
        attendanceDate: '2026-10-16',
        clientTimestamp: now.toIso8601String(),
        records: const [
          OfflineAttendanceRecordItem(studentId: 'st-1', status: 'present'),
          OfflineAttendanceRecordItem(studentId: 'st-2', status: 'absent', remarks: 'Medical leave'),
          OfflineAttendanceRecordItem(studentId: 'st-3', status: 'late'),
        ],
      );

      final jsonStr = jsonEncode(batch.toJson());
      final decodedMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final reconstructed = OfflineAttendanceBatch.fromJson(decodedMap);

      expect(reconstructed.clientBatchId, 'batch-test-999');
      expect(reconstructed.academicYearId, 'year-2026');
      expect(reconstructed.classId, 'class-10');
      expect(reconstructed.sectionId, 'sec-a');
      expect(reconstructed.kind, 'daily');
      expect(reconstructed.attendanceDate, '2026-10-16');
      expect(reconstructed.records.length, 3);
      expect(reconstructed.records[0].status, 'present');
      expect(reconstructed.records[1].status, 'absent');
      expect(reconstructed.records[1].remarks, 'Medical leave');
      expect(reconstructed.records[2].status, 'late');
    });

    test('OfflineAttendanceNotifier stores, retrieves, and clears local batches', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(offlineAttendanceProvider.notifier);

      expect(container.read(offlineAttendanceProvider).isEmpty, isTrue);
      expect(container.read(pendingOfflineCountProvider), 0);

      final batch1 = OfflineAttendanceBatch(
        clientBatchId: 'batch-1',
        academicYearId: 'year-1',
        classId: 'c1',
        sectionId: 's1',
        kind: 'daily',
        attendanceDate: '2026-10-16',
        clientTimestamp: DateTime.now().toIso8601String(),
        records: const [
          OfflineAttendanceRecordItem(studentId: 's1', status: 'present'),
          OfflineAttendanceRecordItem(studentId: 's2', status: 'present'),
        ],
      );

      await notifier.enqueueBatch(batch1);

      expect(container.read(offlineAttendanceProvider).length, 1);
      expect(container.read(pendingOfflineCountProvider), 1);

      final batch2 = OfflineAttendanceBatch(
        clientBatchId: 'batch-2',
        academicYearId: 'year-1',
        classId: 'c1',
        sectionId: 's1',
        kind: 'daily',
        attendanceDate: '2026-10-16',
        clientTimestamp: DateTime.now().toIso8601String(),
        records: const [
          OfflineAttendanceRecordItem(studentId: 's3', status: 'absent'),
        ],
      );

      await notifier.enqueueBatch(batch2);

      expect(container.read(offlineAttendanceProvider).length, 2);
      expect(container.read(pendingOfflineCountProvider), 2);

      await notifier.removeBatch('batch-1');
      expect(container.read(offlineAttendanceProvider).length, 1);
      expect(container.read(offlineAttendanceProvider).first.clientBatchId, 'batch-2');

      await notifier.clearQueue();
      expect(container.read(offlineAttendanceProvider).isEmpty, isTrue);
      expect(container.read(pendingOfflineCountProvider), 0);
    });
  });

  group('Phase 13: Official Board Report Card PDF Generation', () {
    test('buildReportCardPdf creates a valid, compliant PDF document with scholastic and co-scholastic data', () async {
      const reportCardData = ReportCardPdfData(
        schoolName: 'Schoolic Model International School',
        schoolAffiliation: 'CBSE Affiliation No. 1930482',
        schoolAddress: '100ft Road, Indiranagar, Bengaluru, Karnataka - 560038',
        studentName: 'Aarav Sharma',
        admissionNumber: 'SCH-2026-0042',
        rollNumber: '10A01',
        className: 'Class 10',
        sectionName: 'A',
        termName: 'Annual Examination 2026',
        schemeName: 'CBSE Secondary 9-Point Scale',
        board: 'CBSE',
        overallPercentage: '91.4%',
        overallGrade: 'A1',
        overallGradePoint: '10.0',
        attendanceRate: '96.2%',
        resultStatus: 'PROMOTED TO CLASS 11',
        teacherRemarks: 'Outstanding scholastic achievement and leadership in co-curricular activities.',
        issueDate: '2026-10-16',
        scholasticRows: [
          {
            'subjectName': 'Mathematics',
            'components': {'pt': 9.5, 'sub_enrich': 5.0, 'portfolio': 5.0, 'term_exam': 76.0},
            'obtained': 95.5,
            'max': 100.0,
            'percentage': 95.5,
            'grade': 'A1',
            'gradePoint': '10.0',
          },
          {
            'subjectName': 'Science',
            'components': {'pt': 9.0, 'sub_enrich': 4.5, 'portfolio': 4.5, 'term_exam': 72.0},
            'obtained': 90.0,
            'max': 100.0,
            'percentage': 90.0,
            'grade': 'A1',
            'gradePoint': '10.0',
          },
          {
            'subjectName': 'English Communicative',
            'components': {'pt': 8.5, 'sub_enrich': 5.0, 'portfolio': 4.5, 'term_exam': 71.0},
            'obtained': 89.0,
            'max': 100.0,
            'percentage': 89.0,
            'grade': 'A2',
            'gradePoint': '9.0',
          },
          {
            'subjectName': 'Social Science',
            'components': {'pt': 9.0, 'sub_enrich': 4.5, 'portfolio': 4.5, 'term_exam': 73.0},
            'obtained': 91.0,
            'max': 100.0,
            'percentage': 91.0,
            'grade': 'A1',
            'gradePoint': '10.0',
          },
        ],
        coScholasticRows: [
          {'domain': 'Work Education / SUPW', 'grade': 'A'},
          {'domain': 'Health & Physical Education', 'grade': 'A'},
          {'domain': 'Art Education', 'grade': 'A'},
          {'domain': 'Discipline & Conduct', 'grade': 'A'},
        ],
      );

      final Uint8List pdfBytes = await buildReportCardPdf(reportCardData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1500));

      // Standard PDF magic byte sequence %PDF-
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });

  group('Phase 13: Admin Academics & Board Schemes View Widgets', () {
    testWidgets('AdminExamsView renders 3 subtabs: Exams Schedule, Board Schemes & Scales, and Official Report Cards', (tester) async {
      final mockHttp = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/academics/grading-schemes')) {
          return http.Response(jsonEncode({'schemes': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (path.contains('/academics/report-cards')) {
          return http.Response(jsonEncode({'reportCards': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"ok": true}', 200, headers: {'content-type': 'application/json'});
      });

      final testClient = ApiClient(httpClient: mockHttp, apiBaseUrlOverride: 'https://api.example.test');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(testClient),
            authControllerProvider.overrideWith(
              (ref) => AuthController(testClient)..session = dummySession,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminExamsView(
                  exams: const [],
                  years: const [
                    {'id': 'y1', 'name': '2026-2027'},
                  ],
                  classes: const [
                    {'id': 'c1', 'name': 'Class 10'},
                    {'id': 'c2', 'name': 'Class 12'},
                  ],
                  sections: const [
                    {'id': 's1', 'name': 'Section A'},
                  ],
                  subjects: const [
                    {'id': 'sub1', 'name': 'Mathematics'},
                    {'id': 'sub2', 'name': 'Science'},
                  ],
                  reload: () async {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify subtabs
      expect(find.textContaining('Exams Schedule'), findsOneWidget);
      expect(find.textContaining('Board Schemes & Scales'), findsOneWidget);
      expect(find.textContaining('Official Report Cards'), findsOneWidget);

      // Verify stats strip
      expect(find.text('EXAMS SCHEDULED'), findsOneWidget);
      expect(find.text('GRADING SCHEMES'), findsOneWidget);
      expect(find.text('REPORT CARDS'), findsOneWidget);

      // Tap on Board Schemes & Scales subtab
      await tester.tap(find.textContaining('Board Schemes & Scales'));
      await tester.pumpAndSettle();

      // Tap on Official Report Cards subtab
      await tester.tap(find.textContaining('Official Report Cards'), warnIfMissed: false);
      await tester.pumpAndSettle();
    });
  });
}

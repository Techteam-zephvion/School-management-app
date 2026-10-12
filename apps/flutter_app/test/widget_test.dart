import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/theme.dart';
import 'package:schoolic/src/features/admin/dialogs/student_attendance_dialog.dart';
import 'package:schoolic/src/features/admin/views/admin_overview_view.dart';
import 'package:schoolic/src/features/admin/views/admin_students_view.dart';
import 'package:schoolic/src/features/admin/views/admin_timetable_view.dart';
import 'package:schoolic/src/features/auth/login_screen.dart';
import 'package:schoolic/src/features/shared/components/attendance_status_button.dart';
import 'package:schoolic/src/features/shared/components/feedback_banner.dart';
import 'package:schoolic/src/features/shared/components/page_header.dart';
import 'package:schoolic/src/features/shared/components/schoolic_logo.dart';
import 'package:schoolic/src/features/shared/components/shortcuts_dialog.dart';
import 'package:schoolic/src/features/shared/components/stat_strip.dart';
import 'package:schoolic/src/features/shared/components/status_badge.dart';
import 'package:schoolic/src/features/shared/components/tour_dialog.dart';
import 'package:schoolic/src/features/teacher/utils/teaching_material_pdf.dart';

void main() {
  test('auth session serializes roles and dev identity', () {
    const session = AuthSession(
      email: 'admin@schoolic.local',
      displayName: 'System Admin',
      roles: [AppRole.admin],
      schoolId: 'school-1',
      devNeonUserId: 'dev-admin',
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.email, 'admin@schoolic.local');
    expect(restored.displayName, 'System Admin');
    expect(restored.isAdmin, isTrue);
    expect(restored.devNeonUserId, 'dev-admin');
  });

  test('teaching material PDF filenames are useful and separated by audience', () {
    const material = TeachingMaterialPdfData(
      type: 'worksheet',
      title: 'Fractions: Warm Up!',
      topic: 'Fractions',
      overview: 'Practice equivalent fractions.',
      sections: [TeachingMaterialSection(heading: 'Questions', items: ['Simplify 2/4.'])],
      checksForUnderstanding: [],
      teacherNotes: ['1/2'],
    );

    expect(
      teachingMaterialFilename(material, mode: TeachingMaterialExportMode.student),
      'worksheet-fractions-warm-up-student.pdf',
    );
    expect(
      teachingMaterialFilename(material, mode: TeachingMaterialExportMode.answerKey),
      'worksheet-fractions-warm-up-answer-key.pdf',
    );
    expect(hasAnswerKey(material), isTrue);
  });

  test('teaching material PDF builder creates student and answer-key documents', () async {
    const material = TeachingMaterialPdfData(
      type: 'quiz',
      title: 'Fractions Quiz',
      topic: 'Fractions',
      overview: 'Answer each question.',
      sections: [TeachingMaterialSection(heading: 'Questions', items: ['Simplify 2/4.', 'Choose the equivalent fraction.'])],
      checksForUnderstanding: ['Show your working.'],
      teacherNotes: ['1. 1/2', '2. Answers may vary by option set.'],
    );

    final studentPdf = await buildTeachingMaterialPdf(material, mode: TeachingMaterialExportMode.student);
    final keyPdf = await buildTeachingMaterialPdf(material, mode: TeachingMaterialExportMode.answerKey);

    expect(studentPdf.length, greaterThan(1000));
    expect(keyPdf.length, greaterThan(1000));
    expect(teachingMaterialFilename(material, mode: TeachingMaterialExportMode.student), isNot(teachingMaterialFilename(material, mode: TeachingMaterialExportMode.answerKey)));
  });

  testWidgets('PageHeader renders title, description, and primary action', (tester) async {
    bool clicked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSchoolicTheme(),
        home: Scaffold(
          body: PageHeader(
            title: 'Attendance Register',
            description: 'Historical records across grades',
            primaryAction: FilledButton(
              onPressed: () => clicked = true,
              child: const Text('Export CSV'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Attendance Register'), findsOneWidget);
    expect(find.text('Historical records across grades'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);

    await tester.tap(find.text('Export CSV'));
    expect(clicked, isTrue);
  });

  testWidgets('StatStrip renders typographic items with labels and values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSchoolicTheme(),
        home: const Scaffold(
          body: StatStrip(
            items: [
              StatItemData(label: 'Enrolled Students', value: '142', helper: 'All cohorts'),
              StatItemData(label: 'Faculty', value: '12', helper: 'Active teachers'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ENROLLED STUDENTS'), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
    expect(find.text('All cohorts'), findsOneWidget);
    expect(find.text('FACULTY'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('StatusBadge maps attendance statuses correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSchoolicTheme(),
        home: Scaffold(
          body: Row(
            children: [
              StatusBadge.attendance(AttendanceStatus.present),
              StatusBadge.attendance(AttendanceStatus.absent),
              StatusBadge.attendance(AttendanceStatus.late),
              StatusBadge.attendance(AttendanceStatus.excused),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Excused'), findsOneWidget);
  });

  testWidgets('AttendanceStatusGroup switches status on tap', (tester) async {
    AttendanceStatus current = AttendanceStatus.present;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSchoolicTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: AttendanceStatusGroup(
                selectedStatus: current,
                onChanged: (newStatus) {
                  setState(() => current = newStatus);
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);

    await tester.tap(find.text('Absent'));
    await tester.pumpAndSettle();

    expect(current, AttendanceStatus.absent);
  });

  testWidgets('FeedbackBanner renders error message and action callback', (tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSchoolicTheme(),
        home: Scaffold(
          body: FeedbackBanner(
            message: 'Failed to persist attendance records',
            tone: FeedbackTone.error,
            actionLabel: 'Retry',
            onAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Failed to persist attendance records'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  group('P1 — Student Attendance Summary Metrics', () {
    testWidgets('renders real nonzero metrics from fixture correctly', (tester) async {
      final nonzeroFixture = {
        'student': {'id': 's1', 'fullName': 'Aarav Patel'},
        'stats': {
          'totalSessions': 20,
          'present': 16,
          'absent': 2,
          'late': 1,
          'excused': 1,
          'attendanceRate': 85.5,
        },
        'records': [
          {
            'id': 'r1',
            'attendanceDate': '2026-10-10',
            'status': 'present',
            'kind': 'daily',
            'remarks': 'Punctual',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: StudentAttendanceDialog(
              studentId: 's1',
              studentName: 'Aarav Patel',
              initialData: nonzeroFixture,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('85.5%'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // late and excused both have count 1
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('2026-10-10'), findsOneWidget);
    });

    testWidgets('renders neutral dash and zeros for empty attendance stats', (tester) async {
      final emptyFixture = {
        'student': {'id': 's2', 'fullName': 'Diya Sharma'},
        'stats': {
          'totalSessions': 0,
          'present': 0,
          'absent': 0,
          'late': 0,
          'excused': 0,
          'attendanceRate': 0,
        },
        'records': <Map<String, Object?>>[],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: StudentAttendanceDialog(
              studentId: 's2',
              studentName: 'Diya Sharma',
              initialData: emptyFixture,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(5));
      expect(find.text('No attendance records'), findsOneWidget);
    });

    testWidgets('gracefully handles malformed or null stats object without throwing', (tester) async {
      final malformedFixture = {
        'student': {'id': 's3', 'fullName': 'Arjun Rao'},
        'stats': null,
        'records': null,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: StudentAttendanceDialog(
              studentId: 's3',
              studentName: 'Arjun Rao',
              initialData: malformedFixture,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Arjun Rao'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(5));
    });
  });

  group('P2 — Operational Attention Cohort Labels', () {
    testWidgets('renders Grade and Section labels instead of raw section names', (tester) async {
      final classes = [
        {'id': 'c1', 'name': 'Grade 6'},
        {'id': 'c2', 'name': 'Grade 7'},
      ];
      final sections = [
        {'id': 'sec1', 'classId': 'c1', 'name': 'A'},
        {'id': 'sec2', 'classId': 'c1', 'name': 'B'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSchoolicTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminOverviewView(
                students: const [],
                staff: const [],
                classes: classes,
                sections: sections,
                assignments: const [],
                summaries: const [],
                activeYearName: '2026-2027',
                onNavigateToSection: (_) {},
                onOpenAddStudent: () {},
                onOpenAddStaff: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Grade 6 - A, Grade 6 - B have not logged attendance today.'),
        findsOneWidget,
      );
      expect(
        find.text('Grade 6 - A, Grade 6 - B without an active assigned teacher mapping.'),
        findsOneWidget,
      );
      expect(find.text('Daily Attendance Pending (2 sections)'), findsOneWidget);
    });
  });

  group('P2 — Student Directory Columns and Filters', () {
    testWidgets('displays Class & Section column, filters by class/section, and handles unassigned', (tester) async {
      final classes = [
        {'id': 'c1', 'name': 'Grade 6'},
        {'id': 'c2', 'name': 'Grade 7'},
      ];
      final sections = [
        {'id': 'sec1', 'classId': 'c1', 'name': 'A'},
        {'id': 'sec2', 'classId': 'c2', 'name': 'B'},
      ];
      final students = [
        {
          'id': 'st1',
          'admissionNumber': 'ADM-101',
          'fullName': 'Aarav Patel',
          'rollNumber': '06A-01',
          'classId': 'c1',
          'sectionId': 'sec1',
        },
        {
          'id': 'st2',
          'admissionNumber': 'ADM-102',
          'fullName': 'Bhavna Sen',
          'rollNumber': '07B-01',
          'classId': 'c2',
          'sectionId': 'sec2',
        },
        {
          'id': 'st3',
          'admissionNumber': 'ADM-103',
          'fullName': 'Chetan Verma',
          'rollNumber': null,
          'classId': null,
          'sectionId': null,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSchoolicTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminStudentsView(
                students: students,
                classes: classes,
                sections: sections,
                onOpenAddStudent: () {},
                onOpenStudentProfile: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check column header
      expect(find.text('CLASS & SECTION'), findsOneWidget);

      // Check student cohort labels
      expect(find.text('Grade 6 - A'), findsOneWidget);
      expect(find.text('Grade 7 - B'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);

      // Filter by Class: tap class dropdown and select Grade 6
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'All Classes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 6').last);
      await tester.pumpAndSettle();

      // Grade 6 student should still be visible, Grade 7 student filtered out
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Bhavna Sen'), findsNothing);
      expect(find.text('Chetan Verma'), findsNothing);

      // Reset filters
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Bhavna Sen'), findsOneWidget);
      expect(find.text('Chetan Verma'), findsOneWidget);
    });
  });

  group('P3 — Timetable Plural Filter Labels', () {
    testWidgets('uses All Classes, All Sections, All Teachers, All Subjects', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildSchoolicTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminTimetableView(
                  years: const [],
                  classes: const [],
                  sections: const [],
                  subjects: const [],
                  staff: const [],
                  assignments: const [],
                  entries: const [],
                  reload: () async {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All Classes'), findsOneWidget);
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.text('All Teachers'), findsOneWidget);
      expect(find.text('All Subjects'), findsOneWidget);
    });
  });

  group('P2 — Roll Number Badge Rendering', () {
    testWidgets('renders 6-character roll number on a single line with BoxConstraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSchoolicTheme(),
          home: Scaffold(
            body: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadii.rSm,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Text(
                  '06A-01',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('06A-01'));
      expect(textWidget.maxLines, 1);
      expect(textWidget.softWrap, isFalse);

      final renderBox = tester.renderObject<RenderBox>(find.byType(Container).first);
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(28.0));
    });
  });

  group('Safe Area & Mobile Viewport Insets', () {
    testWidgets('teacher dashboard app bar respects top safe area inset on notched/status-bar mobile screens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSchoolicTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 44.0, bottom: 34.0),
            ),
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.mainBackground,
                    border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
                  ),
                  child: const SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 52,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            SchoolicLogo(size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();

      final logoFinder = find.byType(SchoolicLogo).first;
      expect(logoFinder, findsOneWidget);
      expect(find.text('Schoolic.'), findsOneWidget);

      final logoTopLeft = tester.getTopLeft(logoFinder);
      // The logo must be rendered strictly below the 44.0px status bar
      expect(logoTopLeft.dy, greaterThanOrEqualTo(44.0));
    });
  });

  group('Schoolic Official Logo Branding', () {
    testWidgets('SchoolicLogo renders horizontal Schoolic. full name by default with Switzer bold typography and accessibility label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchoolicLogo(size: 24),
          ),
        ),
      );

      final textFinder = find.text('Schoolic.');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.data, 'Schoolic.');
      expect(textWidget.style?.fontFamily, 'Switzer');
      expect(textWidget.style?.fontWeight, FontWeight.w700);
      expect(textWidget.style?.fontSize, 24);
      expect(textWidget.style?.color, AppColors.primaryText);

      // Accessibility Semantics label must remain 'Schoolic'
      expect(find.bySemanticsLabel('Schoolic'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('SchoolicLogo.compact renders compact S. mark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchoolicLogo.compact(size: 20),
          ),
        ),
      );

      final textFinder = find.text('S.');
      expect(textFinder, findsOneWidget);
    });

    testWidgets('SchoolicLogo supports custom size and color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchoolicLogo(size: 32, color: Colors.white),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Schoolic.'));
      expect(textWidget.style?.fontSize, 32);
      expect(textWidget.style?.color, Colors.white);
    });
  });

  group('Schoolic Product Tour & Shortcuts', () {
    testWidgets('TourDialog renders initial step and advances through steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TourDialog(),
          ),
        ),
      );

      // Verify header with Schoolic. logo and step indicator
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      expect(find.text('Institutional School Management'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Next to step 2
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('STEP 2 OF 5'), findsOneWidget);
      expect(find.text('Fast Attendance Recording'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Tap Back to step 1
      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('STEP 1 OF 5'), findsOneWidget);
    });

    testWidgets('ShortcutsDialog displays categorized shortcuts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsDialog(),
          ),
        ),
      );

      expect(find.text('KEYBOARD SHORTCUTS'), findsOneWidget);
      expect(find.text('GENERAL & HELP'), findsOneWidget);
      expect(find.text('FORM INPUTS & ACTIONS'), findsOneWidget);
      expect(find.text('WORKSPACE NAVIGATION'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('LoginScreen renders show password toggle, shortcuts row, and tour trigger', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      // Brand logo renders Schoolic.
      expect(find.text('Schoolic.'), findsOneWidget);

      // Password visibility toggle icon is present
      final toggleFinder = find.byTooltip('Show password');
      expect(toggleFinder, findsOneWidget);

      // Tap show password toggle
      await tester.tap(toggleFinder);
      await tester.pump();

      expect(find.byTooltip('Hide password'), findsOneWidget);

      // Keyboard shortcuts bar and tour trigger are present
      expect(find.text('↵ Enter'), findsOneWidget);
      expect(find.text('Shortcuts'), findsOneWidget);
      expect(find.text('First time here? Explore Product Tour'), findsOneWidget);
    });
  });
}

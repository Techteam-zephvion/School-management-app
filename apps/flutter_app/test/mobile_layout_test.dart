import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schoolic/src/core/theme.dart';
import 'package:schoolic/src/features/admin/views/admin_settings_view.dart';
import 'package:schoolic/src/features/portal/portal_dashboard.dart';
import 'package:schoolic/src/features/shared/components/page_header.dart';
import 'package:schoolic/src/features/shared/views/announcements_view.dart';
import 'package:schoolic/src/features/teacher/views/teacher_attendance_view.dart';
import 'package:schoolic/src/features/teacher/views/teacher_classes_view.dart';
import 'package:schoolic/src/features/teacher/views/teacher_copilot_view.dart';
import 'package:schoolic/src/features/teacher/views/teacher_timetable_view.dart';

const _assignment = <String, Object?>{
  'id': 'assignment-1',
  'academicYearId': '10000000-0000-4000-8000-000000000101',
  'classId': '10000000-0000-4000-8000-000000000401',
  'sectionId': '10000000-0000-4000-8000-000000000501',
  'subjectId': '10000000-0000-4000-8000-000000000601',
  'className': 'Grade 6',
  'sectionName': 'A',
  'subjectName': 'Mathematics',
};

const _timetableEntry = <String, Object?>{
  'id': 'entry-1',
  'academicYearId': '10000000-0000-4000-8000-000000000101',
  'classId': '10000000-0000-4000-8000-000000000401',
  'sectionId': '10000000-0000-4000-8000-000000000501',
  'subjectId': '10000000-0000-4000-8000-000000000601',
  'className': 'Grade 6',
  'sectionName': 'A',
  'subjectName': 'Mathematics',
  'dayOfWeek': 1,
  'startTime': '09:00:00',
  'endTime': '09:40:00',
};

Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child,
) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildSchoolicTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PageHeader wraps actions at 360px', (tester) async {
    await _pumpAtWidth(
      tester,
      360,
      PageHeader(
        title: 'Attendance Register',
        description:
            'Record daily or period-based roll call with real-time totals.',
        primaryAction: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.check),
          label: const Text('Save attendance'),
        ),
      ),
    );

    expect(find.text('Attendance Register'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher My Week uses readable mobile lesson list', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      390,
      TeacherTimetableView(
        entries: const [_timetableEntry],
        onTakeAttendance: (_) {},
      ),
    );

    expect(find.text('Scheduled lessons'), findsOneWidget);
    expect(find.text('Grade 6 A'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher classes cards stack actions at phone width', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      390,
      TeacherClassesView(
        assignments: const [_assignment],
        onTakeAttendance: (_) {},
      ),
    );

    expect(find.text('View roster'), findsOneWidget);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Attendance register controls fit at 430px without selected roster',
    (tester) async {
      await _pumpAtWidth(
        tester,
        430,
        TeacherAttendanceView(
          assignments: const [_assignment],
          selectedAssignment: null,
          onAssignmentChanged: (_) {},
          onAttendanceSaved: () {},
        ),
      );

      expect(find.text('Attendance Register'), findsOneWidget);
      expect(find.text('Assigned section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Teacher Copilot stacks form and editor at 360px', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      360,
      const TeacherCopilotView(assignments: [_assignment]),
    );

    expect(find.text('Teacher Copilot'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin settings stack long values at phone width', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      390,
      const AdminSettingsView(
        years: [
          {'name': '2026-2027'},
        ],
        schoolName: 'Schoolic Synthetic Staging',
      ),
    );

    expect(find.text('System Settings'), findsOneWidget);
    expect(find.text('Institutional Configuration'), findsOneWidget);
    expect(
      find.text('Cloudflare Workers (Hono TypeScript Runtime)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher announcements composer fits phone width', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      390,
      const AnnouncementsView(
        workspace: AnnouncementWorkspace.teacher,
        endpoint: '/api/v1/teacher/announcements',
        assignments: [_assignment],
      ),
    );

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('New announcement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Student portal shell fits phone width without a session', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      390,
      const SizedBox(height: 700, child: PortalDashboard()),
    );

    expect(find.text('Student Portal'), findsOneWidget);
    expect(find.text('Please sign in to continue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

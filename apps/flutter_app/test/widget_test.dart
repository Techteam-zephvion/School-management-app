import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/core/models.dart';
import 'package:schoolic/src/core/theme.dart';
import 'package:schoolic/src/features/shared/components/attendance_status_button.dart';
import 'package:schoolic/src/features/shared/components/feedback_banner.dart';
import 'package:schoolic/src/features/shared/components/page_header.dart';
import 'package:schoolic/src/features/shared/components/stat_strip.dart';
import 'package:schoolic/src/features/shared/components/status_badge.dart';

void main() {
  test('auth session serializes roles and dev identity', () {
    const session = AuthSession(
      email: 'admin@schoolic.local',
      roles: [AppRole.admin],
      schoolId: 'school-1',
      devNeonUserId: 'dev-admin',
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.email, 'admin@schoolic.local');
    expect(restored.isAdmin, isTrue);
    expect(restored.devNeonUserId, 'dev-admin');
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
}

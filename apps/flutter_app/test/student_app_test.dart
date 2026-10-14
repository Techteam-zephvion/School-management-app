import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schoolic/src/features/student/components/digital_id_card.dart';
import 'package:schoolic/src/features/student/components/homework_submission_sheet.dart';
import 'package:schoolic/src/features/student/student_app_view.dart';

void main() {
  testWidgets('DigitalIdCard renders student info, school code, and QR correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DigitalIdCard(
            schoolName: 'Schoolic Synthetic Staging',
            schoolCode: 'STAGE-001',
            fullName: 'Aarav Sharma',
            admissionNumber: 'SCH-2026-0042',
            rollNumber: '01',
            className: '=Stage Class',
            sectionName: 'A',
            academicYear: '2026-2027',
            guardianName: 'Rajesh Sharma',
            guardianPhone: '+91 98765 43210',
          ),
        ),
      ),
    );

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('SCHOOLIC SYNTHETIC STAGING'), findsOneWidget);
    expect(find.text('Adm: SCH-2026-0042  •  Roll: 01'), findsOneWidget);
    expect(find.text('STUDENT ID'), findsOneWidget);
    expect(find.text('Emergency Contact: +91 98765 43210'), findsOneWidget);
  });

  testWidgets('HomeworkSubmissionSheet renders assignment instructions and input field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeworkSubmissionSheet(
              assignmentId: 'test-assign-1',
              assignmentTitle: 'Trigonometric Problem Set',
              subjectName: 'Mathematics',
              dueDate: '2026-10-20',
              instructions: 'Solve problems 1 to 5 from chapter 4.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Trigonometric Problem Set'), findsOneWidget);
    expect(find.text('MATHEMATICS'), findsOneWidget);
    expect(find.text('Solve problems 1 to 5 from chapter 4.'), findsOneWidget);
    expect(find.text('Submit Homework'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('StudentAppView renders bottom navigation and tabs on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StudentAppView(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Grades'), findsOneWidget);
    expect(find.text('ID & Fees'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/features/docs/docs_data.dart';
import 'package:schoolic/src/features/docs/docs_page.dart';
import 'package:schoolic/src/features/docs/docs_screenshot_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocsCatalog & Data Model Tests', () {
    test('contains comprehensive feature catalog with all operational modules', () {
      expect(DocsCatalog.features.length, greaterThanOrEqualTo(22));

      for (final feature in DocsCatalog.features) {
        expect(feature.id.isNotEmpty, isTrue);
        expect(feature.title.isNotEmpty, isTrue);
        expect(feature.summary.isNotEmpty, isTrue);
        expect(feature.roles.isNotEmpty, isTrue);
        expect(feature.howToUse.isNotEmpty, isTrue);
        for (final step in feature.howToUse) {
          expect(step.stepNumber, greaterThan(0));
          expect(step.title.isNotEmpty, isTrue);
          expect(step.description.isNotEmpty, isTrue);
        }
      }
    });

    test('filters features by keyword search across titles and steps', () {
      final cashfreeMatches = DocsCatalog.filter(query: 'Cashfree');
      expect(cashfreeMatches.any((f) => f.id == 'fees_cashfree'), isTrue);

      final attendanceMatches = DocsCatalog.filter(query: 'Attendance');
      expect(attendanceMatches.any((f) => f.id == 'attendance'), isTrue);

      final biometricsMatches = DocsCatalog.filter(query: 'Turnstile');
      expect(biometricsMatches.any((f) => f.id == 'biometrics_terminals'), isTrue);
    });

    test('filters features by target role', () {
      final accountantFeatures = DocsCatalog.filter(role: DocRole.accountant);
      expect(accountantFeatures.every((f) => f.roles.contains(DocRole.accountant)), isTrue);
      expect(accountantFeatures.any((f) => f.id == 'fees_cashfree'), isTrue);

      final teacherFeatures = DocsCatalog.filter(role: DocRole.teacher);
      expect(teacherFeatures.every((f) => f.roles.contains(DocRole.teacher)), isTrue);
    });

    test('filters features by category', () {
      final campusFeatures = DocsCatalog.filter(category: DocCategory.campus);
      expect(campusFeatures.every((f) => f.category == DocCategory.campus), isTrue);
      expect(campusFeatures.any((f) => f.id == 'library_circulation'), isTrue);
    });
  });

  group('DocsPage Widget Tests', () {
    testWidgets('renders top bar, search input, role filters, and step guide without upload buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DocsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title badge
      expect(find.text('DOCUMENTATION & HOW-TO GUIDE'), findsOneWidget);

      // Search field
      expect(find.byType(TextField), findsOneWidget);

      // Role filter chips
      expect(find.text('All Roles'), findsOneWidget);
      expect(find.text('Administrator'), findsWidgets);
      expect(find.text('Teacher'), findsWidgets);

      // Feature title & executive summary
      expect(find.text('Institutional Overview & Command Center'), findsWidgets);
      expect(find.text('How To Use It: Step-by-Step Process'), findsOneWidget);

      // Ensure NO user-facing upload buttons or gallery exist
      expect(find.text('Upload Screenshot'), findsNothing);
      expect(find.text('Screenshots & Visual Guides'), findsNothing);
    });

    testWidgets('search filters list of features dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DocsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term
      await tester.enterText(find.byType(TextField), 'Cashfree');
      await tester.pumpAndSettle();

      // Check results
      expect(find.text('Fees, Billing & Cashfree Payment Gateway'), findsWidgets);
    });

    testWidgets('DocsScreenshotViewer displays caption and close button', (tester) async {
      final mockScreenshot = DocScreenshot(
        id: 'test-1',
        featureId: 'attendance',
        fileName: 'attendance_sheet.png',
        caption: 'Daily Roll Call Register',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DocsScreenshotViewer.show(
                  context,
                  screenshot: mockScreenshot,
                ),
                child: const Text('Open Lightbox'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Lightbox'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Roll Call Register'), findsWidgets);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}

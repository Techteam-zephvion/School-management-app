import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/features/legal/privacy_policy_view.dart';

void main() {
  testWidgets('PrivacyPolicyView renders header, package ID, and switches tabs',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PrivacyPolicyView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Package ID
    expect(find.text('Schoolic Legal & Compliance'), findsOneWidget);
    expect(find.textContaining('com.zephvion.schoolic'), findsOneWidget);
    expect(find.text('Zero Third-Party Ads Guarantee'), findsOneWidget);
    expect(find.textContaining('privacy@zephvion.com'), findsWidgets);

    // Switch to Data Safety tab
    await tester.tap(find.text('Data Safety'));
    await tester.pumpAndSettle();

    expect(find.text('Google Play Data Safety Disclosures'), findsOneWidget);
    expect(find.text('Data Encrypted in Transit: All data transfers between the mobile app and edge API use TLS 1.3 / HTTPS encryption.'), findsOneWidget);

    // Switch to Terms of Service tab
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.text('1. Acceptance of Terms'), findsOneWidget);
  });
}

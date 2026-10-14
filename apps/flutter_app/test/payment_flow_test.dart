import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/features/student/components/fee_payment_sheet.dart';
import 'package:schoolic/src/features/student/components/fee_receipt_modal.dart';
import 'package:schoolic/src/features/student/utils/fee_receipt_pdf.dart';

void main() {
  testWidgets('FeePaymentSheet renders payment options, full and custom amounts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FeePaymentSheet.show(
                    context,
                    allocationId: '00000000-0000-4000-8000-000000000001',
                    feeName: 'Term 1 Tuition Fee',
                    totalAmount: 25000,
                    paidAmount: 10000,
                    balanceDue: 15000,
                    studentName: 'Aarav Sharma',
                    admissionNumber: 'SCH-2026-001',
                  );
                },
                child: const Text('Open Payment'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Fee Payment Checkout'), findsOneWidget);
    expect(find.text('Term 1 Tuition Fee • Aarav Sharma'), findsOneWidget);
    expect(find.text('₹25000'), findsOneWidget); // Total billed
    expect(find.text('₹10000'), findsOneWidget); // Paid so far
    expect(find.text('₹15000'), findsNWidgets(2)); // Balance due & full payment radio
    expect(find.text('Pay Full Balance Due'), findsOneWidget);
    expect(find.text('Pay Custom Partial Amount'), findsOneWidget);
    expect(find.text('Proceed to Pay ₹15000'), findsOneWidget);

    // Switch to Custom Partial Payment
    await tester.tap(find.text('Pay Custom Partial Amount'));
    await tester.pumpAndSettle();

    expect(find.text('Enter amount to pay'), findsOneWidget);

    // Enter custom installment ₹5000
    await tester.enterText(find.byType(TextField), '5000');
    await tester.pumpAndSettle();

    expect(find.text('Proceed to Pay ₹5000'), findsOneWidget);
  });

  testWidgets('FeeReceiptModal displays official institutional receipt details', (tester) async {
    const receiptData = FeeReceiptData(
      schoolName: 'Delhi Public Academy',
      receiptNumber: 'REC-2026-00042',
      studentName: 'Diya Patel',
      admissionNumber: 'DPA-1042',
      className: 'Grade 10',
      sectionName: 'A',
      feeName: 'Annual Composite Fee',
      amountPaid: 12500,
      paymentMethod: 'upi',
      paidAt: '2026-10-14 10:30',
      transactionReference: 'SCH_ORDER_99182',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeeReceiptModal(receiptData: receiptData),
        ),
      ),
    );

    expect(find.text('Delhi Public Academy'), findsOneWidget);
    expect(find.text('Institutional Fee Receipt'), findsOneWidget);
    expect(find.text('REC-2026-00042'), findsOneWidget);
    expect(find.text('Diya Patel'), findsOneWidget);
    expect(find.text('DPA-1042'), findsOneWidget);
    expect(find.text('Grade 10 - A'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('₹12500'), findsOneWidget);
    expect(find.text('Print / PDF'), findsOneWidget);
  });
}

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FeeReceiptData {
  const FeeReceiptData({
    required this.schoolName,
    required this.receiptNumber,
    required this.studentName,
    required this.admissionNumber,
    required this.className,
    required this.sectionName,
    required this.feeName,
    required this.amountPaid,
    required this.paymentMethod,
    required this.paidAt,
    this.transactionReference,
    this.notes,
  });

  final String schoolName;
  final String receiptNumber;
  final String studentName;
  final String admissionNumber;
  final String className;
  final String sectionName;
  final String feeName;
  final int amountPaid;
  final String paymentMethod;
  final String paidAt;
  final String? transactionReference;
  final String? notes;
}

Future<Uint8List> buildFeeReceiptPdf(FeeReceiptData data) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Regular.ttf'));
  final semiBold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Semibold.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Bold.ttf'));
  final document = pw.Document();

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(24),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.schoolName.toUpperCase(),
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 18,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'OFFICIAL INSTITUTIONAL FEE RECEIPT',
                        style: pw.TextStyle(
                          font: semiBold,
                          fontSize: 11,
                          color: PdfColors.blue700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green600),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'STATUS: PAID',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: PdfColors.green800,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 16),

              // Receipt Meta
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Receipt Number:', style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(data.receiptNumber, style: pw.TextStyle(font: bold, fontSize: 12)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date & Time:', style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(data.paidAt, style: pw.TextStyle(font: semiBold, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Student Details Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Student Name', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey600)),
                        pw.Text(data.studentName, style: pw.TextStyle(font: bold, fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Admission No.', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey600)),
                        pw.Text(data.admissionNumber, style: pw.TextStyle(font: semiBold, fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Class & Section', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey600)),
                        pw.Text(
                          data.sectionName.isNotEmpty
                              ? '${data.className} - ${data.sectionName}'
                              : data.className,
                          style: pw.TextStyle(font: semiBold, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Item Breakdown Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description', style: pw.TextStyle(font: bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Mode', style: pw.TextStyle(font: bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(data.feeName, style: pw.TextStyle(font: semiBold, fontSize: 11)),
                            if (data.transactionReference != null && data.transactionReference!.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Text('Ref: ${data.transactionReference}', style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey600)),
                            ],
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(data.paymentMethod.toUpperCase(), style: pw.TextStyle(font: regular, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text('₹${data.amountPaid}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Total Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total Paid: ', style: pw.TextStyle(font: bold, fontSize: 13)),
                  pw.Text('₹${data.amountPaid}', style: pw.TextStyle(font: bold, fontSize: 15, color: PdfColors.blueGrey900)),
                ],
              ),
              pw.Spacer(),

              // Footer Note & Stamp
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a computer-generated institutional receipt verified via Cashfree PG.',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Schoolic Smart Campus',
                    style: pw.TextStyle(font: semiBold, fontSize: 8, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  return document.save();
}

Future<void> printOrShareFeeReceipt(FeeReceiptData data) async {
  final bytes = await buildFeeReceiptPdf(data);
  await Printing.layoutPdf(
    name: 'Receipt_${data.receiptNumber}.pdf',
    onLayout: (format) async => bytes,
  );
}

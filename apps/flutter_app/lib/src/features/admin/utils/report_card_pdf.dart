import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportCardPdfData {
  const ReportCardPdfData({
    required this.schoolName,
    required this.schoolAffiliation,
    required this.schoolAddress,
    required this.studentName,
    required this.admissionNumber,
    this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.termName,
    required this.schemeName,
    required this.board,
    required this.overallPercentage,
    required this.overallGrade,
    this.overallGradePoint,
    required this.attendanceRate,
    required this.resultStatus,
    required this.scholasticRows,
    required this.coScholasticRows,
    this.teacherRemarks,
    this.principalRemarks,
    required this.issueDate,
  });

  final String schoolName;
  final String schoolAffiliation;
  final String schoolAddress;
  final String studentName;
  final String admissionNumber;
  final String? rollNumber;
  final String className;
  final String sectionName;
  final String termName;
  final String schemeName;
  final String board;
  final String overallPercentage;
  final String overallGrade;
  final String? overallGradePoint;
  final String attendanceRate;
  final String resultStatus;
  final List<Map<String, Object?>> scholasticRows;
  final List<Map<String, Object?>> coScholasticRows;
  final String? teacherRemarks;
  final String? principalRemarks;
  final String issueDate;
}

Future<Uint8List> buildReportCardPdf(ReportCardPdfData data) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Regular.ttf'));
  final semiBold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Semibold.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Bold.ttf'));
  final document = pw.Document();

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    italic: regular,
    boldItalic: semiBold,
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      build: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      data.schoolName.toUpperCase(),
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${data.schoolAffiliation} | ${data.schoolAddress}',
                      style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey900,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'OFFICIAL ACADEMIC REPORT CARD — ${data.termName.toUpperCase()} (${data.board.toUpperCase()})',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 10,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Student Demographics Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('STUDENT NAME', data.studentName, bold, regular),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('ADMISSION NO.', data.admissionNumber, bold, regular),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('CLASS & SECTION', '${data.className} — ${data.sectionName}', bold, regular),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('ROLL NUMBER', data.rollNumber ?? '—', bold, regular),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('SCHEME', data.schemeName, bold, regular),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('ATTENDANCE', data.attendanceRate, bold, regular),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Part 1: Scholastic Areas Table
              pw.Text(
                'PART 1: SCHOLASTIC PERFORMANCE',
                style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeader('SUBJECT', bold),
                      _tableHeader('MAX', bold),
                      _tableHeader('OBTAINED', bold),
                      _tableHeader('PERCENT', bold),
                      _tableHeader('GRADE', bold),
                      _tableHeader('GP', bold),
                    ],
                  ),
                  ...data.scholasticRows.map((row) {
                    final subName = '${row['subjectName'] ?? 'General'}';
                    final max = '${row['maxMarks'] ?? 100}';
                    final obt = '${row['marksObtained'] ?? 0}';
                    final pct = '${row['percentage'] ?? 0}%';
                    final grade = '${row['grade'] ?? '—'}';
                    final gp = '${row['gradePoint'] ?? '—'}';
                    return pw.TableRow(
                      children: [
                        _tableCell(subName, regular, align: pw.TextAlign.left),
                        _tableCell(max, regular),
                        _tableCell(obt, bold),
                        _tableCell(pct, regular),
                        _tableCell(grade, bold, color: PdfColors.blue800),
                        _tableCell(gp, regular),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 14),

              // Part 2: Co-Scholastic Activities
              pw.Text(
                'PART 2: CO-SCHOLASTIC & DISCIPLINE ASSESSMENT (3-POINT SCALE A/B/C)',
                style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableHeader('ACTIVITY DOMAIN', bold),
                      _tableHeader('GRADE', bold),
                      _tableHeader('DESCRIPTIVE INDICATORS', bold),
                    ],
                  ),
                  ...data.coScholasticRows.map((row) {
                    return pw.TableRow(
                      children: [
                        _tableCell('${row['area'] ?? ''}', regular, align: pw.TextAlign.left),
                        _tableCell('${row['grade'] ?? 'A'}', bold, color: PdfColors.green800),
                        _tableCell('${row['remarks'] ?? 'Active participation'}', regular, align: pw.TextAlign.left),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 14),

              // Summary & Result Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  border: pw.Border.all(color: PdfColors.blueGrey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'OVERALL: ${data.overallPercentage} | GRADE: ${data.overallGrade} ${data.overallGradePoint != null ? "($data.overallGradePoint GP)" : ""}',
                      style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.blueGrey900),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: data.resultStatus.toLowerCase().contains('fail') ? PdfColors.red800 : PdfColors.green800,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'RESULT: ${data.resultStatus.toUpperCase()}',
                        style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                  ],
                ),
              ),

              if (data.teacherRemarks != null && data.teacherRemarks!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Teacher Remarks: ${data.teacherRemarks}',
                  style: pw.TextStyle(font: regular, fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ],

              pw.Spacer(),

              // Signature footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureLine('Class Teacher Signature', bold, regular),
                  _signatureLine('Exam Controller', bold, regular),
                  _signatureLine('Principal / Head of Institution', bold, regular),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Issued on: ${data.issueDate} | System-generated by Schoolic Academic Suite',
                  style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return document.save();
}

pw.Widget _buildLabelValue(String label, String value, pw.Font bold, pw.Font regular) {
  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.grey800),
        ),
        pw.TextSpan(
          text: value,
          style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.blueGrey900),
        ),
      ],
    ),
  );
}

pw.Widget _tableHeader(String text, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.blueGrey900),
    ),
  );
}

pw.Widget _tableCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.center, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: font, fontSize: 8, color: color ?? PdfColors.blueGrey900),
    ),
  );
}

pw.Widget _signatureLine(String title, pw.Font bold, pw.Font regular) {
  return pw.Column(
    children: [
      pw.Container(width: 130, height: 1, color: PdfColors.grey700),
      pw.SizedBox(height: 3),
      pw.Text(title, style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey800)),
    ],
  );
}

Future<void> printOrShareReportCard(ReportCardPdfData data) async {
  final pdfBytes = await buildReportCardPdf(data);
  await Printing.layoutPdf(
    onLayout: (_) async => pdfBytes,
    name: 'ReportCard_${data.admissionNumber}_${data.termName}.pdf',
  );
}

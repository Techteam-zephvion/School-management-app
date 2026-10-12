import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TeachingMaterialPdfData {
  const TeachingMaterialPdfData({
    required this.type,
    required this.title,
    required this.topic,
    required this.overview,
    required this.sections,
    required this.checksForUnderstanding,
    required this.teacherNotes,
    this.className,
    this.sectionName,
    this.subjectName,
    this.language = 'English',
  });

  final String type;
  final String title;
  final String topic;
  final String overview;
  final List<TeachingMaterialSection> sections;
  final List<String> checksForUnderstanding;
  final List<String> teacherNotes;
  final String? className;
  final String? sectionName;
  final String? subjectName;
  final String language;
}

class TeachingMaterialSection {
  const TeachingMaterialSection({
    required this.heading,
    required this.items,
  });

  final String heading;
  final List<String> items;
}

enum TeachingMaterialExportMode {
  student,
  answerKey,
}

Future<Uint8List> buildTeachingMaterialPdf(
  TeachingMaterialPdfData data, {
  required TeachingMaterialExportMode mode,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Regular.ttf'));
  final semiBold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Semibold.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/switzer/Switzer-Bold.ttf'));
  final document = pw.Document();
  final isAnswerKey = mode == TeachingMaterialExportMode.answerKey;

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 44, 42, 46),
      theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: regular, boldItalic: semiBold),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        _header(data, isAnswerKey: isAnswerKey, semiBold: semiBold, bold: bold),
        pw.SizedBox(height: 18),
        if (isAnswerKey)
          _answerKey(data, semiBold: semiBold)
        else ...[
          _section('Overview', [data.overview], semiBold: semiBold),
          ...data.sections.map((section) => _section(section.heading, section.items, semiBold: semiBold, numbered: _isQuestionSection(data.type))),
          if (data.checksForUnderstanding.isNotEmpty)
            _section('Checks for Understanding', data.checksForUnderstanding, semiBold: semiBold),
        ],
      ],
    ),
  );

  return document.save();
}

Future<void> downloadTeachingMaterialPdf(
  TeachingMaterialPdfData data, {
  required TeachingMaterialExportMode mode,
}) async {
  final bytes = await buildTeachingMaterialPdf(data, mode: mode);
  await Printing.sharePdf(bytes: bytes, filename: teachingMaterialFilename(data, mode: mode));
}

Future<void> printTeachingMaterialPdf(
  TeachingMaterialPdfData data, {
  required TeachingMaterialExportMode mode,
}) async {
  await Printing.layoutPdf(
    name: teachingMaterialFilename(data, mode: mode),
    format: PdfPageFormat.a4,
    onLayout: (_) => buildTeachingMaterialPdf(data, mode: mode),
  );
}

String teachingMaterialFilename(
  TeachingMaterialPdfData data, {
  required TeachingMaterialExportMode mode,
}) {
  final suffix = mode == TeachingMaterialExportMode.answerKey ? 'answer-key' : 'student';
  final base = '${_typeLabel(data.type)}-${data.title}-$suffix'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${base.isEmpty ? 'schoolic-material' : base}.pdf';
}

bool hasAnswerKey(TeachingMaterialPdfData data) => data.teacherNotes.isNotEmpty;

pw.Widget _header(TeachingMaterialPdfData data, {required bool isAnswerKey, required pw.Font semiBold, required pw.Font bold}) {
  final context = [
    if (data.className != null) data.className!,
    if (data.sectionName != null) data.sectionName!,
    if (data.subjectName != null) data.subjectName!,
  ].join(' - ');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(isAnswerKey ? '${data.title} - Answer Key' : data.title, style: pw.TextStyle(font: bold, fontSize: 22)),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          _meta('Type', _typeLabel(data.type), semiBold),
          _meta('Topic', data.topic, semiBold),
          if (context.isNotEmpty) _meta('Class', context, semiBold),
          _meta('Language', data.language, semiBold),
        ],
      ),
      pw.Divider(color: PdfColors.grey400, height: 24),
    ],
  );
}

pw.Widget _meta(String label, String value, pw.Font semiBold) {
  return pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: '$label: ', style: pw.TextStyle(font: semiBold, fontSize: 10, color: PdfColors.grey800)),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
      ],
    ),
  );
}

pw.Widget _section(String heading, List<String> items, {required pw.Font semiBold, bool numbered = false}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Header(
        level: 1,
        margin: const pw.EdgeInsets.only(top: 6, bottom: 8),
        child: pw.Text(heading, style: pw.TextStyle(font: semiBold, fontSize: 14)),
      ),
      ...items.asMap().entries.map((entry) {
        final prefix = numbered ? '${entry.key + 1}. ' : '- ';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text('$prefix${entry.value}', style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        );
      }),
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget _answerKey(TeachingMaterialPdfData data, {required pw.Font semiBold}) {
  if (data.teacherNotes.isEmpty) {
    return _section('Answer Key', ['No answer key was generated for this draft.'], semiBold: semiBold);
  }
  return _section('Answer Key and Teacher Notes', data.teacherNotes, semiBold: semiBold, numbered: data.type == 'quiz' || data.type == 'worksheet');
}

bool _isQuestionSection(String type) => type == 'quiz' || type == 'worksheet';

String _typeLabel(String type) {
  return switch (type) {
    'lesson_plan' => 'Lesson Plan',
    'worksheet' => 'Worksheet',
    'quiz' => 'Quiz',
    _ => type,
  };
}

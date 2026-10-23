import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../utils/teaching_material_pdf.dart';

class TeacherCopilotView extends ConsumerStatefulWidget {
  const TeacherCopilotView({required this.assignments, super.key});

  final List<Map<String, Object?>> assignments;

  @override
  ConsumerState<TeacherCopilotView> createState() => _TeacherCopilotViewState();
}

class _TeacherCopilotViewState extends ConsumerState<TeacherCopilotView> {
  final _topic = TextEditingController();
  final _instructions = TextEditingController();
  final _durationController = TextEditingController(text: '40');
  final _questionCountController = TextEditingController(text: '10');
  final _languageController = TextEditingController(text: 'English');
  final _titleController = TextEditingController();
  final _overviewController = TextEditingController();
  final _sectionsController = TextEditingController();
  final _checksController = TextEditingController();
  final _notesController = TextEditingController();

  String _outputType = 'lesson_plan';
  String _difficulty = 'standard';
  int _duration = 40;
  int _questionCount = 10;
  Map<String, Object?>? _assignment;
  Map<String, Object?>? _currentDraft;
  List<Map<String, Object?>> _saved = [];
  bool _generating = false;
  bool _saving = false;
  bool _loadingSaved = true;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignments.isEmpty ? null : widget.assignments.first;
    _loadSaved();
  }

  @override
  void didUpdateWidget(covariant TeacherCopilotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_assignment == null && widget.assignments.isNotEmpty) {
      _assignment = widget.assignments.first;
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _instructions.dispose();
    _durationController.dispose();
    _questionCountController.dispose();
    _languageController.dispose();
    _titleController.dispose();
    _overviewController.dispose();
    _sectionsController.dispose();
    _checksController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() => _loadingSaved = false);
      return;
    }
    setState(() => _loadingSaved = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .getList('/api/v1/teacher/materials', session: session);
      setState(() => _saved = response);
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _generate() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _generating) return;
    setState(() {
      _generating = true;
      _error = null;
      _notice = null;
    });
    try {
      final assignment = _assignment;
      final response = await ref.read(apiClientProvider).postJson(
        '/api/v1/teacher/ai/copilot',
        {
          'outputType': _outputType,
          'topic': _topic.text.trim(),
          'durationMinutes': _duration,
          'questionCount': _questionCount,
          'difficulty': _difficulty,
          'language': _languageController.text.trim().isEmpty
              ? 'English'
              : _languageController.text.trim(),
          if (_instructions.text.trim().isNotEmpty)
            'instructions': _instructions.text.trim(),
          if (assignment?['classId'] != null) 'classId': assignment!['classId'],
          if (assignment?['sectionId'] != null)
            'sectionId': assignment!['sectionId'],
          if (assignment?['subjectId'] != null)
            'subjectId': assignment!['subjectId'],
        },
        session: session,
      );
      _applyDraft({
        ...response,
        'type': _outputType,
        'topic': _topic.text.trim(),
        'difficulty': _difficulty,
        'language': _languageController.text.trim().isEmpty
            ? 'English'
            : _languageController.text.trim(),
        'durationMinutes': _duration,
        'questionCount': _questionCount,
      }, saved: false);
      setState(
        () => _notice = 'Draft generated. Review and edit it before saving.',
      );
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _saving || _titleController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final body = _materialPayload();
      final id = _currentDraft?['id'];
      final response = id == null
          ? await ref
                .read(apiClientProvider)
                .postJson('/api/v1/teacher/materials', body, session: session)
          : await ref
                .read(apiClientProvider)
                .patchJson(
                  '/api/v1/teacher/materials/$id',
                  body,
                  session: session,
                );
      _applyDraft(response, saved: true);
      await _loadSaved();
      setState(() => _notice = 'Draft saved.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSaved(Map<String, Object?> material) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .getJson(
            '/api/v1/teacher/materials/${material['id']}',
            session: session,
          );
      _applyDraft(response, saved: true);
      setState(() {
        _notice = 'Draft opened.';
        _error = null;
      });
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    }
  }

  Future<void> _deleteCurrent() async {
    final session = ref.read(authControllerProvider).session;
    final id = _currentDraft?['id'];
    if (session == null || id == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/api/v1/teacher/materials/$id', session: session);
      _clearDraft();
      await _loadSaved();
      setState(() => _notice = 'Draft deleted.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    }
  }

  Future<void> _downloadStudentPdf() async {
    await downloadTeachingMaterialPdf(
      _pdfData(),
      mode: TeachingMaterialExportMode.student,
    );
  }

  Future<void> _printStudentPdf() async {
    await printTeachingMaterialPdf(
      _pdfData(),
      mode: TeachingMaterialExportMode.student,
    );
  }

  Future<void> _downloadAnswerKeyPdf() async {
    final data = _pdfData();
    if (!hasAnswerKey(data)) {
      setState(
        () => _notice = 'This draft does not include a generated answer key.',
      );
      return;
    }
    await downloadTeachingMaterialPdf(
      data,
      mode: TeachingMaterialExportMode.answerKey,
    );
  }

  Future<void> _printAnswerKeyPdf() async {
    final data = _pdfData();
    if (!hasAnswerKey(data)) {
      setState(
        () => _notice = 'This draft does not include a generated answer key.',
      );
      return;
    }
    await printTeachingMaterialPdf(
      data,
      mode: TeachingMaterialExportMode.answerKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _generating || _saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Teacher Copilot',
          description: 'Generate, edit, save, and reopen teaching drafts from your assigned class context.',
          primaryAction: FilledButton.icon(
            onPressed: busy ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(_generating ? 'Generating...' : 'Generate draft'),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          FeedbackBanner(
            message: _error!,
            tone: FeedbackTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
        if (_notice != null)
          FeedbackBanner(
            message: _notice!,
            tone: FeedbackTone.success,
            onDismiss: () => setState(() => _notice = null),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final isPhone = constraints.maxWidth < 560;
            final form = _leftPanel(isPhone: isPhone);
            final editor = _editorPanel(isPhone: isPhone);
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, const SizedBox(height: 16), editor],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 330, child: form),
                const SizedBox(width: 16),
                Expanded(child: editor),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _leftPanel({required bool isPhone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          isPhone: isPhone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Generate', style: AppTypography.subsectionHeading),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
              const SizedBox(height: 10),
              _dropdown('Type', _outputType, const {
                'lesson_plan': 'Lesson plan',
                'worksheet': 'Worksheet',
                'quiz': 'Quiz',
              }, (value) => setState(() => _outputType = value ?? _outputType)),
              const SizedBox(height: 10),
              _dropdown('Difficulty', _difficulty, const {
                'introductory': 'Introductory',
                'standard': 'Standard',
                'advanced': 'Advanced',
              }, (value) => setState(() => _difficulty = value ?? _difficulty)),
              const SizedBox(height: 10),
              DropdownButtonFormField<Map<String, Object?>?>(
                initialValue: _assignment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned context',
                ),
                items: widget.assignments.map((assignment) {
                  return DropdownMenuItem<Map<String, Object?>?>(
                    value: assignment,
                    child: Text(
                      '${assignment['className']} ${assignment['sectionName']} - ${assignment['subjectName'] ?? 'General'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _assignment = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _duration = int.tryParse(value) ?? _duration,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _questionCountController,
                      decoration: const InputDecoration(labelText: 'Questions'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _questionCount =
                          int.tryParse(value) ?? _questionCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _languageController,
                decoration: const InputDecoration(labelText: 'Language'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _instructions,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Objectives or instructions',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          isPhone: isPhone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Saved Drafts', style: AppTypography.subsectionHeading),
              const SizedBox(height: 10),
              if (_loadingSaved)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_saved.isEmpty)
                const Text(
                  'No saved drafts yet.',
                  style: AppTypography.bodySecondary,
                )
              else
                ..._saved.map(_savedTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editorPanel({required bool isPhone}) {
    final hasDraft = _currentDraft != null || _titleController.text.isNotEmpty;
    if (!hasDraft) {
      return _panel(
        isPhone: isPhone,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Generate a draft or open a saved one. Copilot drafts remain private to your teacher account until you edit or delete them.',
            style: AppTypography.bodySecondary,
          ),
        ),
      );
    }

    return _panel(
      isPhone: isPhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: isPhone ? double.infinity : 180,
                child: Text(
                  'Draft Editor',
                  style: AppTypography.subsectionHeading,
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_currentDraft?['id'] == null ? 'Save' : 'Update'),
              ),
              if (_currentDraft?['id'] != null)
                TextButton.icon(
                  onPressed: _deleteCurrent,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _downloadStudentPdf,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Student PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _printStudentPdf,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print Student'),
              ),
              if (_outputType == 'worksheet' || _outputType == 'quiz') ...[
                OutlinedButton.icon(
                  onPressed: _downloadAnswerKeyPdf,
                  icon: const Icon(Icons.key_outlined, size: 16),
                  label: const Text('Answer Key PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _printAnswerKeyPdf,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print Key'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _overviewController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Overview'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sectionsController,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(labelText: 'Sections'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _checksController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Checks for understanding',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Teacher notes and answer key',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _documentPreview(isPhone: isPhone),
        ],
      ),
    );
  }

  Widget _documentPreview({required bool isPhone}) {
    final sections = _parseSections(_sectionsController.text);
    final checks = _plainLines(_checksController.text);
    final notes = _plainLines(_notesController.text);
    return Container(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: AppTypography.subsectionHeading),
          const SizedBox(height: 14),
          Text(
            _titleController.text.trim().isEmpty
                ? 'Untitled draft'
                : _titleController.text.trim(),
            style: AppTypography.sectionHeading,
          ),
          const SizedBox(height: 6),
          Text(_previewMeta(), style: AppTypography.metadata),
          const Divider(height: 28, color: AppColors.primaryBorder),
          _previewSection('Overview', [_overviewController.text.trim()]),
          ...sections.map(
            (section) => _previewSection(
              '${section['heading']}',
              ((section['items'] as List?) ?? const [])
                  .map((e) => '$e')
                  .toList(),
            ),
          ),
          if (checks.isNotEmpty)
            _previewSection('Checks for Understanding', checks),
          if ((_outputType == 'worksheet' || _outputType == 'quiz') &&
              notes.isNotEmpty)
            _previewSection('Teacher Answer Key', notes, teacherOnly: true),
        ],
      ),
    );
  }

  Widget _previewSection(
    String title,
    List<String> items, {
    bool teacherOnly = false,
  }) {
    final cleanItems = items.where((item) => item.trim().isNotEmpty).toList();
    if (cleanItems.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.bodyMedium)),
              if (teacherOnly)
                const Text('Teacher only', style: AppTypography.metadata),
            ],
          ),
          const SizedBox(height: 6),
          ...cleanItems.asMap().entries.map((entry) {
            final prefix =
                (_outputType == 'worksheet' || _outputType == 'quiz') &&
                    !teacherOnly
                ? '${entry.key + 1}. '
                : '- ';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$prefix${entry.value}', style: AppTypography.body),
            );
          }),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, bool isPhone = false}) {
    return Container(
      padding: EdgeInsets.all(isPhone ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: child,
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _savedTile(Map<String, Object?> material) {
    return InkWell(
      onTap: () => _openSaved(material),
      borderRadius: AppRadii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${material['title']}',
              style: AppTypography.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${_typeLabel('${material['type']}')} - ${material['className'] ?? 'No class'} ${material['sectionName'] ?? ''}',
              style: AppTypography.metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _applyDraft(Map<String, Object?> draft, {required bool saved}) {
    final content = ((draft['content'] as Map?) ?? draft)
        .cast<String, Object?>();
    final sections = ((content['sections'] as List?) ?? const [])
        .cast<Map<String, Object?>>();
    final checks = ((content['checksForUnderstanding'] as List?) ?? const [])
        .map((e) => '$e')
        .toList();
    final notes = ((content['teacherNotes'] as List?) ?? const [])
        .map((e) => '$e')
        .toList();

    setState(() {
      _currentDraft = saved ? draft : {'metadata': draft['metadata']};
      _titleController.text = '${draft['title'] ?? ''}';
      _overviewController.text = '${content['overview'] ?? ''}';
      _sectionsController.text = sections
          .map((section) {
            final items = ((section['items'] as List?) ?? const [])
                .map((e) => '- $e')
                .join('\n');
            return '## ${section['heading']}\n$items';
          })
          .join('\n\n');
      _checksController.text = checks.map((item) => '- $item').join('\n');
      _notesController.text = notes.map((item) => '- $item').join('\n');
      _outputType = '${draft['type'] ?? _outputType}';
      _difficulty = '${draft['difficulty'] ?? _difficulty}';
      _topic.text = '${draft['topic'] ?? _topic.text}';
      _duration = (draft['durationMinutes'] as num?)?.toInt() ?? _duration;
      _questionCount =
          (draft['questionCount'] as num?)?.toInt() ?? _questionCount;
      _durationController.text = '$_duration';
      _questionCountController.text = '$_questionCount';
      _languageController.text =
          '${draft['language'] ?? _languageController.text}';
      _assignment = _assignmentForDraft(draft) ?? _assignment;
    });
  }

  void _clearDraft() {
    setState(() {
      _currentDraft = null;
      _titleController.clear();
      _overviewController.clear();
      _sectionsController.clear();
      _checksController.clear();
      _notesController.clear();
    });
  }

  Map<String, Object?> _materialPayload() {
    final assignment = _assignment;
    return {
      'type': _outputType,
      'title': _titleController.text.trim(),
      'topic': _topic.text.trim(),
      'difficulty': _difficulty,
      'language': _languageController.text.trim().isEmpty
          ? 'English'
          : _languageController.text.trim(),
      'durationMinutes': _duration,
      'questionCount': _questionCount,
      if (assignment?['academicYearId'] != null)
        'academicYearId': assignment!['academicYearId'],
      if (assignment?['classId'] != null) 'classId': assignment!['classId'],
      if (assignment?['sectionId'] != null)
        'sectionId': assignment!['sectionId'],
      if (assignment?['subjectId'] != null)
        'subjectId': assignment!['subjectId'],
      'content': _currentContent(),
      'metadata': {
        ...((_currentDraft?['metadata'] as Map?) ?? const <String, Object?>{}),
        'editedInSchoolic': true,
      },
    };
  }

  Map<String, Object?> _currentContent() {
    return {
      'overview': _overviewController.text.trim(),
      'sections': _parseSections(_sectionsController.text),
      'checksForUnderstanding': _plainLines(_checksController.text),
      'teacherNotes': _plainLines(_notesController.text),
    };
  }

  TeachingMaterialPdfData _pdfData() {
    final assignment = _assignment;
    return TeachingMaterialPdfData(
      type: _outputType,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Draft'
          : _titleController.text.trim(),
      topic: _topic.text.trim().isEmpty ? 'Untitled topic' : _topic.text.trim(),
      overview: _overviewController.text.trim(),
      sections: _parseSections(_sectionsController.text)
          .map(
            (section) => TeachingMaterialSection(
              heading: '${section['heading']}',
              items: ((section['items'] as List?) ?? const [])
                  .map((e) => '$e')
                  .toList(),
            ),
          )
          .toList(),
      checksForUnderstanding: _plainLines(_checksController.text),
      teacherNotes: _plainLines(_notesController.text),
      className: assignment?['className'] as String?,
      sectionName: assignment?['sectionName'] as String?,
      subjectName: assignment?['subjectName'] as String?,
      language: _languageController.text.trim().isEmpty
          ? 'English'
          : _languageController.text.trim(),
    );
  }

  String _previewMeta() {
    final assignment = _assignment;
    final context = [
      if (assignment?['className'] != null) assignment!['className'],
      if (assignment?['sectionName'] != null) assignment!['sectionName'],
      if (assignment?['subjectName'] != null) assignment!['subjectName'],
    ].join(' - ');
    return [
      _typeLabel(_outputType),
      if (context.isNotEmpty) context,
      if (_topic.text.trim().isNotEmpty) 'Topic: ${_topic.text.trim()}',
    ].join(' | ');
  }

  List<Map<String, Object?>> _parseSections(String text) {
    final sections = <Map<String, Object?>>[];
    String? heading;
    final items = <String>[];
    void flush() {
      if (heading == null && items.isEmpty) return;
      sections.add({
        'heading': heading ?? 'Section',
        'items': items.isEmpty
            ? ['Review this section.']
            : List<String>.from(items),
      });
      items.clear();
    }

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('## ')) {
        flush();
        heading = line.substring(3).trim();
      } else if (line.startsWith('- ')) {
        items.add(line.substring(2).trim());
      } else {
        items.add(line);
      }
    }
    flush();
    return sections.isEmpty
        ? [
            {
              'heading': 'Draft',
              'items': ['Add draft content.'],
            },
          ]
        : sections;
  }

  List<String> _plainLines(String text) {
    return text
        .split('\n')
        .map(
          (line) => line.trim().startsWith('- ')
              ? line.trim().substring(2)
              : line.trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _typeLabel(String value) {
    return switch (value) {
      'lesson_plan' => 'Lesson plan',
      'worksheet' => 'Worksheet',
      'quiz' => 'Quiz',
      _ => value,
    };
  }

  Map<String, Object?>? _assignmentForDraft(Map<String, Object?> draft) {
    for (final assignment in widget.assignments) {
      final classMatches =
          draft['classId'] == null || assignment['classId'] == draft['classId'];
      final sectionMatches =
          draft['sectionId'] == null ||
          assignment['sectionId'] == draft['sectionId'];
      final subjectMatches =
          draft['subjectId'] == null ||
          assignment['subjectId'] == draft['subjectId'];
      if (classMatches && sectionMatches && subjectMatches) return assignment;
    }
    return null;
  }
}

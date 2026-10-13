import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';

class AdminExamsView extends ConsumerStatefulWidget {
  const AdminExamsView({
    required this.exams,
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> exams;
  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final Future<void> Function() reload;

  @override
  ConsumerState<AdminExamsView> createState() => _AdminExamsViewState();
}

class _AdminExamsViewState extends ConsumerState<AdminExamsView> {
  final _name = TextEditingController();
  final _examDate = TextEditingController(text: _defaultExamDate());
  final _maxMarks = TextEditingController(text: '100');
  String? _yearId;
  String? _classId;
  String? _sectionId;
  String? _subjectId;
  String _status = 'draft';
  Map<String, Object?>? _editing;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _selectDefaults();
  }

  @override
  void didUpdateWidget(covariant AdminExamsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectDefaults();
  }

  @override
  void dispose() {
    _name.dispose();
    _examDate.dispose();
    _maxMarks.dispose();
    super.dispose();
  }

  void _selectDefaults() {
    _yearId ??= widget.years.isEmpty
        ? null
        : widget.years.first['id'] as String?;
    _classId ??= widget.classes.isEmpty
        ? null
        : widget.classes.first['id'] as String?;
    _sectionId ??= _sectionsForClass().isEmpty
        ? null
        : _sectionsForClass().first['id'] as String?;
  }

  List<Map<String, Object?>> _sectionsForClass() {
    return widget.sections
        .where((section) => _classId == null || section['classId'] == _classId)
        .toList();
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _saving) return;
    if (_yearId == null || _classId == null || _sectionId == null) {
      setState(() => _error = 'Choose year, class, and section before saving.');
      return;
    }
    final maxMarks = int.tryParse(_maxMarks.text.trim());
    if (_name.text.trim().length < 2 || maxMarks == null) {
      setState(() => _error = 'Add an exam name and numeric max marks.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    final body = <String, Object?>{
      'academicYearId': _yearId,
      'classId': _classId,
      'sectionId': _sectionId,
      if (_subjectId != null) 'subjectId': _subjectId,
      'name': _name.text.trim(),
      'examDate': _examDate.text.trim(),
      'maxMarks': maxMarks,
      'status': _status,
    };
    try {
      final api = ref.read(apiClientProvider);
      final id = _editing?['id'];
      if (id == null) {
        await api.postJson('/api/v1/admin/exams', body, session: session);
      } else {
        await api.patchJson('/api/v1/admin/exams/$id', body, session: session);
      }
      _clear();
      await widget.reload();
      setState(() => _notice = id == null ? 'Exam created.' : 'Exam updated.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, Object?> exam) async {
    final session = ref.read(authControllerProvider).session;
    final id = exam['id'];
    if (session == null || id == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/api/v1/admin/exams/$id', session: session);
      await widget.reload();
      setState(() => _notice = 'Exam removed.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    }
  }

  void _edit(Map<String, Object?> exam) {
    setState(() {
      _editing = exam;
      _yearId = exam['academicYearId'] as String?;
      _classId = exam['classId'] as String?;
      _sectionId = exam['sectionId'] as String?;
      _subjectId = exam['subjectId'] as String?;
      _name.text = exam['name'] as String? ?? '';
      _examDate.text = exam['examDate'] as String? ?? _defaultExamDate();
      _maxMarks.text = '${exam['maxMarks'] ?? 100}';
      _status = exam['status'] as String? ?? 'draft';
    });
  }

  void _clear() {
    _editing = null;
    _name.clear();
    _examDate.text = _defaultExamDate();
    _maxMarks.text = '100';
    _status = 'draft';
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Exams & Marks',
          description: 'Create exam shells for class sections before teachers enter marks.',
          primaryAction: FilledButton.icon(
            onPressed: widget.reload,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
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
        _composer(isPhone: isPhone),
        const SizedBox(height: 18),
        if (widget.exams.isEmpty)
          const EmptyStateView(
            title: 'No exams yet',
            description: 'Create exams to open mark entry for teachers.',
            icon: Icons.assignment_outlined,
          )
        else
          ...widget.exams.map(_examCard),
      ],
    );
  }

  Widget _composer({required bool isPhone}) {
    return Container(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing == null ? 'New exam' : 'Edit exam',
            style: AppTypography.subsectionHeading,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdown(
                'Year',
                _yearId,
                widget.years,
                (value) => setState(() => _yearId = value),
                isPhone,
              ),
              _dropdown(
                'Class',
                _classId,
                widget.classes,
                (value) => setState(() {
                  _classId = value;
                  _sectionId = _sectionsForClass().isEmpty
                      ? null
                      : _sectionsForClass().first['id'] as String?;
                }),
                isPhone,
              ),
              _dropdown(
                'Section',
                _sectionId,
                _sectionsForClass(),
                (value) => setState(() => _sectionId = value),
                isPhone,
              ),
              _dropdown(
                'Subject',
                _subjectId,
                widget.subjects,
                (value) => setState(() => _subjectId = value),
                isPhone,
                optional: true,
              ),
              SizedBox(
                width: isPhone ? double.infinity : 150,
                child: TextField(
                  controller: _examDate,
                  decoration: const InputDecoration(labelText: 'Exam date'),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 120,
                child: TextField(
                  controller: _maxMarks,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max marks'),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'published',
                      child: Text('Published'),
                    ),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'draft'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Exam name'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_editing == null ? 'Create exam' : 'Save changes'),
              ),
              if (_editing != null)
                OutlinedButton(
                  onPressed: () => setState(_clear),
                  child: const Text('Cancel edit'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<Map<String, Object?>> rows,
    ValueChanged<String?> onChanged,
    bool isPhone, {
    bool optional = false,
  }) {
    return SizedBox(
      width: isPhone ? double.infinity : 180,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No subject'),
            ),
          ...rows.map(
            (row) => DropdownMenuItem<String>(
              value: row['id'] as String?,
              child: Text('${row['name']}', overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _examCard(Map<String, Object?> exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge.fromStatusString(exam['status'] as String?),
              Text(
                '${exam['className']} ${exam['sectionName']}',
                style: AppTypography.bodySecondary,
              ),
              if (exam['subjectName'] != null)
                Text(
                  '${exam['subjectName']}',
                  style: AppTypography.bodySecondary,
                ),
              Text(
                'Date ${exam['examDate']}',
                style: AppTypography.bodySecondary,
              ),
              Text(
                'Max ${exam['maxMarks']}',
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${exam['name']}', style: AppTypography.subsectionHeading),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _edit(exam),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _delete(exam),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _defaultExamDate() {
  final date = DateTime.now().add(const Duration(days: 7));
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

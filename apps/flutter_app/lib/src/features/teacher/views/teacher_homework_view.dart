import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';
import '../components/ai_homework_feedback_dialog.dart';

class TeacherHomeworkView extends ConsumerStatefulWidget {
  const TeacherHomeworkView({required this.assignments, super.key});

  final List<Map<String, Object?>> assignments;

  @override
  ConsumerState<TeacherHomeworkView> createState() =>
      _TeacherHomeworkViewState();
}

class _TeacherHomeworkViewState extends ConsumerState<TeacherHomeworkView> {
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _dueDate = TextEditingController(text: _defaultDueDate());
  final _minutes = TextEditingController(text: '30');

  Map<String, Object?>? _selectedClass;
  Map<String, Object?>? _editing;
  List<Map<String, Object?>> _homework = [];
  String _status = 'published';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.assignments.isEmpty
        ? null
        : widget.assignments.first;
    _load();
  }

  @override
  void didUpdateWidget(covariant TeacherHomeworkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedClass == null && widget.assignments.isNotEmpty) {
      _selectedClass = widget.assignments.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _dueDate.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(apiClientProvider)
          .getList('/api/v1/teacher/homework', session: session);
      if (mounted) setState(() => _homework = rows);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    final assignment = _selectedClass;
    if (session == null || assignment == null || _saving) return;
    if (_title.text.trim().length < 3 || _instructions.text.trim().length < 3) {
      setState(
        () => _error = 'Add a title and clear instructions before saving.',
      );
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_dueDate.text.trim())) {
      setState(() => _error = 'Use YYYY-MM-DD for the due date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });

    final minutes = int.tryParse(_minutes.text.trim());
    final body = <String, Object?>{
      'academicYearId': assignment['academicYearId'],
      'classId': assignment['classId'],
      'sectionId': assignment['sectionId'],
      if (assignment['subjectId'] != null) 'subjectId': assignment['subjectId'],
      'title': _title.text.trim(),
      'instructions': _instructions.text.trim(),
      'dueDate': _dueDate.text.trim(),
      'status': _status,
    };
    if (minutes != null) body['estimatedMinutes'] = minutes;

    try {
      final api = ref.read(apiClientProvider);
      final id = _editing?['id'];
      if (id == null) {
        await api.postJson('/api/v1/teacher/homework', body, session: session);
      } else {
        await api.patchJson(
          '/api/v1/teacher/homework/$id',
          body,
          session: session,
        );
      }
      _clearForm();
      await _load();
      if (mounted) {
        setState(
          () =>
              _notice = id == null ? 'Homework assigned.' : 'Homework updated.',
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, Object?> item) async {
    final session = ref.read(authControllerProvider).session;
    final id = item['id'];
    if (session == null || id == null) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/api/v1/teacher/homework/$id', session: session);
      if (_editing?['id'] == id) _clearForm();
      await _load();
      if (mounted) setState(() => _notice = 'Homework removed.');
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  void _edit(Map<String, Object?> item) {
    final match = widget.assignments.where((assignment) {
      return assignment['academicYearId'] == item['academicYearId'] &&
          assignment['classId'] == item['classId'] &&
          assignment['sectionId'] == item['sectionId'] &&
          assignment['subjectId'] == item['subjectId'];
    });
    setState(() {
      _editing = item;
      _selectedClass = match.isEmpty ? _selectedClass : match.first;
      _title.text = item['title'] as String? ?? '';
      _instructions.text = item['instructions'] as String? ?? '';
      _dueDate.text = item['dueDate'] as String? ?? _defaultDueDate();
      _minutes.text = '${item['estimatedMinutes'] ?? 30}';
      _status = item['status'] as String? ?? 'published';
    });
  }

  void _clearForm() {
    _editing = null;
    _title.clear();
    _instructions.clear();
    _dueDate.text = _defaultDueDate();
    _minutes.text = '30';
    _status = 'published';
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Homework',
          description: 'Create assignments for your classes and keep them visible in the student portal.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _load,
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
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_homework.isEmpty)
          const EmptyStateView(
            title: 'No homework yet',
            description:
                'Assignments you create for your classes will appear here.',
            icon: Icons.assignment_outlined,
          )
        else
          ..._homework.map(_homeworkCard),
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
            _editing == null ? 'New homework' : 'Edit homework',
            style: AppTypography.subsectionHeading,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isPhone ? double.infinity : 260,
                child: DropdownButtonFormField<Map<String, Object?>>(
                  isExpanded: true,
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.assignments.map((assignment) {
                    return DropdownMenuItem<Map<String, Object?>>(
                      value: assignment,
                      child: Text(
                        _assignmentLabel(assignment),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selectedClass = value),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 150,
                child: TextField(
                  controller: _dueDate,
                  decoration: const InputDecoration(labelText: 'Due date'),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 140,
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'published',
                      child: Text('Published'),
                    ),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _status = value ?? 'published'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructions,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Instructions'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: widget.assignments.isEmpty || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(
                  _editing == null ? 'Assign homework' : 'Save changes',
                ),
              ),
              if (_editing != null)
                OutlinedButton(
                  onPressed: _saving ? null : () => setState(_clearForm),
                  child: const Text('Cancel edit'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _homeworkCard(Map<String, Object?> item) {
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge.fromStatusString(item['status'] as String?),
              Text(
                'Due ${item['dueDate'] ?? '-'}',
                style: AppTypography.bodySecondary,
              ),
              Text(
                '${item['className']} ${item['sectionName']}',
                style: AppTypography.bodySecondary,
              ),
              if (item['subjectName'] != null)
                Text(
                  '${item['subjectName']}',
                  style: AppTypography.bodySecondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['title'] as String? ?? 'Homework',
            style: AppTypography.subsectionHeading,
          ),
          const SizedBox(height: 6),
          Text(
            item['instructions'] as String? ?? '',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    _HomeworkSubmissionsDialog.show(context, assignment: item),
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: const Text('Review submissions'),
              ),
              OutlinedButton.icon(
                onPressed: () => _edit(item),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _delete(item),
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

String _assignmentLabel(Map<String, Object?> assignment) {
  final subject = assignment['subjectName'];
  return '${assignment['className']} ${assignment['sectionName']}${subject == null ? '' : ' • $subject'}';
}

String _defaultDueDate() {
  final date = DateTime.now().add(const Duration(days: 2));
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _HomeworkSubmissionsDialog extends ConsumerStatefulWidget {
  const _HomeworkSubmissionsDialog({required this.assignment});

  final Map<String, Object?> assignment;

  static Future<void> show(
    BuildContext context, {
    required Map<String, Object?> assignment,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _HomeworkSubmissionsDialog(assignment: assignment),
    );
  }

  @override
  ConsumerState<_HomeworkSubmissionsDialog> createState() =>
      _HomeworkSubmissionsDialogState();
}

class _HomeworkSubmissionsDialogState
    extends ConsumerState<_HomeworkSubmissionsDialog> {
  List<Map<String, Object?>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    final id = widget.assignment['id'];
    if (session == null || id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .getJson(
            '/api/v1/teacher/homework/$id/submissions',
            session: session,
          );
      final rows = ((response['submissions'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, Object?>())
          .toList();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((row) {
      final submission = row['submission'] as Map?;
      if (_filter == 'pending') return submission == null;
      if (_filter == 'submitted') {
        return submission != null && submission['status'] != 'reviewed';
      }
      if (_filter == 'reviewed') return submission?['status'] == 'reviewed';
      return true;
    }).toList();
    final submitted = _rows.where((row) => row['submission'] != null).length;
    final reviewed = _rows.where((row) {
      final submission = row['submission'] as Map?;
      return submission?['status'] == 'reviewed';
    }).length;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.assignment['title'] as String? ??
                              'Homework submissions',
                          style: AppTypography.sectionHeading,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$submitted of ${_rows.length} submitted • $reviewed reviewed',
                          style: AppTypography.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh submissions',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close submissions',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    'all': 'All',
                    'pending': 'Pending',
                    'submitted': 'Needs review',
                    'reviewed': 'Reviewed',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_error != null)
                FeedbackBanner(
                  message: 'Unable to load submissions. $_error',
                  tone: FeedbackTone.error,
                  onDismiss: () => setState(() => _error = null),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : visible.isEmpty
                    ? const EmptyStateView(
                        title: 'No submissions in this view',
                        description: 'Choose another status filter or refresh the assignment.',
                        icon: Icons.inbox_outlined,
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _submissionRow(visible[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submissionRow(Map<String, Object?> row) {
    final student =
        (row['student'] as Map?)?.cast<String, Object?>() ?? const {};
    final submission = (row['submission'] as Map?)?.cast<String, Object?>();
    final status = submission?['status'] as String? ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['fullName'] as String? ?? 'Student',
                  style: AppTypography.subsectionHeading,
                ),
                const SizedBox(height: 3),
                Text(
                  'Roll ${student['rollNumber'] ?? '—'} • ${student['admissionNumber'] ?? 'No admission number'}',
                  style: AppTypography.metadata,
                ),
              ],
            ),
          ),
          StatusBadge.fromStatusString(status),
          const SizedBox(width: 10),
          if (submission == null)
            const Text(
              'Awaiting submission',
              style: AppTypography.bodySecondary,
            )
          else
            FilledButton.tonal(
              onPressed: () => _review(student, submission),
              child: Text(status == 'reviewed' ? 'Open review' : 'Review'),
            ),
        ],
      ),
    );
  }

  Future<void> _review(
    Map<String, Object?> student,
    Map<String, Object?> submission,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _GradeSubmissionDialog(
        assignment: widget.assignment,
        student: student,
        submission: submission,
      ),
    );
    await _load();
  }
}

class _GradeSubmissionDialog extends ConsumerStatefulWidget {
  const _GradeSubmissionDialog({
    required this.assignment,
    required this.student,
    required this.submission,
  });

  final Map<String, Object?> assignment;
  final Map<String, Object?> student;
  final Map<String, Object?> submission;

  @override
  ConsumerState<_GradeSubmissionDialog> createState() =>
      _GradeSubmissionDialogState();
}

class _GradeSubmissionDialogState
    extends ConsumerState<_GradeSubmissionDialog> {
  late final TextEditingController _marks;
  late final TextEditingController _feedback;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _marks = TextEditingController(
      text: '${widget.submission['marksObtained'] ?? ''}',
    );
    _feedback = TextEditingController(
      text: widget.submission['teacherFeedback'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _marks.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    final submissionId = widget.submission['id'];
    final marks = int.tryParse(_marks.text.trim());
    if (session == null || submissionId == null || _saving) return;
    if (marks == null || marks < 0 || marks > 100) {
      setState(() => _error = 'Enter marks from 0 to 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/teacher/homework/submissions/$submissionId/grade',
        {
          'marksObtained': marks,
          'teacherFeedback': _feedback.text.trim().isEmpty
              ? null
              : _feedback.text.trim(),
          'status': 'reviewed',
        },
        session: session,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.student['fullName'] as String? ?? 'Review submission',
                style: AppTypography.sectionHeading,
              ),
              const SizedBox(height: 4),
              Text(
                widget.assignment['title'] as String? ?? 'Homework',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: 18),
              Text('Student response', style: AppTypography.subsectionHeading),
              const SizedBox(height: 6),
              SelectableText(
                widget.submission['content'] as String? ??
                    'No written response.',
                style: AppTypography.bodySecondary,
              ),
              if ((widget.submission['attachmentUrl'] as String?)?.isNotEmpty ??
                  false) ...[
                const SizedBox(height: 14),
                Text('Attachment', style: AppTypography.subsectionHeading),
                const SizedBox(height: 6),
                SelectableText(
                  widget.submission['attachmentUrl'] as String,
                  style: AppTypography.bodySecondary,
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _marks,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Marks out of 100',
                  helperText: 'Enter a whole number from 0 to 100.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedback,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Feedback',
                  helperText:
                      'Explain strengths and the next improvement to make.',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final score = int.tryParse(_marks.text.trim()) ?? 0;
                    AiHomeworkFeedbackDialog.show(
                      context,
                      initialAssignmentTitle:
                          widget.assignment['title'] as String? ?? '',
                      initialSubject:
                          widget.assignment['subjectName'] as String? ??
                          'Subject',
                      initialScore: score,
                      initialMaxScore: 100,
                      onApplyFeedback: (text) => _feedback.text = text,
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('Draft feedback with AI'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                FeedbackBanner(
                  message: 'Unable to save review. $_error',
                  tone: FeedbackTone.error,
                  onDismiss: () => setState(() => _error = null),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Save review'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

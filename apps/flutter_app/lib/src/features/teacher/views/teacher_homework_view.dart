import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';

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
      setState(() => _homework = rows);
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
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
      setState(
        () => _notice = id == null ? 'Homework assigned.' : 'Homework updated.',
      );
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
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
      setState(() => _notice = 'Homework removed.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
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
            children: [
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';
import '../components/ai_draft_remarks_dialog.dart';

class TeacherMarksView extends ConsumerStatefulWidget {
  const TeacherMarksView({super.key});

  @override
  ConsumerState<TeacherMarksView> createState() => _TeacherMarksViewState();
}

class _TeacherMarksViewState extends ConsumerState<TeacherMarksView> {
  List<Map<String, Object?>> _exams = [];
  List<Map<String, Object?>> _students = [];
  Map<String, Object?>? _selectedExam;
  final Map<String, TextEditingController> _markControllers = {};
  final Map<String, TextEditingController> _remarkControllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._markControllers.values,
      ..._remarkControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExams() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await ref
          .read(apiClientProvider)
          .getList('/api/v1/teacher/exams', session: session);
      if (mounted) {
        setState(() {
          _exams = exams;
          _selectedExam = exams.isEmpty ? null : exams.first;
        });
      }
      if (exams.isNotEmpty) await _loadRoster(exams.first['id'] as String);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster(String examId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .getJson('/api/v1/teacher/exams/$examId/roster', session: session);
      final students = ((response['students'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, Object?>())
          .toList();
      for (final controller in [
        ..._markControllers.values,
        ..._remarkControllers.values,
      ]) {
        controller.dispose();
      }
      _markControllers.clear();
      _remarkControllers.clear();
      for (final student in students) {
        final id = student['studentId'] as String;
        _markControllers[id] = TextEditingController(
          text: student['marksObtained'] == null
              ? ''
              : '${student['marksObtained']}',
        );
        _remarkControllers[id] = TextEditingController(
          text: student['remarks'] as String? ?? '',
        );
      }
      if (mounted) setState(() => _students = students);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
  }

  Future<void> _saveMarks() async {
    final session = ref.read(authControllerProvider).session;
    final exam = _selectedExam;
    if (session == null || exam == null || _saving) return;
    final records = <Map<String, Object?>>[];
    for (final student in _students) {
      final id = student['studentId'] as String;
      final raw = _markControllers[id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final marks = int.tryParse(raw);
      if (marks == null) {
        setState(() => _error = 'Marks must be whole numbers.');
        return;
      }
      records.add({
        'studentId': id,
        'marksObtained': marks,
        if ((_remarkControllers[id]?.text.trim().isNotEmpty ?? false))
          'remarks': _remarkControllers[id]!.text.trim(),
      });
    }
    if (records.isEmpty) {
      setState(() => _error = 'Enter marks for at least one student.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(apiClientProvider).postJson('/api/v1/teacher/exam-marks', {
        'examId': exam['id'],
        'records': records,
      }, session: session);
      await _loadRoster(exam['id'] as String);
      if (mounted) setState(() => _notice = 'Marks saved.');
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Marks',
          description: 'Enter marks for exams assigned to your class sections.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _loadExams,
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
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_exams.isEmpty)
          const EmptyStateView(
            title: 'No exams assigned',
            description: 'Published or draft exams for your assigned sections will appear here.',
            icon: Icons.fact_check_outlined,
          )
        else ...[
          _examPicker(isPhone),
          const SizedBox(height: 14),
          _marksTable(isPhone),
        ],
      ],
    );
  }

  Widget _examPicker(bool isPhone) {
    return Container(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isPhone ? double.infinity : 360,
            child: DropdownButtonFormField<Map<String, Object?>>(
              isExpanded: true,
              initialValue: _selectedExam,
              decoration: const InputDecoration(labelText: 'Exam'),
              items: _exams
                  .map(
                    (exam) => DropdownMenuItem(
                      value: exam,
                      child: Text(
                        _examLabel(exam),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (exam) {
                if (exam == null) return;
                setState(() => _selectedExam = exam);
                _loadRoster(exam['id'] as String);
              },
            ),
          ),
          if (_selectedExam != null)
            StatusBadge.fromStatusString(_selectedExam!['status'] as String?),
          if (_selectedExam != null)
            Text(
              'Max ${_selectedExam!['maxMarks']}',
              style: AppTypography.bodySecondary,
            ),
        ],
      ),
    );
  }

  Widget _marksTable(bool isPhone) {
    if (_students.isEmpty) {
      return const EmptyStateView(
        title: 'No students found',
        description: 'The selected exam section has no active students.',
        icon: Icons.people_outline,
      );
    }
    return Container(
      padding: EdgeInsets.all(isPhone ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._students.map((student) {
            final id = student['studentId'] as String;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isPhone ? double.infinity : 240,
                    child: Text(
                      '${student['rollNumber'] ?? '-'} • ${student['fullName']}',
                      style: AppTypography.body,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _markControllers[id],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Marks'),
                    ),
                  ),
                  SizedBox(
                    width: isPhone ? double.infinity : 300,
                    child: TextField(
                      controller: _remarkControllers[id],
                      decoration: InputDecoration(
                        labelText: 'Remarks',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
                          tooltip: 'AI Draft Remarks',
                          onPressed: () {
                            final score = double.tryParse(_markControllers[id]?.text ?? '') ?? 0;
                            final max = (_selectedExam?['maxMarks'] as num?)?.toDouble() ?? 100;
                            final pct = max > 0 ? ((score / max) * 100).toStringAsFixed(1) : '75';
                            AiDraftRemarksDialog.show(
                              context,
                              initialStudentName: '${student['fullName'] ?? 'Student'}',
                              initialPercentage: '$pct%',
                              onApplyRemark: (remark) {
                                setState(() {
                                  _remarkControllers[id]?.text = remark;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveMarks,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save marks'),
            ),
          ),
        ],
      ),
    );
  }
}

String _examLabel(Map<String, Object?> exam) {
  final subject = exam['subjectName'] == null
      ? ''
      : ' • ${exam['subjectName']}';
  return '${exam['name']} • ${exam['className']} ${exam['sectionName']}$subject';
}

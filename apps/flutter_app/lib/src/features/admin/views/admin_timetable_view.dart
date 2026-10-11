import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';

const _days = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

class AdminTimetableView extends StatefulWidget {
  const AdminTimetableView({
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.staff,
    required this.assignments,
    required this.entries,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final List<Map<String, Object?>> staff;
  final List<Map<String, Object?>> assignments;
  final List<Map<String, Object?>> entries;
  final Future<void> Function() reload;

  @override
  State<AdminTimetableView> createState() => _AdminTimetableViewState();
}

class _AdminTimetableViewState extends State<AdminTimetableView> {
  String _mode = 'class';
  String? _classId;
  String? _sectionId;
  String? _staffId;
  String? _subjectId;
  int? _dayOfWeek;
  String? _feedback;

  List<Map<String, Object?>> get _filteredEntries {
    return widget.entries.where((entry) {
      if (_classId != null && entry['classId'] != _classId) return false;
      if (_sectionId != null && entry['sectionId'] != _sectionId) return false;
      if (_staffId != null && entry['staffId'] != _staffId) return false;
      if (_subjectId != null && entry['subjectId'] != _subjectId) return false;
      if (_dayOfWeek != null && entry['dayOfWeek'] != _dayOfWeek) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final day = (a['dayOfWeek'] as int).compareTo(b['dayOfWeek'] as int);
        if (day != 0) return day;
        return '${a['startTime']}'.compareTo('${b['startTime']}');
      });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Timetable',
          description: 'Plan weekly teaching periods and prevent teacher or class conflicts.',
          primaryAction: FilledButton.icon(
            onPressed: widget.years.isEmpty || widget.assignments.isEmpty ? null : () => _openEntryDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add lesson'),
          ),
        ),
        const SizedBox(height: 16),
        if (_feedback != null)
          FeedbackBanner(
            message: _feedback!,
            tone: FeedbackTone.success,
            onDismiss: () => setState(() => _feedback = null),
          ),
        _buildFilters(),
        const SizedBox(height: 16),
        _buildWeeklyView(filtered),
        const SizedBox(height: 20),
        AppTable<Map<String, Object?>>(
          title: 'Scheduled lessons',
          subtitle: _mode == 'class' ? 'Class-oriented schedule view' : 'Teacher-oriented schedule view',
          items: filtered,
          emptyMessage: 'No timetable entries match the current filters.',
          columns: [
            AppTableColumn(
              header: 'Day',
              width: 96,
              cellBuilder: (context, row) => Text(_days[row['dayOfWeek']] ?? '—', style: AppTypography.compactTableMedium),
            ),
            AppTableColumn(
              header: 'Time',
              width: 120,
              cellBuilder: (context, row) => Text('${_time(row['startTime'])}–${_time(row['endTime'])}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Class',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['className']} ${row['sectionName']}', style: AppTypography.compactTableMedium),
            ),
            AppTableColumn(
              header: 'Subject',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['subjectName']}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Teacher',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['staffName']}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: '',
              width: 96,
              alignment: Alignment.centerRight,
              cellBuilder: (context, row) => Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Edit lesson',
                    iconSize: 16,
                    onPressed: () => _openEntryDialog(existing: row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete lesson',
                    iconSize: 16,
                    onPressed: () => _deleteEntry(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'class', label: Text('By class'), icon: Icon(Icons.layers_outlined, size: 14)),
              ButtonSegment(value: 'teacher', label: Text('By teacher'), icon: Icon(Icons.badge_outlined, size: 14)),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          _select('Class', _classId, widget.classes, (value) => setState(() {
                _classId = value;
                _sectionId = null;
              })),
          _select(
            'Section',
            _sectionId,
            widget.sections.where((section) => _classId == null || section['classId'] == _classId).toList(),
            (value) => setState(() => _sectionId = value),
          ),
          _select('Teacher', _staffId, widget.staff.where((s) => s['isTeacher'] == true).toList(), (value) => setState(() => _staffId = value), labelKey: 'fullName'),
          _select('Subject', _subjectId, widget.subjects, (value) => setState(() => _subjectId = value)),
          DropdownButton<String?>(
            value: _dayOfWeek?.toString(),
            hint: const Text('Day'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All days')),
              ..._days.entries.map((d) => DropdownMenuItem<String?>(value: '${d.key}', child: Text(d.value))),
            ],
            onChanged: (value) => setState(() => _dayOfWeek = value == null ? null : int.parse(value)),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _classId = null;
              _sectionId = null;
              _staffId = null;
              _subjectId = null;
              _dayOfWeek = null;
            }),
            icon: const Icon(Icons.clear, size: 14),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView(List<Map<String, Object?>> filtered) {
    if (filtered.isEmpty) {
      return const EmptyStateView(
        title: 'No scheduled lessons',
        description: 'Add a timetable lesson or adjust filters to review an existing schedule.',
        icon: Icons.calendar_month_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final dayWidgets = _days.entries.map((day) {
          final lessons = filtered.where((entry) => entry['dayOfWeek'] == day.key).toList();
          return Container(
            width: isWide ? (constraints.maxWidth - 48) / 5 : constraints.maxWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              border: Border.all(color: AppColors.primaryBorder),
              borderRadius: AppRadii.rLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.value, style: AppTypography.subsectionHeading),
                const SizedBox(height: 10),
                if (lessons.isEmpty)
                  const Text('No lessons', style: AppTypography.metadata)
                else
                  ...lessons.map((lesson) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_time(lesson['startTime'])}–${_time(lesson['endTime'])}', style: AppTypography.metadata),
                            const SizedBox(height: 2),
                            Text('${lesson['className']} ${lesson['sectionName']}', style: AppTypography.bodyMedium),
                            Text('${lesson['subjectName']} • ${lesson['staffName']}', style: AppTypography.bodySecondary),
                          ],
                        ),
                      )),
              ],
            ),
          );
        }).toList();

        return Wrap(spacing: 12, runSpacing: 12, children: dayWidgets);
      },
    );
  }

  Widget _select(
    String label,
    String? value,
    List<Map<String, Object?>> options,
    ValueChanged<String?> onChanged, {
    String labelKey = 'name',
  }) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('All $label')),
          ...options.map((option) => DropdownMenuItem<String?>(value: option['id'] as String, child: Text('${option[labelKey] ?? option['name']}'))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _openEntryDialog({Map<String, Object?>? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _TimetableEntryDialog(
        years: widget.years,
        classes: widget.classes,
        sections: widget.sections,
        subjects: widget.subjects,
        staff: widget.staff,
        assignments: widget.assignments,
        existing: existing,
      ),
    );
    if (changed == true) {
      await widget.reload();
      setState(() => _feedback = existing == null ? 'Lesson added to timetable.' : 'Lesson updated.');
    }
  }

  Future<void> _deleteEntry(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Delete lesson',
        subtitle: '${_days[row['dayOfWeek']]} ${_time(row['startTime'])}–${_time(row['endTime'])}',
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
        child: const Text('This removes the scheduled lesson from the weekly timetable. Attendance history remains unchanged.'),
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = ProviderScope.containerOf(context, listen: false).read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ProviderScope.containerOf(context, listen: false).read(apiClientProvider).deleteJson('/api/v1/admin/timetable/${row['id']}', session: session);
      await widget.reload();
      setState(() => _feedback = 'Lesson removed from timetable.');
    } on ApiException catch (e) {
      setState(() => _feedback = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _TimetableEntryDialog extends ConsumerStatefulWidget {
  const _TimetableEntryDialog({
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.staff,
    required this.assignments,
    this.existing,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final List<Map<String, Object?>> staff;
  final List<Map<String, Object?>> assignments;
  final Map<String, Object?>? existing;

  @override
  ConsumerState<_TimetableEntryDialog> createState() => _TimetableEntryDialogState();
}

class _TimetableEntryDialogState extends ConsumerState<_TimetableEntryDialog> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _period = TextEditingController();
  final _label = TextEditingController();
  String? _yearId;
  String? _classId;
  String? _sectionId;
  String? _subjectId;
  String? _staffId;
  int _day = 1;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _yearId = existing?['academicYearId'] as String? ?? _first(widget.years)?['id'] as String?;
    _classId = existing?['classId'] as String? ?? _first(widget.classes)?['id'] as String?;
    _sectionId = existing?['sectionId'] as String? ?? _first(widget.sections.where((s) => s['classId'] == _classId))?['id'] as String?;
    _subjectId = existing?['subjectId'] as String?;
    _staffId = existing?['staffId'] as String?;
    _day = existing?['dayOfWeek'] as int? ?? 1;
    _start.text = _time(existing?['startTime'] ?? '09:00');
    _end.text = _time(existing?['endTime'] ?? '09:45');
    _period.text = existing?['periodNumber']?.toString() ?? '';
    _label.text = existing?['label']?.toString() ?? '';
    _normalizeAssignmentChoices();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _period.dispose();
    _label.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> get _matchingAssignments {
    return widget.assignments.where((assignment) {
      if (_yearId != null && assignment['academicYearId'] != _yearId) return false;
      if (_classId != null && assignment['classId'] != _classId) return false;
      if (_sectionId != null && assignment['sectionId'] != _sectionId) return false;
      if (assignment['subjectId'] == null) return false;
      return true;
    }).toList();
  }

  List<Map<String, Object?>> get _availableSubjects {
    final ids = _matchingAssignments.map((a) => a['subjectId']).whereType<String>().toSet();
    return widget.subjects.where((subject) => ids.contains(subject['id'])).toList();
  }

  List<Map<String, Object?>> get _availableTeachers {
    final ids = _matchingAssignments
        .where((assignment) => _subjectId == null || assignment['subjectId'] == _subjectId)
        .map((a) => a['staffId'])
        .whereType<String>()
        .toSet();
    return widget.staff.where((teacher) => ids.contains(teacher['id'])).toList();
  }

  void _normalizeAssignmentChoices() {
    final subjects = _availableSubjects;
    if (_subjectId == null || !subjects.any((s) => s['id'] == _subjectId)) {
      _subjectId = _first(subjects)?['id'] as String?;
    }
    final teachers = _availableTeachers;
    if (_staffId == null || !teachers.any((s) => s['id'] == _staffId)) {
      _staffId = _first(teachers)?['id'] as String?;
    }
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _yearId == null || _classId == null || _sectionId == null || _subjectId == null || _staffId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = {
      'academicYearId': _yearId,
      'classId': _classId,
      'sectionId': _sectionId,
      'subjectId': _subjectId,
      'staffId': _staffId,
      'dayOfWeek': _day,
      'startTime': _start.text.trim(),
      'endTime': _end.text.trim(),
      'periodNumber': _period.text.trim().isEmpty ? null : int.tryParse(_period.text.trim()),
      'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
    };

    try {
      final id = widget.existing?['id'];
      if (id == null) {
        await ref.read(apiClientProvider).postJson('/api/v1/admin/timetable', body, session: session);
      } else {
        await ref.read(apiClientProvider).putJson('/api/v1/admin/timetable/$id', body, session: session);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.existing == null ? 'Add timetable lesson' : 'Edit timetable lesson',
      subtitle: 'Teacher and subject choices are limited to existing assignments.',
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving || _matchingAssignments.isEmpty ? null : _save,
          icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check, size: 16),
          label: Text(_saving ? 'Saving...' : 'Save lesson'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            FeedbackBanner(
              message: _error!,
              tone: FeedbackTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdown('Academic year', _yearId, widget.years, (v) => setState(() {
                    _yearId = v;
                    _normalizeAssignmentChoices();
                  })),
              _dropdown('Class', _classId, widget.classes, (v) => setState(() {
                    _classId = v;
                    _sectionId = _first(widget.sections.where((s) => s['classId'] == _classId))?['id'] as String?;
                    _normalizeAssignmentChoices();
                  })),
              _dropdown('Section', _sectionId, widget.sections.where((s) => s['classId'] == _classId).toList(), (v) => setState(() {
                    _sectionId = v;
                    _normalizeAssignmentChoices();
                  })),
              _dropdown('Subject', _subjectId, _availableSubjects, (v) => setState(() {
                    _subjectId = v;
                    _normalizeAssignmentChoices();
                  })),
              _dropdown('Teacher', _staffId, _availableTeachers, (v) => setState(() => _staffId = v), labelKey: 'fullName'),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: _day,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: _days.entries.map((d) => DropdownMenuItem(value: d.key, child: Text(d.value))).toList(),
                  onChanged: (v) => setState(() => _day = v ?? 1),
                ),
              ),
              _field('Start', _start, '09:00'),
              _field('End', _end, '09:45'),
              _field('Period', _period, '1', number: true),
              _field('Label', _label, 'Optional'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<Map<String, Object?>> options,
    ValueChanged<String?> onChanged, {
    String labelKey = 'name',
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String?>(
        initialValue: options.any((o) => o['id'] == value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: options.map((option) => DropdownMenuItem<String?>(value: option['id'] as String, child: Text('${option[labelKey]}'))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint, {bool number = false}) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

String _time(Object? value) {
  final text = '$value';
  return text.length >= 5 ? text.substring(0, 5) : text;
}

Map<String, Object?>? _first(Iterable<Map<String, Object?>> items) {
  return items.isEmpty ? null : items.first;
}

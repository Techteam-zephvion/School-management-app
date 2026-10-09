import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../shared/shell.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  List<Map<String, Object?>> _years = [];
  List<Map<String, Object?>> _classes = [];
  List<Map<String, Object?>> _sections = [];
  List<Map<String, Object?>> _subjects = [];
  List<Map<String, Object?>> _staff = [];
  List<Map<String, Object?>> _students = [];
  List<Map<String, Object?>> _assignments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getList('/api/v1/admin/academic-years', session: session),
        api.getList('/api/v1/admin/classes', session: session),
        api.getList('/api/v1/admin/sections', session: session),
        api.getList('/api/v1/admin/subjects', session: session),
        api.getList('/api/v1/admin/staff', session: session),
        api.getList('/api/v1/admin/students', session: session),
        api.getList('/api/v1/admin/teacher-assignments', session: session),
      ]);
      setState(() {
        _years = results[0];
        _classes = results[1];
        _sections = results[2];
        _subjects = results[3];
        _staff = results[4];
        _students = results[5];
        _assignments = results[6];
      });
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Admin setup',
      actions: [
        IconButton.filledTonal(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: 220, child: InfoCard(title: 'Students', value: '${_students.length}', icon: Icons.groups_outlined)),
                    SizedBox(width: 220, child: InfoCard(title: 'Classes', value: '${_classes.length}', icon: Icons.class_outlined)),
                    SizedBox(width: 220, child: InfoCard(title: 'Teachers', value: '${_staff.length}', icon: Icons.badge_outlined)),
                    SizedBox(width: 220, child: InfoCard(title: 'Assignments', value: '${_assignments.length}', icon: Icons.assignment_ind_outlined)),
                  ],
                ),
                const SizedBox(height: 20),
                _SetupGrid(
                  reload: _load,
                  years: _years,
                  classes: _classes,
                  sections: _sections,
                  subjects: _subjects,
                  staff: _staff,
                ),
                const SizedBox(height: 20),
                _DataTablePreview(title: 'Students', rows: _students, columns: const ['admissionNumber', 'fullName', 'rollNumber']),
              ],
            ),
    );
  }
}

class _SetupGrid extends ConsumerWidget {
  const _SetupGrid({
    required this.reload,
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.staff,
  });

  final Future<void> Function() reload;
  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final List<Map<String, Object?>> staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: wide ? 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: wide ? 1.1 : 2.2,
          children: [
            _QuickCreateCard(
              title: 'Academic year',
              fields: const [
                _FieldSpec('name', 'Name'),
                _FieldSpec('startsOn', 'Starts on', hint: '2026-06-01'),
                _FieldSpec('endsOn', 'Ends on', hint: '2027-03-31'),
              ],
              defaults: const {'isActive': true},
              path: '/api/v1/admin/academic-years',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Class',
              fields: const [_FieldSpec('name', 'Name'), _FieldSpec('sortOrder', 'Sort order', number: true)],
              defaults: const {'sortOrder': 0},
              path: '/api/v1/admin/classes',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Section',
              fields: [_FieldSpec.select('classId', 'Class', classes), const _FieldSpec('name', 'Name')],
              path: '/api/v1/admin/sections',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Subject',
              fields: const [_FieldSpec('name', 'Name'), _FieldSpec('code', 'Code')],
              path: '/api/v1/admin/subjects',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Teacher',
              fields: const [
                _FieldSpec('staffCode', 'Staff code'),
                _FieldSpec('fullName', 'Full name'),
                _FieldSpec('email', 'Email'),
              ],
              defaults: const {'isTeacher': true},
              path: '/api/v1/admin/staff',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Student',
              fields: [
                const _FieldSpec('admissionNumber', 'Admission no.'),
                const _FieldSpec('fullName', 'Full name'),
                _FieldSpec.select('academicYearId', 'Academic year', years),
                _FieldSpec.select('classId', 'Class', classes),
                _FieldSpec.select('sectionId', 'Section', sections),
                const _FieldSpec('rollNumber', 'Roll no.'),
              ],
              path: '/api/v1/admin/students',
              reload: reload,
            ),
            _QuickCreateCard(
              title: 'Teacher assignment',
              fields: [
                _FieldSpec.select('staffId', 'Teacher', staff, labelKey: 'fullName'),
                _FieldSpec.select('academicYearId', 'Academic year', years),
                _FieldSpec.select('classId', 'Class', classes),
                _FieldSpec.select('sectionId', 'Section', sections),
                _FieldSpec.select('subjectId', 'Subject', subjects, nullable: true),
              ],
              defaults: const {'canTakeDailyAttendance': true},
              path: '/api/v1/admin/teacher-assignments',
              reload: reload,
            ),
          ],
        );
      },
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.key, this.label, {this.hint, this.number = false})
      : options = null,
        nullable = false,
        labelKey = 'name';

  const _FieldSpec.select(this.key, this.label, this.options, {this.labelKey = 'name', this.nullable = false})
      : hint = null,
        number = false;

  final String key;
  final String label;
  final String? hint;
  final bool number;
  final List<Map<String, Object?>>? options;
  final String labelKey;
  final bool nullable;
}

class _QuickCreateCard extends ConsumerStatefulWidget {
  const _QuickCreateCard({
    required this.title,
    required this.fields,
    required this.path,
    required this.reload,
    this.defaults = const {},
  });

  final String title;
  final List<_FieldSpec> fields;
  final String path;
  final Map<String, Object?> defaults;
  final Future<void> Function() reload;

  @override
  ConsumerState<_QuickCreateCard> createState() => _QuickCreateCardState();
}

class _QuickCreateCardState extends ConsumerState<_QuickCreateCard> {
  final _controllers = <String, TextEditingController>{};
  final _selected = <String, String?>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final field in widget.fields) ...[
                    if (field.options == null)
                      TextField(
                        controller: _controllers.putIfAbsent(field.key, TextEditingController.new),
                        keyboardType: field.number ? TextInputType.number : TextInputType.text,
                        decoration: InputDecoration(labelText: field.label, hintText: field.hint),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selected[field.key],
                        decoration: InputDecoration(labelText: field.label),
                        items: [
                          ...field.options!.map(
                            (option) => DropdownMenuItem(
                              value: option['id'] as String,
                              child: Text((option[field.labelKey] ?? option['name'] ?? option['fullName']) as String),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _selected[field.key] = value),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add),
              label: Text(_saving ? 'Saving...' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final body = <String, Object?>{...widget.defaults};
    for (final field in widget.fields) {
      if (field.options == null) {
        final value = _controllers[field.key]?.text.trim();
        if (value == null || value.isEmpty) continue;
        body[field.key] = field.number ? int.parse(value) : value;
      } else {
        body[field.key] = _selected[field.key];
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postJson(widget.path, body, session: session);
      for (final controller in _controllers.values) {
        controller.clear();
      }
      _selected.clear();
      await widget.reload();
    } on Exception catch (exception) {
      setState(() => _error = exception.toString());
    } finally {
      setState(() => _saving = false);
    }
  }
}

class _DataTablePreview extends StatelessWidget {
  const _DataTablePreview({required this.title, required this.rows, required this.columns});

  final String title;
  final List<Map<String, Object?>> rows;
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns.map((column) => DataColumn(label: Text(column))).toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: columns.map((column) => DataCell(Text('${row[column] ?? ''}'))).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

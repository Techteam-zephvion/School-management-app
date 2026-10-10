import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../shared/shell.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  List<Map<String, Object?>> _assignments = [];
  List<StudentRow> _roster = [];
  final Map<String, AttendanceStatus> _statuses = {};
  Map<String, Object?>? _selectedAssignment;
  AttendanceKind _kind = AttendanceKind.daily;
  final _date = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _period = TextEditingController(text: '1');
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _date.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final assignments = await ref.read(apiClientProvider).getList('/api/v1/teacher/assignments', session: session);
      setState(() {
        _assignments = assignments;
        _selectedAssignment = assignments.isEmpty ? null : assignments.first;
      });
      await _loadRoster();
    } on ApiException catch (exception) {
      setState(() => _message = exception.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster() async {
    final session = ref.read(authControllerProvider).session;
    final assignment = _selectedAssignment;
    if (session == null || assignment == null) return;

    final query = Uri(queryParameters: {
      'sectionId': assignment['sectionId'] as String,
      'academicYearId': assignment['academicYearId'] as String,
    }).query;
    final rosterJson = await ref.read(apiClientProvider).getList('/api/v1/teacher/roster?$query', session: session);
    final roster = rosterJson.map(StudentRow.fromJson).toList();
    setState(() {
      _roster = roster;
      _statuses
        ..clear()
        ..addEntries(roster.map((student) => MapEntry(student.id, AttendanceStatus.present)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Teacher attendance',
      actions: [
        IconButton.filledTonal(
          tooltip: 'Refresh',
          onPressed: _loadAssignments,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 340,
                          child: DropdownButtonFormField<Map<String, Object?>>(
                            isExpanded: true,
                            initialValue: _selectedAssignment,
                            decoration: const InputDecoration(labelText: 'Assigned section'),
                            selectedItemBuilder: (context) => _assignments
                                .map(
                                  (assignment) => Text(
                                    '${assignment['className']} - ${assignment['sectionName']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                                .toList(),
                            items: _assignments
                                .map(
                                  (assignment) => DropdownMenuItem(
                                    value: assignment,
                                    child: Text(
                                      '${assignment['className']} - ${assignment['sectionName']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              setState(() => _selectedAssignment = value);
                              await _loadRoster();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: SegmentedButton<AttendanceKind>(
                            segments: const [
                              ButtonSegment(
                                value: AttendanceKind.daily,
                                icon: Icon(Icons.today_outlined),
                                label: Text('Daily'),
                              ),
                              ButtonSegment(
                                value: AttendanceKind.period,
                                icon: Icon(Icons.schedule_outlined),
                                label: Text('Period'),
                              ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (value) => setState(() => _kind = value.first),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _date,
                            decoration: const InputDecoration(labelText: 'Date'),
                          ),
                        ),
                        if (_kind == AttendanceKind.period)
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _period,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Period'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Roster', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        if (_roster.isEmpty)
                          const Text('No students found for this assigned section.')
                        else
                          ..._roster.map(_studentAttendanceRow),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving || _roster.isEmpty ? null : _saveAttendance,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving...' : 'Save attendance'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _studentAttendanceRow(StudentRow student) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: Text(
              '${student.rollNumber ?? student.admissionNumber}  ${student.fullName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SegmentedButton<AttendanceStatus>(
            segments: const [
              ButtonSegment(value: AttendanceStatus.present, icon: Icon(Icons.check), label: Text('Present')),
              ButtonSegment(value: AttendanceStatus.absent, icon: Icon(Icons.close), label: Text('Absent')),
              ButtonSegment(value: AttendanceStatus.late, icon: Icon(Icons.schedule), label: Text('Late')),
              ButtonSegment(value: AttendanceStatus.excused, icon: Icon(Icons.event_available), label: Text('Excused')),
            ],
            selected: {_statuses[student.id] ?? AttendanceStatus.present},
            onSelectionChanged: (value) => setState(() => _statuses[student.id] = value.first),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final session = ref.read(authControllerProvider).session;
    final assignment = _selectedAssignment;
    if (session == null || assignment == null) return;

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final body = {
        'academicYearId': assignment['academicYearId'],
        'classId': assignment['classId'],
        'sectionId': assignment['sectionId'],
        'subjectId': _kind == AttendanceKind.period ? assignment['subjectId'] : null,
        'kind': _kind.name,
        'attendanceDate': _date.text,
        'periodNumber': _kind == AttendanceKind.period ? int.parse(_period.text) : null,
        'records': _roster
            .map(
              (student) => {
                'studentId': student.id,
                'status': (_statuses[student.id] ?? AttendanceStatus.present).name,
              },
            )
            .toList(),
      };
      final result = await ref.read(apiClientProvider).postJson('/api/v1/teacher/attendance', body, session: session);
      setState(() => _message = 'Saved ${result['savedRecords']} records.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${result['savedRecords']} attendance records.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on Exception catch (exception) {
      setState(() => _message = exception.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $exception'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }
}

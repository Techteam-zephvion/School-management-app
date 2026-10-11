import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/attendance_status_button.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';

class TeacherAttendanceView extends ConsumerStatefulWidget {
  const TeacherAttendanceView({
    required this.assignments,
    required this.selectedAssignment,
    required this.onAssignmentChanged,
    required this.onAttendanceSaved,
    super.key,
  });

  final List<Map<String, Object?>> assignments;
  final Map<String, Object?>? selectedAssignment;
  final ValueChanged<Map<String, Object?>?> onAssignmentChanged;
  final VoidCallback onAttendanceSaved;

  @override
  ConsumerState<TeacherAttendanceView> createState() => _TeacherAttendanceViewState();
}

class _TeacherAttendanceViewState extends ConsumerState<TeacherAttendanceView> {
  List<StudentRow> _roster = [];
  final Map<String, AttendanceStatus> _statuses = {};
  AttendanceKind _kind = AttendanceKind.daily;
  final _date = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _period = TextEditingController(text: '1');
  final _searchController = TextEditingController();

  bool _loadingRoster = false;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String? _errorMessage;
  String? _successMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.selectedAssignment != null) {
      _loadRoster(widget.selectedAssignment!);
    }
  }

  @override
  void didUpdateWidget(covariant TeacherAttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedAssignment != oldWidget.selectedAssignment && widget.selectedAssignment != null) {
      _loadRoster(widget.selectedAssignment!);
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _period.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster(Map<String, Object?> assignment) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loadingRoster = true;
      _errorMessage = null;
      _successMessage = null;
      _hasUnsavedChanges = false;
    });

    try {
      final query = Uri(queryParameters: {
        'sectionId': assignment['sectionId'] as String,
        'academicYearId': assignment['academicYearId'] as String,
      }).query;
      final rosterJson = await ref.read(apiClientProvider).getList(
            '/api/v1/teacher/roster?$query',
            session: session,
          );
      final roster = rosterJson.map(StudentRow.fromJson).toList();
      setState(() {
        _roster = roster;
        _statuses
          ..clear()
          ..addEntries(roster.map((student) => MapEntry(student.id, AttendanceStatus.present)));
      });
    } on ApiException catch (exception) {
      setState(() => _errorMessage = exception.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final student in _roster) {
        _statuses[student.id] = status;
      }
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    final session = ref.read(authControllerProvider).session;
    final assignment = widget.selectedAssignment;
    if (session == null || assignment == null || _roster.isEmpty) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final body = {
        'academicYearId': assignment['academicYearId'],
        'classId': assignment['classId'],
        'sectionId': assignment['sectionId'],
        'subjectId': _kind == AttendanceKind.period ? assignment['subjectId'] : null,
        'kind': _kind.name,
        'attendanceDate': _date.text.trim(),
        'periodNumber': _kind == AttendanceKind.period ? int.tryParse(_period.text.trim()) ?? 1 : null,
        'records': _roster
            .map(
              (student) => {
                'studentId': student.id,
                'status': (_statuses[student.id] ?? AttendanceStatus.present).name,
              },
            )
            .toList(),
      };

      final result = await ref.read(apiClientProvider).postJson(
            '/api/v1/teacher/attendance',
            body,
            session: session,
          );

      final count = result['savedRecords'] ?? _roster.length;
      final className = '${assignment['className']} - ${assignment['sectionName']}';

      setState(() {
        _hasUnsavedChanges = false;
        _successMessage = 'Successfully recorded $count attendance records for $className on ${_date.text}.';
      });

      widget.onAttendanceSaved();
    } on ApiException catch (exception) {
      setState(() => _errorMessage = exception.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoster = _searchQuery.isEmpty
        ? _roster
        : _roster.where((student) {
            final name = student.fullName.toLowerCase();
            final adm = student.admissionNumber.toLowerCase();
            final roll = (student.rollNumber ?? '').toLowerCase();
            return name.contains(_searchQuery) || adm.contains(_searchQuery) || roll.contains(_searchQuery);
          }).toList();

    // Calculate real-time totals
    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int excusedCount = 0;
    for (final student in _roster) {
      final status = _statuses[student.id] ?? AttendanceStatus.present;
      switch (status) {
        case AttendanceStatus.present:
          presentCount++;
        case AttendanceStatus.absent:
          absentCount++;
        case AttendanceStatus.late:
          lateCount++;
        case AttendanceStatus.excused:
          excusedCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Attendance Register',
          description: 'Record daily or period-based roll call with real-time totals.',
          badge: _hasUnsavedChanges
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.statusWarning.withValues(alpha: 0.1),
                    borderRadius: AppRadii.rSm,
                    border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: AppColors.statusWarning),
                      SizedBox(width: 5),
                      Text(
                        'UNSAVED CHANGES',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusWarning,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          primaryAction: FilledButton.icon(
            onPressed: _saving || _loadingRoster || _roster.isEmpty ? null : _saveAttendance,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 16),
            label: Text(_saving ? 'Persisting...' : 'Save attendance'),
          ),
        ),
        const SizedBox(height: 20),

        if (_successMessage != null)
          FeedbackBanner(
            message: _successMessage!,
            tone: FeedbackTone.success,
            onDismiss: () => setState(() => _successMessage = null),
          ),

        if (_errorMessage != null)
          FeedbackBanner(
            message: _errorMessage!,
            tone: FeedbackTone.error,
            actionLabel: 'Retry',
            onAction: _saveAttendance,
            onDismiss: () => setState(() => _errorMessage = null),
          ),

        // Session controls bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Class assignment selector
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<Map<String, Object?>?>(
                  isExpanded: true,
                  initialValue: widget.selectedAssignment,
                  decoration: const InputDecoration(labelText: 'Assigned section'),
                  selectedItemBuilder: (context) => widget.assignments.map((assignment) {
                    final sub = assignment['subjectName'] != null ? ' (${assignment['subjectName']})' : '';
                    return Text(
                      '${assignment['className']} - ${assignment['sectionName']}$sub',
                      overflow: TextOverflow.ellipsis,
                    );
                  }).toList(),
                  items: widget.assignments.map((assignment) {
                    final sub = assignment['subjectName'] != null ? ' (${assignment['subjectName']})' : '';
                    return DropdownMenuItem<Map<String, Object?>?>(
                      value: assignment,
                      child: Text(
                        '${assignment['className']} - ${assignment['sectionName']}$sub',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    widget.onAssignmentChanged(value);
                    if (value != null) _loadRoster(value);
                  },
                ),
              ),

              // Kind toggle
              SizedBox(
                width: 220,
                child: SegmentedButton<AttendanceKind>(
                  segments: const [
                    ButtonSegment(
                      value: AttendanceKind.daily,
                      icon: Icon(Icons.today_outlined, size: 14),
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: AttendanceKind.period,
                      icon: Icon(Icons.schedule_outlined, size: 14),
                      label: Text('Period'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (val) => setState(() {
                    _kind = val.first;
                    _hasUnsavedChanges = true;
                  }),
                ),
              ),

              // Date picker field
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _date,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _date.text = DateFormat('yyyy-MM-dd').format(picked);
                          setState(() => _hasUnsavedChanges = true);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Period field if period attendance
              if (_kind == AttendanceKind.period)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _period,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Period #'),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Real-time Summary Tally & Bulk Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTally('TOTAL', '${_roster.length}', AppColors.primaryText),
                    _buildTally('PRESENT', '$presentCount', AppColors.statusSuccess),
                    _buildTally('ABSENT', '$absentCount', AppColors.statusError),
                    _buildTally('LATE', '$lateCount', AppColors.statusWarning),
                    _buildTally('EXCUSED', '$excusedCount', AppColors.statusInfo),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _roster.isEmpty ? null : () => _markAll(AttendanceStatus.present),
                    icon: const Icon(Icons.done_all, size: 14, color: AppColors.statusSuccess),
                    label: const Text('All Present', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _roster.isEmpty ? null : () => _markAll(AttendanceStatus.absent),
                    icon: const Icon(Icons.close, size: 14, color: AppColors.statusError),
                    label: const Text('All Absent', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Student Roster Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search & table header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Text('Student Roster (${_roster.length})', style: AppTypography.subsectionHeading),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 32,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Filter by name or roll...',
                          hintStyle: AppTypography.metadata,
                          prefixIcon: const Icon(Icons.search, size: 14, color: AppColors.mutedText),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 12, color: AppColors.mutedText),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: AppColors.secondaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.primaryBorder),

              if (_loadingRoster)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryText),
                  ),
                )
              else if (_roster.isEmpty)
                const EmptyStateView(
                  title: 'No students enrolled',
                  description: 'This assigned class section does not have any active student enrollments.',
                  icon: Icons.people_outline,
                )
              else if (filteredRoster.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('No students match "$_searchQuery"', style: AppTypography.bodySecondary),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRoster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                  itemBuilder: (context, index) {
                    final student = filteredRoster[index];
                    final currentStatus = _statuses[student.id] ?? AttendanceStatus.present;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBackground,
                              borderRadius: AppRadii.rSm,
                              border: Border.all(color: AppColors.primaryBorder),
                            ),
                            child: Text(
                              student.rollNumber ?? '${index + 1}',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.fullName, style: AppTypography.compactTableMedium),
                                Text(student.admissionNumber, style: AppTypography.metadata),
                              ],
                            ),
                          ),
                          AttendanceStatusGroup(
                            selectedStatus: currentStatus,
                            onChanged: (newStatus) {
                              setState(() {
                                _statuses[student.id] = newStatus;
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTally(String label, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:', style: AppTypography.label),
        const SizedBox(width: 5),
        Text(
          count,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

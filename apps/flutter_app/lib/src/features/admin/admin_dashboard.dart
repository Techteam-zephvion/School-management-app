import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/csv_exporter.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/app_dialog.dart';
import '../shared/components/feedback_banner.dart';
import 'dialogs/add_staff_dialog.dart';
import 'dialogs/add_student_dialog.dart';
import 'dialogs/student_attendance_dialog.dart';
import 'views/admin_assignments_view.dart';
import 'views/admin_attendance_view.dart';
import 'views/admin_classes_view.dart';
import 'views/admin_overview_view.dart';
import 'views/admin_reports_view.dart';
import 'views/admin_settings_view.dart';
import 'views/admin_staff_view.dart';
import 'views/admin_students_view.dart';

enum AdminNavSection {
  overview,
  attendance,
  students,
  staff,
  classesAndSubjects,
  teacherAssignments,
  reports,
  settings,
}

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  AdminNavSection _activeSection = AdminNavSection.overview;
  bool _sidebarCollapsed = false;

  List<Map<String, Object?>> _years = [];
  List<Map<String, Object?>> _classes = [];
  List<Map<String, Object?>> _sections = [];
  List<Map<String, Object?>> _subjects = [];
  List<Map<String, Object?>> _staff = [];
  List<Map<String, Object?>> _students = [];
  List<Map<String, Object?>> _assignments = [];
  List<Map<String, Object?>> _summaries = [];
  String _schoolName = 'Schoolic Academy';
  bool _loading = true;
  String? _error;

  String? _selectedClassId;
  String? _selectedSectionId;
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
    _searchController.dispose();
    super.dispose();
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
        api.getJson('/api/v1/admin/overview', session: session).then((res) {
          final school = res['school'] as Map<String, Object?>?;
          if (school != null && school['name'] != null) {
            _schoolName = school['name'] as String;
          }
          return <Map<String, Object?>>[];
        }).catchError((_) => <Map<String, Object?>>[]),
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
      await _loadSummaries();
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSummaries() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final queryParams = <String, String>{
        if (_selectedClassId != null && _selectedClassId!.isNotEmpty) 'classId': _selectedClassId!,
        if (_selectedSectionId != null && _selectedSectionId!.isNotEmpty) 'sectionId': _selectedSectionId!,
        if (_startDate.text.trim().isNotEmpty) 'startDate': _startDate.text.trim(),
        if (_endDate.text.trim().isNotEmpty) 'endDate': _endDate.text.trim(),
      };
      final qs = queryParams.isEmpty ? '' : '?${Uri(queryParameters: queryParams).query}';
      final res = await ref.read(apiClientProvider).getJson('/api/v1/admin/attendance-summary$qs', session: session);
      setState(() {
        _summaries = ((res['sessions'] as List?) ?? const []).cast<Map<String, Object?>>();
      });
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    }
  }

  String _sanitizeCsvCell(Object? value) {
    if (value == null) return '""';
    var str = value.toString().trim();
    if (str.startsWith('=') ||
        str.startsWith('+') ||
        str.startsWith('-') ||
        str.startsWith('@') ||
        str.startsWith('\t') ||
        str.startsWith('\r')) {
      str = "'$str";
    }
    return '"${str.replaceAll('"', '""')}"';
  }

  void _exportSummariesCsv() {
    if (_summaries.isEmpty) return;
    final headers = ['Date', 'Class', 'Section', 'Kind', 'Period', 'Teacher'];
    final keys = ['attendanceDate', 'className', 'sectionName', 'kind', 'periodNumber', 'staffName'];
    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final row in _summaries) {
      final line = keys.map((k) => _sanitizeCsvCell(row[k])).join(',');
      buffer.writeln(line);
    }
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    downloadCsv('attendance_summary_$dateStr.csv', buffer.toString());
  }

  void _showStudentDialog(Map<String, Object?> student) {
    showDialog(
      context: context,
      builder: (context) => StudentAttendanceDialog(
        studentId: student['id'] as String,
        studentName: student['fullName'] as String,
      ),
    );
  }

  void _openAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddStudentDialog(
        years: _years,
        classes: _classes,
        sections: _sections,
        reload: _load,
      ),
    );
  }

  void _openAddStaffDialog() {
    showDialog(
      context: context,
      builder: (context) => AddStaffDialog(reload: _load),
    );
  }

  void _openNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: 'System Activity',
        subtitle: 'Recent institutional log events.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _activityTile('Today', 'Attendance register synchronized for ${_summaries.length} sessions.'),
            _activityTile('Active Term', '${_classes.length} classes and ${_sections.length} sections active.'),
            _activityTile('Faculty', '${_staff.length} staff members and ${_assignments.length} assignments.'),
          ],
        ),
      ),
    );
  }

  Widget _activityTile(String time, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time.toUpperCase(), style: AppTypography.metadata),
          const SizedBox(height: 2),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryText),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              FeedbackBanner(
                                message: _error!,
                                tone: FeedbackTone.error,
                                onDismiss: () => setState(() => _error = null),
                              ),
                            _buildCurrentView(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: AppMotion.comfortable,
      curve: AppMotion.curve,
      width: _sidebarCollapsed ? 64.0 : 230.0,
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(right: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 20),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
            ),
            child: _sidebarCollapsed
                ? const Center(
                    child: Text(
                      's.',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      const Text(
                        'schoolic.',
                        style: TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: AppRadii.rSm,
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _sidebarItem(AdminNavSection.overview, Icons.grid_view_outlined, 'Overview'),
          _sidebarItem(AdminNavSection.attendance, Icons.fact_check_outlined, 'Attendance'),
          _sidebarItem(AdminNavSection.students, Icons.people_outline, 'Students'),
          _sidebarItem(AdminNavSection.staff, Icons.badge_outlined, 'Staff'),
          _sidebarItem(AdminNavSection.classesAndSubjects, Icons.layers_outlined, 'Classes & Subjects'),
          _sidebarItem(AdminNavSection.teacherAssignments, Icons.assignment_ind_outlined, 'Teacher Assignments'),
          _sidebarItem(AdminNavSection.reports, Icons.analytics_outlined, 'Reports'),
          const Spacer(),
          const Divider(height: 1, color: AppColors.primaryBorder),
          _sidebarItem(AdminNavSection.settings, Icons.settings_outlined, 'Settings'),
          InkWell(
            onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    _sidebarCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                    size: 16,
                    color: AppColors.mutedText,
                  ),
                  if (!_sidebarCollapsed) ...[
                    const SizedBox(width: 12),
                    const Text('Collapse sidebar', style: AppTypography.metadata),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(AdminNavSection section, IconData icon, String label) {
    final active = _activeSection == section;
    return Tooltip(
      message: _sidebarCollapsed ? label : '',
      child: InkWell(
        onTap: () => setState(() => _activeSection = section),
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 12),
          decoration: BoxDecoration(
            color: active ? AppColors.secondaryBackground : Colors.transparent,
            borderRadius: AppRadii.rMd,
            border: active ? const Border(left: BorderSide(color: AppColors.primaryText, width: 2)) : null,
          ),
          child: Row(
            mainAxisAlignment: _sidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.primaryText : AppColors.secondaryText,
              ),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: active ? AppColors.primaryText : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final session = ref.watch(authControllerProvider).session;
    final yearName = _years.isNotEmpty ? '${_years.first['name'] ?? '2026-2027'}' : '2026-2027';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: Row(
        children: [
          Text(
            _sectionTitle(_activeSection),
            style: const TextStyle(
              fontFamily: 'Switzer',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 20),
          Container(width: 1, height: 16, color: AppColors.primaryBorder),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBorder),
              borderRadius: AppRadii.rMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Text(
                  yearName,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'System activity',
            iconSize: 18,
            onPressed: _openNotificationsDialog,
            icon: const Icon(Icons.notifications_none_outlined, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh data',
            iconSize: 18,
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: AppColors.primaryBorder),
          const SizedBox(width: 16),
          Text(
            session?.email ?? 'admin@schoolic.local',
            style: const TextStyle(fontFamily: 'Switzer', fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            iconSize: 16,
            onPressed: () => ref.read(authControllerProvider).signOut(),
            icon: const Icon(Icons.logout, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  String _sectionTitle(AdminNavSection section) {
    switch (section) {
      case AdminNavSection.overview:
        return 'Overview';
      case AdminNavSection.attendance:
        return 'Attendance Register';
      case AdminNavSection.students:
        return 'Students';
      case AdminNavSection.staff:
        return 'Teaching & Staff';
      case AdminNavSection.classesAndSubjects:
        return 'Classes & Subjects';
      case AdminNavSection.teacherAssignments:
        return 'Teacher Assignments';
      case AdminNavSection.reports:
        return 'Reports & Export';
      case AdminNavSection.settings:
        return 'Settings';
    }
  }

  Widget _buildCurrentView() {
    final activeYear = _years.isNotEmpty ? '${_years.first['name'] ?? '2026-2027'}' : '2026-2027';

    switch (_activeSection) {
      case AdminNavSection.overview:
        return AdminOverviewView(
          students: _students,
          staff: _staff,
          classes: _classes,
          sections: _sections,
          assignments: _assignments,
          summaries: _summaries,
          activeYearName: activeYear,
          onNavigateToSection: (index) => setState(() => _activeSection = AdminNavSection.values[index]),
          onOpenAddStudent: _openAddStudentDialog,
          onOpenAddStaff: _openAddStaffDialog,
        );
      case AdminNavSection.attendance:
        return AdminAttendanceView(
          summaries: _summaries,
          classes: _classes,
          sections: _sections,
          selectedClassId: _selectedClassId,
          selectedSectionId: _selectedSectionId,
          startDateController: _startDate,
          endDateController: _endDate,
          onClassChanged: (val) {
            setState(() {
              _selectedClassId = val;
              _selectedSectionId = null;
            });
          },
          onSectionChanged: (val) => setState(() => _selectedSectionId = val),
          onFilter: _loadSummaries,
          onReset: () {
            setState(() {
              _selectedClassId = null;
              _selectedSectionId = null;
              _startDate.clear();
              _endDate.clear();
            });
            _loadSummaries();
          },
          onExportCsv: _exportSummariesCsv,
        );
      case AdminNavSection.students:
        return AdminStudentsView(
          students: _students,
          onOpenAddStudent: _openAddStudentDialog,
          onOpenStudentProfile: _showStudentDialog,
        );
      case AdminNavSection.staff:
        return AdminStaffView(
          staff: _staff,
          onOpenAddStaff: _openAddStaffDialog,
        );
      case AdminNavSection.classesAndSubjects:
        return AdminClassesView(
          years: _years,
          classes: _classes,
          sections: _sections,
          subjects: _subjects,
          reload: _load,
        );
      case AdminNavSection.teacherAssignments:
        return AdminAssignmentsView(
          assignments: _assignments,
          staff: _staff,
          years: _years,
          classes: _classes,
          sections: _sections,
          subjects: _subjects,
          reload: _load,
        );
      case AdminNavSection.reports:
        return AdminReportsView(
          summaries: _summaries,
          students: _students,
          classes: _classes,
          onExportCsv: _exportSummariesCsv,
        );
      case AdminNavSection.settings:
        return AdminSettingsView(
          years: _years,
          schoolName: _schoolName,
        );
    }
  }
}

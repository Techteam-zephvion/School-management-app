import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/csv_exporter.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

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
    } finally {
      setState(() => _loading = false);
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

  void _exportSummariesCsv() {
    if (_summaries.isEmpty) return;
    final headers = ['Date', 'Class', 'Section', 'Kind', 'Period', 'Teacher'];
    final keys = ['attendanceDate', 'className', 'sectionName', 'kind', 'periodNumber', 'staffName'];
    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final row in _summaries) {
      final line = keys.map((k) {
        final val = '${row[k] ?? ''}'.replaceAll('"', '""');
        return '"$val"';
      }).join(',');
      buffer.writeln(line);
    }
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    downloadCsv('attendance_summary_$dateStr.csv', buffer.toString());
  }

  void _showStudentDialog(Map<String, Object?> student) {
    showDialog(
      context: context,
      builder: (context) => _StudentAttendanceDialog(
        studentId: student['id'] as String,
        studentName: student['fullName'] as String,
      ),
    );
  }

  void _openAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddStudentDialog(
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
      builder: (context) => _AddStaffDialog(reload: _load),
    );
  }

  void _openNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => const _NotificationsDialog(),
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
                        child: _buildCurrentView(),
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
    final width = _sidebarCollapsed ? 64.0 : 230.0;
    return Container(
      width: width,
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
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.secondaryText)),
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
            borderRadius: BorderRadius.circular(6),
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
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Text(
                  yearName,
                  style: const TextStyle(fontFamily: 'Switzer', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primaryText),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: AppTypography.metadata,
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.mutedText),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                filled: true,
                fillColor: AppColors.secondaryBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primaryBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primaryBorder)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Notifications',
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
    switch (_activeSection) {
      case AdminNavSection.overview:
        return _buildOverviewContent();
      case AdminNavSection.attendance:
        return _buildAttendanceContent();
      case AdminNavSection.students:
        return _buildStudentsContent();
      case AdminNavSection.staff:
        return _buildStaffContent();
      case AdminNavSection.classesAndSubjects:
        return _buildClassesAndSubjectsContent();
      case AdminNavSection.teacherAssignments:
        return _buildTeacherAssignmentsContent();
      case AdminNavSection.reports:
        return _buildReportsContent();
      case AdminNavSection.settings:
        return _buildSettingsContent();
    }
  }

  Widget _buildOverviewContent() {
    final nowFormatted = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    final yearName = _years.isNotEmpty ? '${_years.first['name'] ?? '2026-2027'}' : '2026-2027';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.statusError)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overview', style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Your school at a glance.', style: AppTypography.bodySecondary),
                    const SizedBox(width: 12),
                    Text('•  $nowFormatted  •  $yearName', style: AppTypography.metadata),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _openAddStaffDialog,
                  child: const Text('Add staff'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openAddStudentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add student'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildIntegratedStats(),
        const SizedBox(height: 28),
        _buildNeedsAttention(),
        const SizedBox(height: 28),
        _buildRecentAttendance(),
        const SizedBox(height: 28),
        _buildQuickAccess(),
      ],
    );
  }

  Widget _buildIntegratedStats() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _statSegment('TOTAL STUDENTS', '${_students.length}', 'Enrolled learners')),
            const VerticalDivider(width: 1, color: AppColors.primaryBorder),
            Expanded(child: _statSegment('TEACHING STAFF', '${_staff.length}', 'Active faculty')),
            const VerticalDivider(width: 1, color: AppColors.primaryBorder),
            Expanded(child: _statSegment('CLASSES & SECTIONS', '${_classes.length}', '${_sections.length} active cohorts')),
            const VerticalDivider(width: 1, color: AppColors.primaryBorder),
            Expanded(child: _statSegment("TODAY'S ATTENDANCE", _summaries.isNotEmpty ? '100%' : '—', '${_summaries.length} sessions logged')),
          ],
        ),
      ),
    );
  }

  Widget _statSegment(String label, String value, String helper) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontFamily: 'Switzer', fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
          const SizedBox(height: 4),
          Text(helper, style: AppTypography.metadata),
        ],
      ),
    );
  }

  Widget _buildNeedsAttention() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Needs attention', style: AppTypography.subsectionHeading),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _attentionItem(
                icon: Icons.schedule_outlined,
                title: 'Attendance Register — Afternoon verification',
                subtitle: 'Confirm that all class sections have completed afternoon period attendance recordings.',
                actionLabel: 'Check register →',
                onTap: () => setState(() => _activeSection = AdminNavSection.attendance),
              ),
              const Divider(height: 1, color: AppColors.primaryBorder),
              _attentionItem(
                icon: Icons.verified_outlined,
                title: 'Curriculum & Faculty Allocation',
                subtitle: 'All configured sections have primary teacher assignments actively mapped.',
                actionLabel: 'Review →',
                onTap: () => setState(() => _activeSection = AdminNavSection.teacherAssignments),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attentionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodySecondary),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel, style: const TextStyle(fontFamily: 'Switzer', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent attendance', style: AppTypography.subsectionHeading),
            InkWell(
              onTap: () => setState(() => _activeSection = AdminNavSection.attendance),
              child: const Text('View all →', style: TextStyle(fontFamily: 'Switzer', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.accent)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _summaries.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Text('No attendance records logged yet.', style: AppTypography.bodySecondary),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _summaries.take(5).length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                  itemBuilder: (context, index) {
                    final row = _summaries[index];
                    return InkWell(
                      onTap: () => setState(() => _activeSection = AdminNavSection.attendance),
                      hoverColor: AppColors.secondaryBackground,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text('${row['attendanceDate'] ?? ''}', style: AppTypography.compactTable),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${row['className'] ?? ''} - ${row['sectionName'] ?? ''}', style: AppTypography.compactTableMedium),
                            ),
                            Expanded(
                              child: Text('${row['kind'] ?? ''}'.toUpperCase(), style: AppTypography.metadata),
                            ),
                            Expanded(
                              child: Text(row['periodNumber'] != null ? 'Period ${row['periodNumber']}' : 'Daily', style: AppTypography.compactTable),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${row['staffName'] ?? 'Dev Teacher'}', style: AppTypography.compactTable),
                            ),
                            const Text('Details →', style: TextStyle(fontFamily: 'Switzer', fontSize: 12, color: AppColors.secondaryText)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick access', style: AppTypography.subsectionHeading),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _quickLink('Manage students', Icons.people_outline, () => setState(() => _activeSection = AdminNavSection.students)),
            _quickLink('Manage staff', Icons.badge_outlined, () => setState(() => _activeSection = AdminNavSection.staff)),
            _quickLink('Configure classes & subjects', Icons.layers_outlined, () => setState(() => _activeSection = AdminNavSection.classesAndSubjects)),
            _quickLink('Assign teachers', Icons.assignment_ind_outlined, () => setState(() => _activeSection = AdminNavSection.teacherAssignments)),
            _quickLink('Review attendance reports', Icons.analytics_outlined, () => setState(() => _activeSection = AdminNavSection.reports)),
          ],
        ),
      ],
    );
  }

  Widget _quickLink(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.mainBackground,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.compactTableMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceContent() {
    final filteredSections = _selectedClassId == null || _selectedClassId!.isEmpty
        ? _sections
        : _sections.where((s) => s['classId'] == _selectedClassId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance Register', style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                const Text('Historical and filtered class attendance sessions.', style: AppTypography.bodySecondary),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: _summaries.isEmpty ? null : _exportSummariesCsv,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(labelText: 'Filter Class'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
                    ..._classes.map((c) => DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['name']}'))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClassId = val;
                      _selectedSectionId = null;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('sec_$_selectedClassId'),
                  isExpanded: true,
                  initialValue: _selectedSectionId,
                  decoration: const InputDecoration(labelText: 'Filter Section'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
                    ...filteredSections.map((s) => DropdownMenuItem<String?>(value: s['id'] as String, child: Text('${s['name']}'))),
                  ],
                  onChanged: (val) => setState(() => _selectedSectionId = val),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _startDate,
                  decoration: InputDecoration(
                    labelText: 'From Date',
                    hintText: 'yyyy-MM-dd',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _startDate.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _endDate,
                  decoration: InputDecoration(
                    labelText: 'To Date',
                    hintText: 'yyyy-MM-dd',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _endDate.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _loadSummaries,
                icon: const Icon(Icons.filter_alt_outlined, size: 16),
                label: const Text('Filter'),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedClassId = null;
                    _selectedSectionId = null;
                    _startDate.clear();
                    _endDate.clear();
                  });
                  _loadSummaries();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildTable(
          title: 'Recorded Sessions (${_summaries.length})',
          rows: _summaries,
          columns: const ['attendanceDate', 'className', 'sectionName', 'kind', 'periodNumber', 'staffName'],
          headers: const ['Date', 'Class', 'Section', 'Kind', 'Period', 'Staff'],
        ),
      ],
    );
  }

  Widget _buildStudentsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Students Directory', style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                const Text('Click any student to view their attendance rate and session history.', style: AppTypography.bodySecondary),
              ],
            ),
            FilledButton.icon(
              onPressed: _openAddStudentDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add student'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTable(
          title: 'Enrolled Students (${_students.length})',
          rows: _students,
          columns: const ['admissionNumber', 'fullName', 'rollNumber'],
          headers: const ['Admission No.', 'Full Name', 'Roll No.'],
          onRowTap: _showStudentDialog,
        ),
      ],
    );
  }

  Widget _buildStaffContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teaching & Administrative Staff', style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                const Text('Faculty directory, contact information, and roles.', style: AppTypography.bodySecondary),
              ],
            ),
            FilledButton.icon(
              onPressed: _openAddStaffDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add staff'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTable(
          title: 'Staff Members (${_staff.length})',
          rows: _staff,
          columns: const ['fullName', 'email', 'phone'],
          headers: const ['Full Name', 'Email', 'Phone'],
        ),
      ],
    );
  }

  Widget _buildClassesAndSubjectsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Classes & Subjects', style: AppTypography.pageTitle),
        const SizedBox(height: 4),
        const Text('Configure academic structure, cohorts, and curricula.', style: AppTypography.bodySecondary),
        const SizedBox(height: 24),
        _SetupGrid(
          reload: _load,
          years: _years,
          classes: _classes,
          sections: _sections,
          subjects: _subjects,
          staff: _staff,
        ),
      ],
    );
  }

  Widget _buildTeacherAssignmentsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Teacher Assignments', style: AppTypography.pageTitle),
        const SizedBox(height: 4),
        const Text('Manage faculty assignments to class sections and specific subjects.', style: AppTypography.bodySecondary),
        const SizedBox(height: 24),
        _QuickCreateCard(
          title: 'Create Teacher Assignment',
          fields: [
            _FieldSpec.select('staffId', 'Teacher', _staff, labelKey: 'fullName'),
            _FieldSpec.select('academicYearId', 'Academic year', _years),
            _FieldSpec.select('classId', 'Class', _classes),
            _FieldSpec.select('sectionId', 'Section', _sections),
            _FieldSpec.select('subjectId', 'Subject', _subjects, nullable: true),
          ],
          defaults: const {'canTakeDailyAttendance': true},
          path: '/api/v1/admin/teacher-assignments',
          reload: _load,
        ),
        const SizedBox(height: 20),
        _buildTable(
          title: 'Active Assignments (${_assignments.length})',
          rows: _assignments,
          columns: const ['staffName', 'className', 'sectionName', 'subjectName'],
          headers: const ['Teacher', 'Class', 'Section', 'Subject'],
        ),
      ],
    );
  }

  Widget _buildReportsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reports & Export', style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                const Text('Regulatory compliance summaries and audit exports.', style: AppTypography.bodySecondary),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: _summaries.isEmpty ? null : _exportSummariesCsv,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendance Summary Metrics', style: AppTypography.sectionHeading),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _metricBox('Total Sessions', '${_summaries.length}')),
                  const SizedBox(width: 16),
                  Expanded(child: _metricBox('Enrolled Students', '${_students.length}')),
                  const SizedBox(width: 16),
                  Expanded(child: _metricBox('Active Classes', '${_classes.length}')),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Download complete historical dataset as comma-separated values for external reporting and regulatory audits.', style: AppTypography.bodySecondary),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _exportSummariesCsv,
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('Download Full Attendance CSV'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontFamily: 'Switzer', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('System Settings', style: AppTypography.pageTitle),
        const SizedBox(height: 4),
        const Text('Application environment, academic defaults, and database connectivity.', style: AppTypography.bodySecondary),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('School Information', style: AppTypography.sectionHeading),
              const SizedBox(height: 16),
              _settingRow('Application Version', 'Schoolic V1 Pilot MVP'),
              _settingRow('Typography', 'Switzer (Fontshare Free License)'),
              _settingRow('Design System', 'Minimalist Precision (1440x900 Desktop-First)'),
              _settingRow('Database', 'Neon Serverless PostgreSQL (Drizzle ORM)'),
              _settingRow('API Gateway', 'Cloudflare Worker (Hono Framework)'),
              _settingRow('Active Academic Year', _years.isNotEmpty ? '${_years.first['name']}' : '2026-2027'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySecondary),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildTable({
    required String title,
    required List<Map<String, Object?>> rows,
    required List<String> columns,
    required List<String> headers,
    void Function(Map<String, Object?> row)? onRowTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(title, style: AppTypography.subsectionHeading),
          ),
          const Divider(height: 1, color: AppColors.primaryBorder),
          if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('No records available.', style: AppTypography.bodySecondary),
            )
          else ...[
            Container(
              color: AppColors.secondaryBackground,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: headers
                    .map(
                      (h) => Expanded(
                        child: Text(h, style: AppTypography.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
              itemBuilder: (context, index) {
                final row = rows[index];
                return InkWell(
                  onTap: onRowTap != null ? () => onRowTap(row) : null,
                  hoverColor: AppColors.secondaryBackground,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: columns
                          .map(
                            (c) => Expanded(
                              child: Text(
                                '${row[c] ?? '—'}',
                                style: AppTypography.compactTable,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('School Notifications', style: AppTypography.sectionHeading),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _notificationItem('Today', 'Grade 10 - Section A daily attendance recorded.'),
            _notificationItem('Yesterday', 'New student admission STU-002 registered.'),
            _notificationItem('2 days ago', 'Teacher assignment updated for Dev Teacher.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _notificationItem(String time, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: AppTypography.metadata),
          const SizedBox(height: 2),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _AddStudentDialog extends ConsumerStatefulWidget {
  const _AddStudentDialog({
    required this.years,
    required this.classes,
    required this.sections,
    required this.reload,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final Future<void> Function() reload;

  @override
  ConsumerState<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<_AddStudentDialog> {
  final _admissionNo = TextEditingController();
  final _fullName = TextEditingController();
  final _rollNo = TextEditingController();
  String? _yearId;
  String? _classId;
  String? _sectionId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.years.isNotEmpty) _yearId = widget.years.first['id'] as String;
    if (widget.classes.isNotEmpty) _classId = widget.classes.first['id'] as String;
    if (widget.sections.isNotEmpty) _sectionId = widget.sections.first['id'] as String;
  }

  @override
  void dispose() {
    _admissionNo.dispose();
    _fullName.dispose();
    _rollNo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'admissionNumber': _admissionNo.text.trim(),
        'fullName': _fullName.text.trim(),
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        'rollNumber': _rollNo.text.trim().isEmpty ? null : _rollNo.text.trim(),
      };
      await ref.read(apiClientProvider).postJson('/api/v1/admin/students', body, session: session);
      await widget.reload();
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Student', style: AppTypography.sectionHeading),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.statusError)),
                ),
              TextField(
                controller: _admissionNo,
                decoration: const InputDecoration(labelText: 'Admission Number *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _yearId,
                decoration: const InputDecoration(labelText: 'Academic Year *'),
                items: widget.years
                    .map((y) => DropdownMenuItem(value: y['id'] as String, child: Text('${y['name']}')))
                    .toList(),
                onChanged: (val) => setState(() => _yearId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: widget.classes
                    .map((c) => DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}')))
                    .toList(),
                onChanged: (val) => setState(() => _classId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sectionId,
                decoration: const InputDecoration(labelText: 'Section *'),
                items: widget.sections
                    .map((s) => DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}')))
                    .toList(),
                onChanged: (val) => setState(() => _sectionId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rollNo,
                decoration: const InputDecoration(labelText: 'Roll Number (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save student'),
        ),
      ],
    );
  }
}

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog({required this.reload});

  final Future<void> Function() reload;

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      };
      await ref.read(apiClientProvider).postJson('/api/v1/admin/staff', body, session: session);
      await widget.reload();
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Staff Member', style: AppTypography.sectionHeading),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.statusError)),
              ),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save staff'),
        ),
      ],
    );
  }
}

class _StudentAttendanceDialog extends ConsumerStatefulWidget {
  const _StudentAttendanceDialog({
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;

  @override
  ConsumerState<_StudentAttendanceDialog> createState() => _StudentAttendanceDialogState();
}

class _StudentAttendanceDialogState extends ConsumerState<_StudentAttendanceDialog> {
  bool _loading = true;
  String? _error;
  Map<String, Object?>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final res = await ref.read(apiClientProvider).getJson(
            '/api/v1/admin/students/${widget.studentId}/attendance-summary',
            session: session,
          );
      setState(() => _data = res);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ((_data?['records'] as List?) ?? const []).cast<Map<String, Object?>>();
    final rate = _data?['attendanceRate'] != null ? '${_data!['attendanceRate']}%' : '—';
    final total = _data?['totalSessions']?.toString() ?? '0';
    final present = _data?['presentCount']?.toString() ?? '0';
    final absent = _data?['absentCount']?.toString() ?? '0';
    final lateCount = _data?['lateCount']?.toString() ?? '0';
    final excused = _data?['excusedCount']?.toString() ?? '0';

    return AlertDialog(
      title: Text('${widget.studentName} — Attendance History', style: AppTypography.sectionHeading),
      content: SizedBox(
        width: 580,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryText))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.statusError)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _miniMetric('Attendance Rate', rate, AppColors.accent),
                          _miniMetric('Total Sessions', total, AppColors.primaryText),
                          _miniMetric('Present', present, AppColors.statusSuccess),
                          _miniMetric('Absent', absent, AppColors.statusError),
                          _miniMetric('Late', lateCount, AppColors.statusWarning),
                          _miniMetric('Excused', excused, AppColors.statusInfo),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Session Records', style: AppTypography.subsectionHeading),
                      const SizedBox(height: 8),
                      Expanded(
                        child: records.isEmpty
                            ? const Center(child: Text('No attendance records logged for this student yet.', style: AppTypography.bodySecondary))
                            : ListView.separated(
                                itemCount: records.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                                itemBuilder: (context, index) {
                                  final r = records[index];
                                  final status = '${r['status'] ?? ''}';
                                  Color badgeColor;
                                  switch (status) {
                                    case 'present':
                                      badgeColor = AppColors.statusSuccess;
                                    case 'absent':
                                      badgeColor = AppColors.statusError;
                                    case 'late':
                                      badgeColor = AppColors.statusWarning;
                                    case 'excused':
                                      badgeColor = AppColors.statusInfo;
                                    default:
                                      badgeColor = AppColors.secondaryText;
                                  }
                                  return ListTile(
                                    dense: true,
                                    title: Text('${r['className']} - ${r['sectionName']} (${r['kind']})', style: AppTypography.compactTableMedium),
                                    subtitle: Text('Date: ${r['date']}', style: AppTypography.metadata),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
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
        final columns = constraints.maxWidth > 900 ? 2 : 1;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: _QuickCreateCard(
                title: 'Academic Year',
                fields: const [
                  _FieldSpec('name', 'Year name', hint: '2026-2027'),
                  _FieldSpec('startDate', 'Start date', hint: '2026-06-01'),
                  _FieldSpec('endDate', 'End date', hint: '2027-04-30'),
                ],
                path: '/api/v1/admin/academic-years',
                reload: reload,
              ),
            ),
            SizedBox(
              width: columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: _QuickCreateCard(
                title: 'Class',
                fields: const [
                  _FieldSpec('name', 'Class name', hint: 'Grade 10'),
                  _FieldSpec('code', 'Code', hint: 'G10'),
                  _FieldSpec('stage', 'Stage', hint: 'Secondary'),
                  _FieldSpec('sequenceNumber', 'Sequence', hint: '10', number: true),
                ],
                path: '/api/v1/admin/classes',
                reload: reload,
              ),
            ),
            SizedBox(
              width: columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: _QuickCreateCard(
                title: 'Section',
                fields: [
                  _FieldSpec.select('classId', 'Class', classes),
                  const _FieldSpec('name', 'Section name', hint: 'Section A'),
                  const _FieldSpec('roomNumber', 'Room', hint: 'Room 204'),
                  const _FieldSpec('capacity', 'Capacity', hint: '40', number: true),
                ],
                path: '/api/v1/admin/sections',
                reload: reload,
              ),
            ),
            SizedBox(
              width: columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
              child: _QuickCreateCard(
                title: 'Subject',
                fields: const [
                  _FieldSpec('name', 'Subject name', hint: 'Mathematics'),
                  _FieldSpec('code', 'Code', hint: 'MATH-10'),
                ],
                path: '/api/v1/admin/subjects',
                reload: reload,
              ),
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
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectValues = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.options == null) {
        _controllers[field.key] = TextEditingController();
      } else {
        _selectValues[field.key] = field.options!.isNotEmpty ? field.options!.first['id'] as String? : null;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, Object?>{...widget.defaults};
      for (final field in widget.fields) {
        if (field.options == null) {
          final value = _controllers[field.key]!.text.trim();
          if (value.isNotEmpty) {
            body[field.key] = field.number ? int.parse(value) : value;
          }
        } else {
          final value = _selectValues[field.key];
          if (value != null && value.isNotEmpty) {
            body[field.key] = value;
          }
        }
      }
      await ref.read(apiClientProvider).postJson(widget.path, body, session: session);
      for (final controller in _controllers.values) {
        controller.clear();
      }
      await widget.reload();
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTypography.subsectionHeading),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.statusError)),
              ),
            ...widget.fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.options == null
                    ? TextFormField(
                        controller: _controllers[field.key],
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                        ),
                      )
                    : DropdownButtonFormField<String?>(
                        initialValue: _selectValues[field.key],
                        decoration: InputDecoration(labelText: field.label),
                        items: [
                          if (field.nullable)
                            const DropdownMenuItem<String?>(value: null, child: Text('None')),
                          ...?field.options?.map(
                            (option) => DropdownMenuItem<String?>(
                              value: option['id'] as String?,
                              child: Text('${option[field.labelKey]}'),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _selectValues[field.key] = value),
                      ),
              );
            }),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.add, size: 16),
                label: Text('Create ${widget.title.toLowerCase()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

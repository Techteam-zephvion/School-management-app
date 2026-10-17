import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../../core/api_client.dart';
import '../../core/csv_exporter.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/app_dialog.dart';
import '../shared/components/command_palette.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/schoolic_logo.dart';
import '../shared/components/shortcuts_dialog.dart';
import '../shared/components/tour_dialog.dart';
import '../shared/views/announcements_view.dart';
import 'dialogs/add_staff_dialog.dart';
import 'dialogs/add_student_dialog.dart';
import 'dialogs/student_attendance_dialog.dart';
import 'views/admin_admissions_view.dart';
import 'views/admin_assignments_view.dart';
import 'views/admin_attendance_view.dart';
import 'views/admin_ai_usage_view.dart';
import 'views/admin_classes_view.dart';
import 'views/admin_exams_view.dart';
import 'views/admin_fees_view.dart';
import 'views/admin_insights_view.dart';

import 'views/admin_overview_view.dart';
import 'views/admin_reports_view.dart';
import 'views/admin_settings_view.dart';
import 'views/admin_staff_view.dart';
import 'views/admin_students_view.dart';
import 'views/admin_timetable_view.dart';
import 'views/admin_communications_view.dart';
import 'views/admin_compliance_view.dart';
import 'views/admin_operations_view.dart';
import 'views/admin_campus_view.dart';

enum AdminNavSection {
  overview,
  attendance,
  insights,
  aiUsage,
  announcements,
  admissions,
  operations,
  campus,
  students,
  staff,
  classesAndSubjects,
  teacherAssignments,
  timetable,
  exams,
  fees,
  communications,
  compliance,
  reports,
  settings,
}


class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with WidgetsBindingObserver {
  AdminNavSection _activeSection = AdminNavSection.overview;
  bool _sidebarCollapsed = false;

  List<Map<String, Object?>> _years = [];
  List<Map<String, Object?>> _classes = [];
  List<Map<String, Object?>> _sections = [];
  List<Map<String, Object?>> _subjects = [];
  List<Map<String, Object?>> _staff = [];
  List<Map<String, Object?>> _students = [];
  List<Map<String, Object?>> _assignments = [];
  List<Map<String, Object?>> _timetable = [];
  List<Map<String, Object?>> _exams = [];
  List<Map<String, Object?>> _summaries = [];
  String _schoolName = 'Schoolic';
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  Timer? _realtimeSyncTimer;

  String? _selectedClassId;
  String? _selectedSectionId;
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();

    // Background real-time live sync every 25s (bypassed in test harness)
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _realtimeSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (mounted) _load(silent: true);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await TourDialog.shouldShowAutoTour()) {
        if (mounted) {
          TourDialog.show(context, isFirstVisit: true);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    _realtimeSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _startDate.dispose();
    _endDate.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final auth = ref.read(authControllerProvider);
    if (auth.isLoading) return;
    final session = auth.session;
    if (session == null) {
      if (mounted && !silent) setState(() => _loading = false);
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
        api.getList('/api/v1/admin/timetable', session: session),
        api.getList('/api/v1/admin/exams', session: session),
        api
            .getJson('/api/v1/admin/overview', session: session)
            .then((res) {
              final school = res['school'] as Map<String, Object?>?;
              if (school != null && school['name'] != null) {
                _schoolName = school['name'] as String;
              }
              return <Map<String, Object?>>[];
            })
            .catchError((_) => <Map<String, Object?>>[]),
      ]);
      setState(() {
        _years = results[0];
        _classes = results[1];
        _sections = results[2];
        _subjects = results[3];
        _staff = results[4];
        _students = results[5];
        _assignments = results[6];
        _timetable = results[7];
        _exams = results[8];
        _hasLoaded = true;
        _error = null;
      });
      await _loadSummaries();
    } on ApiException catch (exception) {
      if (!silent && !_hasLoaded) setState(() => _error = exception.message);
    } catch (e) {
      if (!silent && !_hasLoaded) setState(() => _error = e.toString());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadSummaries() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final queryParams = <String, String>{
        if (_selectedClassId != null && _selectedClassId!.isNotEmpty)
          'classId': _selectedClassId!,
        if (_selectedSectionId != null && _selectedSectionId!.isNotEmpty)
          'sectionId': _selectedSectionId!,
        if (_startDate.text.trim().isNotEmpty)
          'startDate': _startDate.text.trim(),
        if (_endDate.text.trim().isNotEmpty) 'endDate': _endDate.text.trim(),
      };
      final qs = queryParams.isEmpty
          ? ''
          : '?${Uri(queryParameters: queryParams).query}';
      final res = await ref
          .read(apiClientProvider)
          .getJson('/api/v1/admin/attendance-summary$qs', session: session);
      setState(() {
        _summaries = ((res['sessions'] as List?) ?? const [])
            .cast<Map<String, Object?>>();
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
    final keys = [
      'attendanceDate',
      'className',
      'sectionName',
      'kind',
      'periodNumber',
      'staffName',
    ];
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
            _activityTile(
              'Today',
              'Attendance register synchronized for ${_summaries.length} sessions.',
            ),
            _activityTile(
              'Active Term',
              '${_classes.length} classes and ${_sections.length} sections active.',
            ),
            _activityTile(
              'Faculty',
              '${_staff.length} staff members and ${_assignments.length} assignments.',
            ),
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
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    if (!auth.isLoading && session != null && !_hasLoaded && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasLoaded) _load();
      });
    }

    if ((_loading || auth.isLoading) && !_hasLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryText,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

    final safePadding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(isDrawer: false),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isMobile: isMobile, topInset: safePadding.top),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 32,
                      isMobile ? 20 : 28,
                      isMobile ? 16 : 32,
                      (isMobile ? 24 : 28) + safePadding.bottom,
                    ),
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

  Widget _buildSidebar({bool isDrawer = false}) {
    final session = ref.watch(authControllerProvider).session;
    return Container(
      width: isDrawer ? 280.0 : (_sidebarCollapsed ? 64.0 : 230.0),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(right: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              padding: EdgeInsets.symmetric(
                horizontal: (!isDrawer && _sidebarCollapsed) ? 12 : 20,
              ),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.primaryBorder),
                ),
              ),
              child: (!isDrawer && _sidebarCollapsed)
                  ? const Center(child: SchoolicLogo.compact(size: 20))
                  : Row(
                      children: [
                        const SchoolicLogo(size: 20),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sidebarItem(
                    AdminNavSection.overview,
                    Icons.grid_view_outlined,
                    'Overview',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.attendance,
                    Icons.fact_check_outlined,
                    'Attendance',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.insights,
                    Icons.auto_awesome_outlined,
                    'Insights',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.aiUsage,
                    Icons.speed_outlined,
                    'AI Usage',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.announcements,
                    Icons.campaign_outlined,
                    'Announcements',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.admissions,
                    Icons.how_to_reg_outlined,
                    'Admissions',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.operations,
                    Icons.commute_outlined,
                    'Operations',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.campus,
                    Icons.domain_rounded,
                    'Campus ERP',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.students,
                    Icons.people_outline,
                    'Students',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.staff,
                    Icons.badge_outlined,
                    'Staff',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.classesAndSubjects,
                    Icons.layers_outlined,
                    'Classes & Subjects',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.teacherAssignments,
                    Icons.assignment_ind_outlined,
                    'Teacher Assignments',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.timetable,
                    Icons.calendar_month_outlined,
                    'Timetable',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.exams,
                    Icons.assignment_outlined,
                    'Exams',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.fees,
                    Icons.payments_outlined,
                    'Fees & Finance',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.communications,
                    Icons.campaign_outlined,
                    'Communications & Import',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.compliance,
                    Icons.verified_user_outlined,
                    'DPDP & Compliance',
                    isDrawer: isDrawer,
                  ),
                  _sidebarItem(
                    AdminNavSection.reports,
                    Icons.analytics_outlined,
                    'Reports',
                    isDrawer: isDrawer,
                  ),

                  _sidebarItem(
                    AdminNavSection.settings,
                    Icons.settings_outlined,
                    'Settings',
                    isDrawer: isDrawer,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(height: 1, color: AppColors.primaryBorder),
                  ),
                  _sidebarActionItem(
                    icon: Icons.explore_outlined,
                    label: 'Tutorial',
                    isDrawer: isDrawer,
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      TourDialog.show(context);
                    },
                  ),
                  _sidebarActionItem(
                    icon: Icons.keyboard_outlined,
                    label: 'Shortcuts',
                    isDrawer: isDrawer,
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      ShortcutsDialog.show(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),
            if (isDrawer)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session?.email ?? 'admin@schoolic.app',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      iconSize: 18,
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(authControllerProvider).signOut();
                      },
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () =>
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: _sidebarCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(
                        _sidebarCollapsed
                            ? Icons.keyboard_double_arrow_right
                            : Icons.keyboard_double_arrow_left,
                        size: 16,
                        color: AppColors.mutedText,
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        const Text(
                          'Collapse sidebar',
                          style: AppTypography.metadata,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(
    AdminNavSection section,
    IconData icon,
    String label, {
    bool isDrawer = false,
  }) {
    final active = _activeSection == section;
    final collapsed = !isDrawer && _sidebarCollapsed;
    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: () {
          setState(() => _activeSection = section);
          if (isDrawer) Navigator.of(context).pop();
        },
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 12),
          decoration: BoxDecoration(
            color: active ? AppColors.secondaryBackground : Colors.transparent,
            borderRadius: AppRadii.rMd,
            border: active
                ? const Border(
                    left: BorderSide(color: AppColors.primaryText, width: 2),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.primaryText : AppColors.secondaryText,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: active
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
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

  Widget _sidebarActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDrawer = false,
  }) {
    final collapsed = !isDrawer && _sidebarCollapsed;
    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 12),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.secondaryText),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.secondaryText,
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

  Widget _buildTopBar({bool isMobile = false, double topInset = 0}) {
    final session = ref.watch(authControllerProvider).session;
    final yearName = _years.isNotEmpty
        ? '${_years.first['name'] ?? '2026-2027'}'
        : '2026-2027';

    return Container(
      height: 52 + topInset,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 24,
        topInset,
        isMobile ? 8 : 24,
        0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            if (isMobile) ...[
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(
                    Icons.menu,
                    size: 20,
                    color: AppColors.primaryText,
                  ),
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                _sectionTitle(_activeSection),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 20),
              Container(width: 1, height: 16, color: AppColors.primaryBorder),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryBorder),
                  borderRadius: AppRadii.rMd,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppColors.secondaryText,
                    ),
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
            ],
            const SizedBox(width: 14),
            InkWell(
              borderRadius: AppRadii.rMd,
              onTap: () => CommandPaletteDialog.show(
                context,
                onActionSelected: _handleCommandPaletteAction,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 14, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      isMobile ? 'Search' : 'Quick Actions...',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.mainBackground,
                          borderRadius: AppRadii.rSm,
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Text(
                          '⌘K',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!isMobile) ...[
              IconButton(
                tooltip: 'System activity',
                iconSize: 18,
                onPressed: _openNotificationsDialog,
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: 'App Tutorial',
              iconSize: 18,
              onPressed: () => TourDialog.show(context),
              icon: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.secondaryText,
              ),
            ),
            IconButton(
              tooltip: 'Refresh data',
              iconSize: 18,
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: AppColors.primaryBorder),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  session?.email ?? 'admin@schoolic.app',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              tooltip: 'Sign out',
              iconSize: 16,
              onPressed: () => ref.read(authControllerProvider).signOut(),
              icon: const Icon(Icons.logout, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitle(AdminNavSection section) {
    switch (section) {
      case AdminNavSection.overview:
        return 'Overview';
      case AdminNavSection.attendance:
        return 'Attendance Register';
      case AdminNavSection.insights:
        return 'Insights';
      case AdminNavSection.aiUsage:
        return 'AI Usage';
      case AdminNavSection.announcements:
        return 'Announcements';
      case AdminNavSection.admissions:
        return 'Admissions';
      case AdminNavSection.operations:
        return 'School Operations';
      case AdminNavSection.campus:
        return 'Campus Operations';
      case AdminNavSection.students:
        return 'Students';
      case AdminNavSection.staff:
        return 'Teaching & Staff';
      case AdminNavSection.classesAndSubjects:
        return 'Classes & Subjects';
      case AdminNavSection.teacherAssignments:
        return 'Teacher Assignments';
      case AdminNavSection.timetable:
        return 'Timetable';
      case AdminNavSection.exams:
        return 'Exams & Marks';
      case AdminNavSection.fees:
        return 'Fees & Finance';
      case AdminNavSection.communications:
        return 'Communications & Import';
      case AdminNavSection.compliance:
        return 'DPDP & Compliance';
      case AdminNavSection.reports:
        return 'Reports & Export';
      case AdminNavSection.settings:
        return 'Settings';
    }
  }


  Widget _buildCurrentView() {
    final activeYear = _years.isNotEmpty
        ? '${_years.first['name'] ?? '2026-2027'}'
        : '2026-2027';

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
          onNavigateToSection: (section) => setState(() {
            _activeSection = switch (section) {
              'attendance' => AdminNavSection.attendance,
              'insights' => AdminNavSection.insights,
              'students' => AdminNavSection.students,
              'staff' => AdminNavSection.staff,
              'classes' => AdminNavSection.classesAndSubjects,
              'assignments' => AdminNavSection.teacherAssignments,
              'reports' => AdminNavSection.reports,
              _ => AdminNavSection.overview,
            };
          }),
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
      case AdminNavSection.insights:
        return AdminInsightsView(classes: _classes, sections: _sections);
      case AdminNavSection.aiUsage:
        return const AdminAiUsageView();
      case AdminNavSection.announcements:
        return AnnouncementsView(
          workspace: AnnouncementWorkspace.admin,
          endpoint: '/api/v1/admin/announcements',
          classes: _classes,
          sections: _sections,
        );
      case AdminNavSection.students:
        return AdminStudentsView(
          students: _students,
          classes: _classes,
          sections: _sections,
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
      case AdminNavSection.timetable:
        return AdminTimetableView(
          years: _years,
          classes: _classes,
          sections: _sections,
          subjects: _subjects,
          staff: _staff,
          assignments: _assignments,
          entries: _timetable,
          reload: _load,
        );
      case AdminNavSection.exams:
        return AdminExamsView(
          exams: _exams,
          years: _years,
          classes: _classes,
          sections: _sections,
          subjects: _subjects,
          reload: _load,
        );
      case AdminNavSection.fees:
        return AdminFeesView(
          years: _years,
          classes: _classes,
          sections: _sections,
          students: _students,
          reload: _load,
        );
      case AdminNavSection.admissions:
        return AdminAdmissionsView(
          years: _years,
          classes: _classes,
          sections: _sections,
          reload: _load,
        );
      case AdminNavSection.operations:
        return AdminOperationsView(
          students: _students,
          staff: _staff,
          classes: _classes,
          sections: _sections,
        );
      case AdminNavSection.campus:
        return AdminCampusView(
          students: _students,
          staff: _staff,
        );
      case AdminNavSection.communications:
        return AdminCommunicationsView(
          years: _years,
          classes: _classes,
          sections: _sections,
          reload: _load,
        );
      case AdminNavSection.compliance:
        return AdminComplianceView(
          students: _students,
        );
      case AdminNavSection.reports:
        return AdminReportsView(

          summaries: _summaries,
          students: _students,
          classes: _classes,
          onExportCsv: _exportSummariesCsv,
        );
      case AdminNavSection.settings:
        return AdminSettingsView(years: _years, schoolName: _schoolName);
    }
  }

  void _handleCommandPaletteAction(String action) {
    if (action.startsWith('nav:')) {
      final dest = action.replaceFirst('nav:', '');
      switch (dest) {
        case 'overview':
          setState(() => _activeSection = AdminNavSection.overview);
          break;
        case 'students':
          setState(() => _activeSection = AdminNavSection.students);
          break;
        case 'attendance':
          setState(() => _activeSection = AdminNavSection.attendance);
          break;
        case 'exams':
          setState(() => _activeSection = AdminNavSection.exams);
          break;
        case 'fees':
          setState(() => _activeSection = AdminNavSection.fees);
          break;
        case 'operations':
          setState(() => _activeSection = AdminNavSection.operations);
          break;
        case 'campus':
          setState(() => _activeSection = AdminNavSection.campus);
          break;
        case 'compliance':
          setState(() => _activeSection = AdminNavSection.compliance);
          break;
        case 'insights':
          setState(() => _activeSection = AdminNavSection.insights);
          break;
      }
    } else if (action == 'action:nl_query' || action == 'action:at_risk') {
      setState(() => _activeSection = AdminNavSection.insights);
    } else if (action.startsWith('action:campus_')) {
      setState(() => _activeSection = AdminNavSection.campus);
    } else if (action == 'action:shortcuts') {
      ShortcutsDialog.show(context);
    } else if (action == 'action:new_announcement') {
      setState(() => _activeSection = AdminNavSection.announcements);
    } else if (action == 'action:take_attendance') {
      setState(() => _activeSection = AdminNavSection.attendance);
    }
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';
import 'views/teacher_attendance_view.dart';
import 'views/teacher_classes_view.dart';
import 'views/teacher_my_day_view.dart';
import 'views/teacher_timetable_view.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  int _activeTab = 0;
  List<Map<String, Object?>> _assignments = [];
  List<Map<String, Object?>> _timetable = [];
  List<Map<String, Object?>> _recentSessions = [];
  Map<String, Object?>? _selectedAssignment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getList('/api/v1/teacher/assignments', session: session),
        api.getList('/api/v1/teacher/timetable', session: session),
        api.getJson('/api/v1/teacher/attendance/summary', session: session).catchError((_) => {'sessions': []}),
      ]);

      final assignments = results[0] as List<Map<String, Object?>>;
      final timetable = results[1] as List<Map<String, Object?>>;
      final summaryJson = results[2] as Map<String, Object?>;
      final sessions = ((summaryJson['sessions'] as List?) ?? const []).cast<Map<String, Object?>>();

      setState(() {
        _assignments = assignments;
        _timetable = timetable;
        _recentSessions = sessions;
        if (_selectedAssignment == null && assignments.isNotEmpty) {
          _selectedAssignment = assignments.first;
        }
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectAssignmentAndTakeAttendance(Map<String, Object?> assignment) {
    setState(() {
      _selectedAssignment = assignment;
      _activeTab = 3;
    });
  }

  void _selectTimetableEntryAndTakeAttendance(Map<String, Object?> entry) {
    final matchingAssignments = _assignments.where((assignment) {
      return assignment['academicYearId'] == entry['academicYearId'] &&
          assignment['classId'] == entry['classId'] &&
          assignment['sectionId'] == entry['sectionId'] &&
          assignment['subjectId'] == entry['subjectId'];
    });
    final baseAssignment = matchingAssignments.isEmpty ? null : matchingAssignments.first;

    setState(() {
      _selectedAssignment = {
        ...(baseAssignment ?? entry),
        'academicYearId': entry['academicYearId'],
        'classId': entry['classId'],
        'sectionId': entry['sectionId'],
        'subjectId': entry['subjectId'],
        'className': entry['className'],
        'sectionName': entry['sectionName'],
        'subjectName': entry['subjectName'],
        'periodNumber': entry['periodNumber'],
        'attendanceDate': _todayIso(),
      };
      _activeTab = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

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
      drawer: isMobile ? _buildTeacherDrawer(session) : null,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
          child: Row(
            children: [
              if (isMobile) ...[
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, size: 20, color: AppColors.primaryText),
                    tooltip: 'Open navigation',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Text(
                'schoolic.',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadii.rSm,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Text(
                  'TEACHER',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 24),
                // Navigation tab buttons
                _buildTabButton(0, 'My Day', Icons.dashboard_outlined),
                const SizedBox(width: 4),
                _buildTabButton(1, 'My Week', Icons.calendar_month_outlined),
                const SizedBox(width: 4),
                _buildTabButton(2, 'My Classes', Icons.layers_outlined),
                const SizedBox(width: 4),
                _buildTabButton(3, 'Attendance Register', Icons.fact_check_outlined),
              ],

              const Spacer(),

              // Refresh button
              IconButton(
                tooltip: 'Refresh data',
                iconSize: 18,
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
              ),

              if (!isMobile) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: AppColors.primaryBorder),
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    session?.displayName ?? session?.email ?? 'Faculty',
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 18 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  FeedbackBanner(
                    message: _error!,
                    tone: FeedbackTone.error,
                    onDismiss: () => setState(() => _error = null),
                  ),
                _buildActiveTabContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherDrawer(AuthSession? session) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
              ),
              child: Row(
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
                      'TEACHER',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
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
                  _drawerTabItem(0, 'My Day', Icons.dashboard_outlined),
                  _drawerTabItem(1, 'My Week', Icons.calendar_month_outlined),
                  _drawerTabItem(2, 'My Classes', Icons.layers_outlined),
                  _drawerTabItem(3, 'Attendance Register', Icons.fact_check_outlined),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (session?.displayName != null)
                          Text(
                            session!.displayName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryText,
                            ),
                          ),
                        Text(
                          session?.email ?? 'teacher@schoolic.local',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    iconSize: 18,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(authControllerProvider).signOut();
                    },
                    icon: const Icon(Icons.logout, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() => _activeTab = index);
        Navigator.of(context).pop();
      },
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryBackground : Colors.transparent,
          borderRadius: AppRadii.rMd,
          border: isSelected ? const Border(left: BorderSide(color: AppColors.primaryText, width: 2)) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: AppRadii.rMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryBackground : Colors.transparent,
          borderRadius: AppRadii.rMd,
          border: isSelected ? Border.all(color: AppColors.primaryBorder) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    final session = ref.watch(authControllerProvider).session;

    switch (_activeTab) {
      case 0:
        return TeacherMyDayView(
          assignments: _assignments,
          timetableEntries: _timetable,
          recentSessions: _recentSessions,
          teacherDisplayName: session?.displayName,
          teacherEmail: session?.email,
          onSelectAssignmentAndTakeAttendance: _selectAssignmentAndTakeAttendance,
          onSelectTimetableEntryAndTakeAttendance: _selectTimetableEntryAndTakeAttendance,
          onNavigateToRegister: () => setState(() => _activeTab = 3),
        );
      case 1:
        return TeacherTimetableView(
          entries: _timetable,
          onTakeAttendance: _selectTimetableEntryAndTakeAttendance,
        );
      case 2:
        return TeacherClassesView(
          assignments: _assignments,
          onTakeAttendance: _selectAssignmentAndTakeAttendance,
        );
      case 3:
        final attendanceAssignments = _selectedAssignment == null || _assignments.contains(_selectedAssignment)
            ? _assignments
            : [_selectedAssignment!, ..._assignments];
        return TeacherAttendanceView(
          assignments: attendanceAssignments,
          selectedAssignment: _selectedAssignment,
          onAssignmentChanged: (val) => setState(() => _selectedAssignment = val),
          onAttendanceSaved: _loadData,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

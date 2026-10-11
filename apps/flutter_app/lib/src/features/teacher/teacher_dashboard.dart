import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';
import 'views/teacher_attendance_view.dart';
import 'views/teacher_classes_view.dart';
import 'views/teacher_my_day_view.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  int _activeTab = 0; // 0: My Day, 1: My Classes, 2: Attendance Register
  List<Map<String, Object?>> _assignments = [];
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
        api.getJson('/api/v1/teacher/attendance/summary', session: session).catchError((_) => {'sessions': []}),
      ]);

      final assignments = results[0] as List<Map<String, Object?>>;
      final summaryJson = results[1] as Map<String, Object?>;
      final sessions = ((summaryJson['sessions'] as List?) ?? const []).cast<Map<String, Object?>>();

      setState(() {
        _assignments = assignments;
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
      _activeTab = 2; // Switch to Attendance Register tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
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
              const SizedBox(width: 24),

              // Navigation tab buttons
              _buildTabButton(0, 'My Day', Icons.dashboard_outlined),
              const SizedBox(width: 4),
              _buildTabButton(1, 'My Classes', Icons.layers_outlined),
              const SizedBox(width: 4),
              _buildTabButton(2, 'Attendance Register', Icons.fact_check_outlined),

              const Spacer(),

              // Refresh button
              IconButton(
                tooltip: 'Refresh data',
                iconSize: 18,
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: AppColors.secondaryText),
              ),
              const SizedBox(width: 8),

              Container(width: 1, height: 16, color: AppColors.primaryBorder),
              const SizedBox(width: 14),

              Text(
                session?.email ?? 'teacher@schoolic.local',
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
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
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
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

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: AppRadii.rMd,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.curve,
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
              size: 15,
              color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
          recentSessions: _recentSessions,
          teacherEmail: session?.email ?? 'Faculty',
          onSelectAssignmentAndTakeAttendance: _selectAssignmentAndTakeAttendance,
          onNavigateToRegister: () => setState(() => _activeTab = 2),
        );
      case 1:
        return TeacherClassesView(
          assignments: _assignments,
          onTakeAttendance: _selectAssignmentAndTakeAttendance,
        );
      case 2:
        return TeacherAttendanceView(
          assignments: _assignments,
          selectedAssignment: _selectedAssignment,
          onAssignmentChanged: (val) => setState(() => _selectedAssignment = val),
          onAttendanceSaved: _loadData,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

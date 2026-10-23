import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/fluid_ui.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/brand_deck_dialog.dart';
import '../shared/components/command_palette.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/schoolic_logo.dart';
import '../shared/components/shortcuts_dialog.dart';
import '../shared/components/tour_dialog.dart';
import '../shared/views/announcements_view.dart';
import 'components/ai_draft_remarks_dialog.dart';
import 'components/ai_homework_feedback_dialog.dart';
import 'views/teacher_attendance_view.dart';
import 'views/teacher_classes_view.dart';
import 'views/teacher_copilot_view.dart';
import 'views/teacher_homework_view.dart';
import 'views/teacher_marks_view.dart';
import 'views/teacher_my_day_view.dart';
import 'views/teacher_timetable_view.dart';
import 'views/teacher_messages_view.dart';
import 'views/teacher_operations_view.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard>
    with WidgetsBindingObserver {
  int _activeTab = 0;
  List<Map<String, Object?>> _assignments = [];
  List<Map<String, Object?>> _timetable = [];
  List<Map<String, Object?>> _recentSessions = [];
  Map<String, Object?>? _selectedAssignment;
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  Timer? _realtimeSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();

    // Background real-time live sync every 20s (bypassed in test harness)
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTest) {
      _realtimeSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) _loadData(silent: true);
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
      _loadData(silent: true);
    }
  }

  @override
  void dispose() {
    _realtimeSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
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
        api.getList('/api/v1/teacher/assignments', session: session),
        api
            .getList('/api/v1/teacher/timetable', session: session)
            .catchError((_) => <Map<String, Object?>>[]),
        api
            .getJson('/api/v1/teacher/attendance/summary', session: session)
            .catchError((_) => {'sessions': []}),
      ]);

      final assignments = results[0] as List<Map<String, Object?>>;
      final timetable = results[1] as List<Map<String, Object?>>;
      final summaryJson = results[2] as Map<String, Object?>;
      final sessions = ((summaryJson['sessions'] as List?) ?? const [])
          .cast<Map<String, Object?>>();

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _timetable = timetable;
          _recentSessions = sessions;
          _hasLoaded = true;
          _error = null;
          if (_selectedAssignment == null && assignments.isNotEmpty) {
            _selectedAssignment = assignments.first;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (!silent && !_hasLoaded) {
          setState(() => _error = e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        if (!silent && !_hasLoaded) {
          setState(() => _error = e.toString());
        }
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
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
    final baseAssignment = matchingAssignments.isEmpty
        ? null
        : matchingAssignments.first;

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
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    if (!auth.isLoading && session != null && !_hasLoaded && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasLoaded) _loadData();
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1000;

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
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
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
                    const SchoolicLogo(size: 20),
                    if (!isMobile) ...[
                      const SizedBox(width: 24),
                      // Navigation tab buttons
                      _buildTabButton(0, 'My Day', Icons.dashboard_outlined),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        1,
                        'My Week',
                        Icons.calendar_month_outlined,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(2, 'My Classes', Icons.layers_outlined),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        3,
                        'Attendance Register',
                        Icons.fact_check_outlined,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        4,
                        'Copilot',
                        Icons.auto_awesome_outlined,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(5, 'Homework', Icons.assignment_outlined),
                      const SizedBox(width: 4),
                      _buildTabButton(6, 'Marks', Icons.fact_check_outlined),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        7,
                        'Announcements',
                        Icons.campaign_outlined,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(8, 'Messages', Icons.chat_bubble_outline),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        9,
                        'Operations',
                        Icons.event_note_outlined,
                      ),
                    ],

                    const Spacer(),

                    InkWell(
                      borderRadius: AppRadii.rMd,
                      onTap: () => CommandPaletteDialog.show(
                        context,
                        onActionSelected: _handleCommandPaletteAction,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: AppRadii.rMd,
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search,
                              size: 14,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMobile ? 'Search' : 'Quick Actions...',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.mainBackground,
                                  borderRadius: AppRadii.rSm,
                                  border: Border.all(
                                    color: AppColors.primaryBorder,
                                  ),
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
                    const SizedBox(width: 6),

                    // Tutorial button
                    IconButton(
                      tooltip: 'App Tutorial',
                      iconSize: 18,
                      onPressed: () => TourDialog.show(context),
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.secondaryText,
                      ),
                    ),

                    // Refresh button
                    IconButton(
                      tooltip: 'Refresh data',
                      iconSize: 18,
                      onPressed: () => _loadData(),
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.secondaryText,
                      ),
                    ),

                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 16,
                        color: AppColors.primaryBorder,
                      ),
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

                    const FluidMascotInsignia(size: 26),
                    const SizedBox(width: 6),

                    IconButton(
                      tooltip: 'Sign out',
                      iconSize: 16,
                      onPressed: () =>
                          ref.read(authControllerProvider).signOut(),
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 14 : 32,
            isMobile ? 16 : 28,
            isMobile ? 14 : 32,
            isMobile ? 32 : 28,
          ),
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
                border: Border(
                  bottom: BorderSide(color: AppColors.primaryBorder),
                ),
              ),
              child: const Row(children: [SchoolicLogo(size: 20)]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerTabItem(0, 'My Day', Icons.dashboard_outlined),
                  _drawerTabItem(1, 'My Week', Icons.calendar_month_outlined),
                  _drawerTabItem(2, 'My Classes', Icons.layers_outlined),
                  _drawerTabItem(
                    3,
                    'Attendance Register',
                    Icons.fact_check_outlined,
                  ),
                  _drawerTabItem(
                    4,
                    'Teacher Copilot',
                    Icons.auto_awesome_outlined,
                  ),
                  _drawerTabItem(5, 'Homework', Icons.assignment_outlined),
                  _drawerTabItem(6, 'Marks', Icons.fact_check_outlined),
                  _drawerTabItem(7, 'Announcements', Icons.campaign_outlined),
                  _drawerTabItem(
                    8,
                    'Messages & Hours',
                    Icons.chat_bubble_outline,
                  ),
                  _drawerTabItem(
                    9,
                    'Teacher operations',
                    Icons.event_note_outlined,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1, color: AppColors.primaryBorder),
                  ),
                  _drawerActionItem(
                    label: 'Brand Deck',
                    icon: Icons.palette_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      BrandDeckDialog.show(context);
                    },
                  ),
                  _drawerActionItem(
                    label: 'Tutorial',
                    icon: Icons.explore_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      TourDialog.show(context);
                    },
                  ),
                  _drawerActionItem(
                    label: 'Keyboard Shortcuts',
                    icon: Icons.keyboard_outlined,
                    onTap: () {
                      Navigator.of(context).pop();
                      ShortcutsDialog.show(context);
                    },
                  ),
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
                          session?.email ?? 'teacher@schoolic.app',
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
                    icon: const Icon(
                      Icons.logout,
                      color: AppColors.secondaryText,
                    ),
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
        setState(() {
          _activeTab = index;
          _error = null;
        });
        Navigator.of(context).pop();
      },
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryBackground
              : Colors.transparent,
          borderRadius: AppRadii.rMd,
          border: isSelected
              ? const Border(
                  left: BorderSide(color: AppColors.primaryText, width: 2),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.primaryText
                  : AppColors.secondaryText,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerActionItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rMd,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.secondaryText),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;

    return FluidPressable(
      scaleDown: 0.98,
      onTap: () => setState(() {
        _activeTab = index;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.fluidOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryBackground
              : Colors.transparent,
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: isSelected ? AppColors.primaryBorder : Colors.transparent,
          ),
          boxShadow: isSelected ? AppShadows.ambientSoft : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primaryText
                  : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
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
          onSelectAssignmentAndTakeAttendance:
              _selectAssignmentAndTakeAttendance,
          onSelectTimetableEntryAndTakeAttendance:
              _selectTimetableEntryAndTakeAttendance,
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
        final attendanceAssignments =
            _selectedAssignment == null ||
                _assignments.contains(_selectedAssignment)
            ? _assignments
            : [_selectedAssignment!, ..._assignments];
        return TeacherAttendanceView(
          assignments: attendanceAssignments,
          selectedAssignment: _selectedAssignment,
          onAssignmentChanged: (val) =>
              setState(() => _selectedAssignment = val),
          onAttendanceSaved: _loadData,
        );
      case 4:
        return TeacherCopilotView(assignments: _assignments);
      case 5:
        return TeacherHomeworkView(assignments: _assignments);
      case 6:
        return const TeacherMarksView();
      case 7:
        return AnnouncementsView(
          workspace: AnnouncementWorkspace.teacher,
          endpoint: '/api/v1/teacher/announcements',
          assignments: _assignments,
        );
      case 8:
        return const TeacherMessagesView();
      case 9:
        return TeacherOperationsView(assignments: _assignments);
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleCommandPaletteAction(String action) {
    if (action.startsWith('nav:')) {
      final dest = action.replaceFirst('nav:', '');
      switch (dest) {
        case 'overview':
          setState(() => _activeTab = 0);
          break;
        case 'attendance':
          setState(() => _activeTab = 1);
          break;
        case 'timetable':
          setState(() => _activeTab = 2);
          break;
        case 'homework':
          setState(() => _activeTab = 5);
          break;
        case 'exams':
          setState(() => _activeTab = 6);
          break;
      }
    } else if (action == 'action:draft_remarks') {
      AiDraftRemarksDialog.show(context);
    } else if (action == 'action:homework_feedback') {
      AiHomeworkFeedbackDialog.show(context);
    } else if (action == 'action:shortcuts') {
      ShortcutsDialog.show(context);
    }
  }
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

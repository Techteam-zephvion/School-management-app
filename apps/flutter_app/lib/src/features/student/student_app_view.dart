import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/empty_state_view.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/status_badge.dart';
import 'components/digital_id_card.dart';
import 'components/homework_submission_sheet.dart';

class StudentAppView extends ConsumerStatefulWidget {
  const StudentAppView({super.key});

  @override
  ConsumerState<StudentAppView> createState() => _StudentAppViewState();
}

class _StudentAppViewState extends ConsumerState<StudentAppView> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  String? _selectedStudentId;

  Map<String, Object?>? _profile;
  Map<String, Object?>? _attendance;
  Map<String, Object?>? _timetable;
  Map<String, Object?>? _homework;
  Map<String, Object?>? _reportCard;
  Map<String, Object?>? _fees;
  Map<String, Object?>? _idCard;
  List<Map<String, Object?>> _announcements = const [];

  int _timetableSelectedDay = DateTime.now().weekday; // 1 = Mon .. 7 = Sun
  String _homeworkFilter = 'all'; // all, pending, submitted

  List<Map<String, Object?>> get _students {
    final rows = _profile?['students'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Map<String, Object?>? get _activeStudent {
    if (_students.isEmpty) return null;
    if (_selectedStudentId == null) return _students.first;
    return _students.firstWhere(
      (s) => s['id'] == _selectedStudentId,
      orElse: () => _students.first,
    );
  }

  List<Map<String, Object?>> get _homeworkList {
    final rows = _homework?['assignments'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  int get _pendingHomeworkCount {
    return _homeworkList.where((h) => h['submission'] == null).length;
  }

  @override
  void initState() {
    super.initState();
    if (_timetableSelectedDay > 6) _timetableSelectedDay = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({String? studentId}) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to continue.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final profile = await api.getJson(
        '/api/v1/portal/profile',
        session: session,
      );

      final students = ((profile['students'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, Object?>())
          .toList();

      final selectedId = studentId ??
          _selectedStudentId ??
          (students.isEmpty ? null : students.first['id'] as String?);

      final query = selectedId == null ? '' : '?studentId=$selectedId';

      final responses = await Future.wait([
        api.getJson('/api/v1/portal/attendance$query', session: session),
        api.getJson('/api/v1/portal/timetable$query', session: session),
        api.getJson('/api/v1/portal/homework$query', session: session),
        api.getJson('/api/v1/portal/report-card$query', session: session),
        api.getJson('/api/v1/portal/fees$query', session: session),
        api.getJson('/api/v1/portal/id-card$query', session: session),
        api.getList('/api/v1/portal/announcements$query', session: session),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _selectedStudentId = selectedId;
        _attendance = responses[0] as Map<String, Object?>;
        _timetable = responses[1] as Map<String, Object?>;
        _homework = responses[2] as Map<String, Object?>;
        _reportCard = responses[3] as Map<String, Object?>;
        _fees = responses[4] as Map<String, Object?>;
        _idCard = responses[5] as Map<String, Object?>;
        _announcements = responses[6] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Unable to load student data.';
      });
    }
  }

  Future<void> _signOut() => ref.read(authControllerProvider).signOut();

  void _showStudentSelectorSheet() {
    if (_students.length <= 1) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Switch Student Profile',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._students.map((student) {
                final isSelected = student['id'] == _selectedStudentId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? AppColors.primaryText
                        : AppColors.secondaryBackground,
                    foregroundColor:
                        isSelected ? Colors.white : AppColors.primaryText,
                    child: Text(
                      ((student['fullName'] as String?) ?? 'S')[0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    (student['fullName'] as String?) ?? 'Student',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Class: ${student["className"] ?? "-"} • Section: ${student["sectionName"] ?? "-"}',
                    style: AppTypography.metadata,
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primaryText, size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _load(studentId: student['id'] as String?);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 720;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: _buildTopAppBar(isDesktop),
      body: _buildBody(isDesktop),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildTopAppBar(bool isDesktop) {
    final student = _activeStudent;
    final fullName = (student?['fullName'] as String?) ?? 'Student Portal';
    final className = (student?['className'] as String?) ?? '';
    final sectionName = (student?['sectionName'] as String?) ?? '';
    final initials = fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.mainBackground,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryText,
            child: Text(
              initials.isEmpty ? 'ST' : initials,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  className.isNotEmpty
                      ? '$className • Sec $sectionName'
                      : 'Student App',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_students.length > 1)
          IconButton(
            tooltip: 'Switch Child / Student Profile',
            icon: const Icon(Icons.people_outline, size: 20),
            onPressed: _showStudentSelectorSheet,
          ),
        IconButton(
          tooltip: 'Refresh App Data',
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
          onPressed: _loading ? null : () => _load(),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout, size: 19),
          onPressed: _signOut,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.primaryBorder,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: FeedbackBanner(
              message: _error!,
              tone: FeedbackTone.error,
              actionLabel: 'Retry',
              onAction: () => _load(),
            ),
          ),
        ),
      );
    }

    if (_loading && _profile == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_students.isEmpty) {
      return const EmptyStateView(
        title: 'No Student Profile Linked',
        description:
            'Please ask the school administrator to link your account to a student record.',
      );
    }

    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: _tabIndex,
            onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.secondaryBackground,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny),
                label: Text('Today'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: Text('Timetable'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: _pendingHomeworkCount > 0,
                  label: Text('$_pendingHomeworkCount'),
                  child: const Icon(Icons.assignment_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _pendingHomeworkCount > 0,
                  label: Text('$_pendingHomeworkCount'),
                  child: const Icon(Icons.assignment),
                ),
                label: const Text('Homework'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Academics'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: Text('ID & Fees'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.primaryBorder),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: _buildCurrentTab(),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: _buildCurrentTab(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(top: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        backgroundColor: AppColors.mainBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.secondaryBackground,
        destinations: [
          const NavigationRequestDestination(
            icon: Icon(Icons.wb_sunny_outlined, size: 22),
            selectedIcon: Icon(Icons.wb_sunny, size: 22),
            label: 'Today',
          ),
          const NavigationRequestDestination(
            icon: Icon(Icons.calendar_today_outlined, size: 22),
            selectedIcon: Icon(Icons.calendar_today, size: 22),
            label: 'Schedule',
          ),
          NavigationRequestDestination(
            icon: Badge(
              isLabelVisible: _pendingHomeworkCount > 0,
              label: Text('$_pendingHomeworkCount'),
              child: const Icon(Icons.assignment_outlined, size: 22),
            ),
            selectedIcon: Badge(
              isLabelVisible: _pendingHomeworkCount > 0,
              label: Text('$_pendingHomeworkCount'),
              child: const Icon(Icons.assignment, size: 22),
            ),
            label: 'Homework',
          ),
          const NavigationRequestDestination(
            icon: Icon(Icons.bar_chart_outlined, size: 22),
            selectedIcon: Icon(Icons.bar_chart, size: 22),
            label: 'Grades',
          ),
          const NavigationRequestDestination(
            icon: Icon(Icons.badge_outlined, size: 22),
            selectedIcon: Icon(Icons.badge, size: 22),
            label: 'ID & Fees',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_tabIndex) {
      case 0:
        return _buildTodayTab();
      case 1:
        return _buildTimetableTab();
      case 2:
        return _buildHomeworkTab();
      case 3:
        return _buildAcademicsTab();
      case 4:
        return _buildIdFeesTab();
      default:
        return _buildTodayTab();
    }
  }

  // -------------------------------------------------------------
  // TAB 0: TODAY / HOME
  // -------------------------------------------------------------
  Widget _buildTodayTab() {
    final student = _activeStudent;
    final fullName = (student?['fullName'] as String?) ?? 'Student';
    final firstName = fullName.split(' ').first;

    final attSummary = _attendance?['summary'] as Map<String, Object?>?;
    final presentCount = attSummary?['present'] as int? ?? 0;
    final totalSessions = attSummary?['total'] as int? ?? 0;
    final percentage = attSummary?['percentage'];

    // Today's classes
    final timetableRows = ((_timetable?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => r.cast<String, Object?>())
        .where((r) => r['dayOfWeek'] == DateTime.now().weekday)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        // Greeting & Daily Motivational Banner
        Text(
          'Good morning, $firstName 👋',
          style: const TextStyle(
            fontFamily: 'Switzer',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is your daily academic schedule and homework briefing.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 18),

        // Attendance Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.mainBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TODAY'S ATTENDANCE STATUS",
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Present in Class',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    Text(
                      percentage != null
                          ? '$percentage% Cumulative ($presentCount of $totalSessions recorded)'
                          : 'Recorded by class teacher',
                      style: AppTypography.metadata,
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: 'PRESENT', tone: BadgeTone.success),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Quick Shortcuts 4-Grid
        Row(
          children: [
            Expanded(
              child: _buildQuickTile(
                title: 'Pending Tasks',
                value: '$_pendingHomeworkCount due',
                icon: Icons.assignment_outlined,
                onTap: () => setState(() => _tabIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickTile(
                title: 'Timetable',
                value: '${timetableRows.length} classes today',
                icon: Icons.calendar_today_outlined,
                onTap: () => setState(() => _tabIndex = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickTile(
                title: 'Student ID',
                value: 'Tap to view card',
                icon: Icons.badge_outlined,
                onTap: () => setState(() => _tabIndex = 4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickTile(
                title: 'Report Card',
                value: _reportCard?['summary'] != null
                    ? '${(_reportCard!["summary"] as Map)["percentage"] ?? "-"}% score'
                    : 'View Marks',
                icon: Icons.bar_chart_outlined,
                onTap: () => setState(() => _tabIndex = 3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Today's Classes Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Classes",
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _tabIndex = 1),
              child: const Text('Full Week'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (timetableRows.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Center(
              child: Text(
                'No scheduled classes for today.',
                style: AppTypography.bodySecondary,
              ),
            ),
          )
        else
          ...timetableRows.map(_buildTimetableItemCard),

        const SizedBox(height: 24),

        // School Announcements Feed
        const Text(
          'Announcements & Circulars',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        if (_announcements.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Center(
              child: Text(
                'No current announcements.',
                style: AppTypography.bodySecondary,
              ),
            ),
          )
        else
          ..._announcements.take(3).map(_buildAnnouncementCard),
      ],
    );
  }

  Widget _buildQuickTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rMd,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.mainBackground,
          borderRadius: AppRadii.rMd,
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryText),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: TIMETABLE
  // -------------------------------------------------------------
  Widget _buildTimetableTab() {
    final allEntries = ((_timetable?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => r.cast<String, Object?>())
        .toList();

    final filtered = allEntries
        .where((r) => r['dayOfWeek'] == _timetableSelectedDay)
        .toList();

    const days = [
      {'day': 1, 'label': 'Mon'},
      {'day': 2, 'label': 'Tue'},
      {'day': 3, 'label': 'Wed'},
      {'day': 4, 'label': 'Thu'},
      {'day': 5, 'label': 'Fri'},
      {'day': 6, 'label': 'Sat'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const Text(
          'Weekly Class Schedule',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Daily periods, subject allocations, and faculty in-charge.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 16),

        // Day of Week Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((d) {
              final isSelected = d['day'] == _timetableSelectedDay;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(d['label'] as String),
                  selected: isSelected,
                  selectedColor: AppColors.primaryText,
                  labelStyle: TextStyle(
                    fontFamily: 'Switzer',
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.primaryText,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _timetableSelectedDay = d['day'] as int);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Center(
              child: Text(
                'No classes scheduled for this day.',
                style: AppTypography.bodySecondary,
              ),
            ),
          )
        else
          ...filtered.map(_buildTimetableItemCard),
      ],
    );
  }

  Widget _buildTimetableItemCard(Map<String, Object?> entry) {
    final startTime = (entry['startTime'] as String?) ?? '--:--';
    final endTime = (entry['endTime'] as String?) ?? '--:--';
    final subject = (entry['subjectName'] as String?) ?? 'Subject';
    final teacher = (entry['staffName'] as String?) ?? 'Faculty';
    final room = (entry['roomNumber'] as String?) ?? 'Main Classroom';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rSm,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Column(
              children: [
                Text(
                  startTime,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const Text(
                  'to',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 9,
                    color: AppColors.mutedText,
                  ),
                ),
                Text(
                  endTime,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Subject & Teacher info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppColors.secondaryText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        teacher,
                        style: AppTypography.bodySecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Room tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rSm,
            ),
            child: Text(
              room,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                color: AppColors.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: HOMEWORK & SUBMISSIONS
  // -------------------------------------------------------------
  Widget _buildHomeworkTab() {
    final allList = _homeworkList;
    final filtered = allList.where((h) {
      if (_homeworkFilter == 'pending') return h['submission'] == null;
      if (_homeworkFilter == 'submitted') return h['submission'] != null;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const Text(
          'Homework & Assignments',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Submit work, track due dates, and review faculty evaluations.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 16),

        // Filter chips
        Row(
          children: [
            ChoiceChip(
              label: Text('All (${allList.length})'),
              selected: _homeworkFilter == 'all',
              selectedColor: AppColors.primaryText,
              labelStyle: TextStyle(
                fontFamily: 'Switzer',
                fontWeight: FontWeight.w600,
                color: _homeworkFilter == 'all'
                    ? Colors.white
                    : AppColors.primaryText,
              ),
              onSelected: (_) => setState(() => _homeworkFilter = 'all'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('Pending ($_pendingHomeworkCount)'),
              selected: _homeworkFilter == 'pending',
              selectedColor: AppColors.primaryText,
              labelStyle: TextStyle(
                fontFamily: 'Switzer',
                fontWeight: FontWeight.w600,
                color: _homeworkFilter == 'pending'
                    ? Colors.white
                    : AppColors.primaryText,
              ),
              onSelected: (_) => setState(() => _homeworkFilter = 'pending'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(
                  'Submitted (${allList.length - _pendingHomeworkCount})'),
              selected: _homeworkFilter == 'submitted',
              selectedColor: AppColors.primaryText,
              labelStyle: TextStyle(
                fontFamily: 'Switzer',
                fontWeight: FontWeight.w600,
                color: _homeworkFilter == 'submitted'
                    ? Colors.white
                    : AppColors.primaryText,
              ),
              onSelected: (_) => setState(() => _homeworkFilter = 'submitted'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Center(
              child: Text(
                _homeworkFilter == 'pending'
                    ? 'Great job! No pending homework assignments.'
                    : 'No assignments found in this view.',
                style: AppTypography.bodySecondary,
              ),
            ),
          )
        else
          ...filtered.map(_buildHomeworkCard),
      ],
    );
  }

  Widget _buildHomeworkCard(Map<String, Object?> hw) {
    final assignmentId = hw['id'] as String;
    final title = (hw['title'] as String?) ?? 'Homework';
    final subject = (hw['subjectName'] as String?) ?? 'Subject';
    final instructions = (hw['instructions'] as String?) ?? '';
    final dueDate = (hw['dueDate'] as String?) ?? '';
    final estimatedMin = hw['estimatedMinutes'] as int?;
    final teacher = (hw['teacherName'] as String?) ?? 'Teacher';

    final sub = hw['submission'] as Map<String, Object?>?;
    final isSubmitted = sub != null;
    final subStatus = (sub?['status'] as String?) ?? 'pending';
    final marks = sub?['marksObtained'];
    final feedback = sub?['teacherFeedback'] as String?;
    final content = sub?['content'] as String?;
    final attachmentUrl = sub?['attachmentUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Subject pill + Status badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: AppRadii.rSm,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    subject.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                if (estimatedMin != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '⏱ $estimatedMin mins',
                    style: AppTypography.metadata,
                  ),
                ],
                const Spacer(),
                if (isSubmitted)
                  StatusBadge(
                    label: subStatus.toUpperCase(),
                    tone: subStatus == 'reviewed'
                        ? BadgeTone.success
                        : BadgeTone.info,
                  )
                else
                  const StatusBadge(
                    label: 'PENDING',
                    tone: BadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 6),

            // Instructions
            Text(
              instructions,
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 12),

            // Due Date & Teacher info
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 14, color: AppColors.mutedText),
                const SizedBox(width: 4),
                Text(
                  'Due: $dueDate',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.mutedText),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    teacher,
                    style: AppTypography.metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // If submitted, show submission summary and evaluation
            if (isSubmitted) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 15, color: Colors.green),
                        const SizedBox(width: 6),
                        const Text(
                          'Your Submission',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (marks != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryText,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Score: $marks / 100',
                              style: const TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (content != null && content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        content,
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                    if (attachmentUrl != null &&
                        attachmentUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Link: $attachmentUrl',
                        style: const TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    if (feedback != null && feedback.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.mainBackground,
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.feedback_outlined,
                                size: 14, color: AppColors.primaryText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Teacher: "$feedback"',
                                style: const TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Interactive Action Button
            SizedBox(
              width: double.infinity,
              child: isSubmitted
                  ? OutlinedButton.icon(
                      onPressed: () => HomeworkSubmissionSheet.show(
                        context,
                        assignmentId: assignmentId,
                        assignmentTitle: title,
                        subjectName: subject,
                        dueDate: dueDate,
                        instructions: instructions,
                        studentId: _selectedStudentId,
                        initialContent: content,
                        initialAttachmentUrl: attachmentUrl,
                        onSubmitted: () => _load(),
                      ),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Update / Resubmit Homework'),
                    )
                  : FilledButton.icon(
                      onPressed: () => HomeworkSubmissionSheet.show(
                        context,
                        assignmentId: assignmentId,
                        assignmentTitle: title,
                        subjectName: subject,
                        dueDate: dueDate,
                        instructions: instructions,
                        studentId: _selectedStudentId,
                        onSubmitted: () => _load(),
                      ),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Submit Solution'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: ACADEMICS & REPORT CARD
  // -------------------------------------------------------------
  Widget _buildAcademicsTab() {
    final summary = _reportCard?['summary'] as Map<String, Object?>?;
    final totalObtained = summary?['totalObtained'] as int? ?? 0;
    final totalMax = summary?['totalMax'] as int? ?? 0;
    final percentage = summary?['percentage'];
    final examCount = summary?['exams'] as int? ?? 0;

    final results = ((_reportCard?['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => r.cast<String, Object?>())
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const Text(
          'Academic Performance',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Exam marks, grade report card, and faculty assessments.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 18),

        // Overall GPA / Percentage Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryText,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERALL SCORE',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      percentage != null ? '$percentage%' : 'N/A',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalObtained / $totalMax marks across $examCount published exams',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 3),
                ),
                child: Center(
                  child: Text(
                    percentage != null && (percentage as num) >= 90
                        ? 'A+'
                        : 'A',
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Published Exam Results',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        if (results.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Center(
              child: Text(
                'No exam marks published for this term yet.',
                style: AppTypography.bodySecondary,
              ),
            ),
          )
        else
          ...results.map(_buildExamResultCard),
      ],
    );
  }

  Widget _buildExamResultCard(Map<String, Object?> item) {
    final examName = (item['name'] as String?) ?? 'Examination';
    final subject = (item['subjectName'] as String?) ?? 'Subject';
    final examDate = (item['examDate'] as String?) ?? '';
    final marksObtained = item['marksObtained'] as int? ?? 0;
    final maxMarks = item['maxMarks'] as int? ?? 100;
    final percent = maxMarks > 0
        ? (marksObtained / maxMarks * 100).toStringAsFixed(1)
        : '0';
    final remarks = item['remarks'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadii.rSm,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  subject.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$marksObtained / $maxMarks ($percent%)',
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            examName,
            style: const TextStyle(
              fontFamily: 'Switzer',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Exam Date: $examDate',
            style: AppTypography.metadata,
          ),
          if (remarks != null && remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined,
                      size: 13, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      remarks,
                      style: AppTypography.metadata,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: DIGITAL ID & FEES
  // -------------------------------------------------------------
  Widget _buildIdFeesTab() {
    final school = _idCard?['school'] as Map<String, Object?>?;
    final student = _idCard?['student'] as Map<String, Object?>?;
    final qrPayload = _idCard?['qrPayload'] as String?;

    final schoolName = (school?['name'] as String?) ?? 'Schoolic Academy';
    final schoolCode = (school?['code'] as String?) ?? 'SCH';
    final fullName = (student?['fullName'] as String?) ?? 'Student';
    final admissionNumber =
        (student?['admissionNumber'] as String?) ?? 'SCH-000';
    final rollNumber = (student?['rollNumber'] as String?) ?? '01';
    final className = (student?['className'] as String?) ?? 'Class';
    final sectionName = (student?['sectionName'] as String?) ?? 'A';
    final academicYear = (student?['academicYearName'] as String?) ?? '2026-2027';
    final guardianName = student?['guardianName'] as String?;
    final guardianPhone = student?['guardianPhone'] as String?;

    final feeSummary = _fees?['summary'] as Map<String, Object?>?;
    final totalBilled = feeSummary?['totalBilled'] as int? ?? 0;
    final totalPaid = feeSummary?['totalPaid'] as int? ?? 0;
    final balanceDue = feeSummary?['balanceDue'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const Text(
          'Digital Student ID Card',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Institutional verification, entry pass, and attendance QR.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 16),

        // High-Contrast Sleek Digital ID Card
        DigitalIdCard(
          schoolName: schoolName,
          schoolCode: schoolCode,
          fullName: fullName,
          admissionNumber: admissionNumber,
          rollNumber: rollNumber,
          className: className,
          sectionName: sectionName,
          academicYear: academicYear,
          guardianName: guardianName,
          guardianPhone: guardianPhone,
          qrPayload: qrPayload,
        ),
        const SizedBox(height: 28),

        // Fees Section
        const Text(
          'Fee Statement & Payments',
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tuition dues, paid receipts, and payment transactions.',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 14),

        // Fee Summary Container
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance Due',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                  Text(
                    '₹$balanceDue',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: balanceDue > 0 ? Colors.redAccent : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.primaryBorder),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Billed: ₹$totalBilled',
                    style: AppTypography.metadata,
                  ),
                  Text(
                    'Total Paid: ₹$totalPaid',
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Receipt Card Example
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 22, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Term 1 Composite Tuition Receipt',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Receipt: REC-2026-0089 • UPI Payment',
                      style: AppTypography.metadata,
                    ),
                  ],
                ),
              ),
              const Text(
                '₹15,000',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, Object?> item) {
    final title = (item['title'] as String?) ?? 'Notice';
    final body = (item['body'] as String?) ?? '';
    final priority = (item['priority'] as String?) ?? 'normal';
    final isUrgent = priority == 'urgent' || priority == 'important';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: isUrgent ? Colors.redAccent.withValues(alpha: 0.4) : AppColors.primaryBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isUrgent)
                const StatusBadge(
                  label: 'IMPORTANT',
                  tone: BadgeTone.error,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class NavigationRequestDestination extends NavigationDestination {
  const NavigationRequestDestination({
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.key,
  });
}

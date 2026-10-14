import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/empty_state_view.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/page_header.dart';
import '../shared/components/status_badge.dart';
import '../shared/components/stat_strip.dart';

class PortalDashboard extends ConsumerStatefulWidget {
  const PortalDashboard({super.key});

  @override
  ConsumerState<PortalDashboard> createState() => _PortalDashboardState();
}

class _PortalDashboardState extends ConsumerState<PortalDashboard> {
  bool _loading = true;
  String? _error;
  String? _selectedStudentId;
  Map<String, Object?>? _profile;
  Map<String, Object?>? _attendance;
  Map<String, Object?>? _timetable;
  Map<String, Object?>? _homework;
  Map<String, Object?>? _reportCard;
  Map<String, Object?>? _fees;
  List<Map<String, Object?>> _announcements = const [];

  List<Map<String, Object?>> get _students {
    final rows = _profile?['students'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  @override
  void initState() {
    super.initState();
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
      final selectedId =
          studentId ??
          _selectedStudentId ??
          (students.isEmpty ? null : students.first['id'] as String?);
      final query = selectedId == null ? '' : '?studentId=$selectedId';

      final attendance = await api.getJson(
        '/api/v1/portal/attendance$query',
        session: session,
      );
      final timetable = await api.getJson(
        '/api/v1/portal/timetable$query',
        session: session,
      );
      final homework = await api.getJson(
        '/api/v1/portal/homework$query',
        session: session,
      );
      final reportCard = await api.getJson(
        '/api/v1/portal/report-card$query',
        session: session,
      );
      final fees = await api.getJson(
        '/api/v1/portal/fees$query',
        session: session,
      );
      final announcements = await api.getList(
        '/api/v1/portal/announcements$query',
        session: session,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _selectedStudentId = selectedId;
        _attendance = attendance;
        _timetable = timetable;
        _homework = homework;
        _reportCard = reportCard;
        _fees = fees;
        _announcements = announcements;
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception is ApiException
            ? exception.message
            : 'Unable to load portal data.';
      });
    }
  }

  Future<void> _signOut() => ref.read(authControllerProvider).signOut();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 720;

    return SafeArea(
      child: Column(
        children: [
          _PortalTopBar(
            onRefresh: _loading
                ? null
                : () {
                    _load();
                  },
            onSignOut: () {
              _signOut();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 28,
                  24,
                  isCompact ? 16 : 28,
                  32,
                ),
                children: [
                  PageHeader(
                    title: 'Student Portal',
                    description: 'Attendance, timetable, and school updates in one place.',
                    primaryAction: _students.length > 1
                        ? _studentSelector()
                        : null,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    FeedbackBanner(
                      message: _error!,
                      tone: FeedbackTone.error,
                      actionLabel: 'Retry',
                      onAction: () {
                        _load();
                      },
                    )
                  else if (_loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (_students.isEmpty)
                    const EmptyStateView(
                      title: 'No linked student profile',
                      description: 'Ask the school administrator to link this account to a student record.',
                    )
                  else ...[
                    _studentSummary(),
                    const SizedBox(height: 18),
                    _attendanceSummary(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stack = constraints.maxWidth < 900;
                        final timetable = _timetablePanel();
                        final announcements = _announcementsPanel();
                        final fees = _feesPanel();
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              timetable,
                              const SizedBox(height: 18),
                              _homeworkPanel(),
                              const SizedBox(height: 18),
                              _reportCardPanel(),
                              const SizedBox(height: 18),
                              fees,
                              const SizedBox(height: 18),
                              announcements,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  timetable,
                                  const SizedBox(height: 18),
                                  fees,
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _homeworkPanel(),
                                  const SizedBox(height: 18),
                                  _reportCardPanel(),
                                  const SizedBox(height: 18),
                                  announcements,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStudentId,
      decoration: const InputDecoration(labelText: 'Student'),
      items: _students
          .map(
            (student) => DropdownMenuItem<String>(
              value: student['id'] as String?,
              child: Text(student['fullName'] as String? ?? 'Student'),
            ),
          )
          .toList(),
      onChanged: _loading ? null : (value) => _load(studentId: value),
    );
  }

  Widget _studentSummary() {
    final student = _selectedStudent;
    final profileYear = (_profile?['activeAcademicYear'] as Map?)
        ?.cast<String, Object?>();
    final yearName =
        student?['academicYearName'] as String? ??
        profileYear?['name'] as String? ??
        'Active year';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student?['fullName'] as String? ?? 'Student',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            '${student?['className'] ?? 'Class'} ${student?['sectionName'] ?? ''} • $yearName',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          if ((student?['rollNumber'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            StatusBadge(
              label: 'Roll ${student!['rollNumber']}',
              tone: BadgeTone.neutral,
            ),
          ],
        ],
      ),
    );
  }

  Widget _attendanceSummary() {
    final stats = (_attendance?['stats'] as Map?)?.cast<String, Object?>();
    final rate = stats?['attendanceRate'];
    return StatStrip(
      items: [
        StatItemData(
          label: 'Attendance Rate',
          value: rate == null ? '-' : '$rate%',
          helper: 'Present and late counted',
        ),
        StatItemData(
          label: 'Present',
          value: '${stats?['present'] ?? 0}',
          helper: 'Recorded sessions',
        ),
        StatItemData(
          label: 'Absent',
          value: '${stats?['absent'] ?? 0}',
          helper: 'Requires attention',
        ),
        StatItemData(
          label: 'Late',
          value: '${stats?['late'] ?? 0}',
          helper: 'Arrived after roll call',
        ),
      ],
    );
  }

  Widget _timetablePanel() {
    final entries = ((_timetable?['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
    return _Panel(
      title: 'Weekly Timetable',
      child: entries.isEmpty
          ? const EmptyStateView(
              title: 'No timetable published',
              description: 'Scheduled lessons will appear here.',
            )
          : Column(
              children: entries.map((entry) {
                return _ListRow(
                  title:
                      '${_dayName(entry['dayOfWeek'])} • ${entry['startTime']} - ${entry['endTime']}',
                  subtitle:
                      '${entry['subjectName'] ?? 'Subject'} with ${entry['staffName'] ?? 'Teacher'}',
                );
              }).toList(),
            ),
    );
  }

  Widget _announcementsPanel() {
    return _Panel(
      title: 'Announcements',
      child: _announcements.isEmpty
          ? const EmptyStateView(
              title: 'No announcements',
              description: 'School notices for your class will appear here.',
            )
          : Column(
              children: _announcements.map((announcement) {
                final audience = announcement['audience'] == 'school'
                    ? 'School-wide'
                    : '${announcement['className'] ?? 'Class'} ${announcement['sectionName'] ?? ''}';
                return _ListRow(
                  title: announcement['title'] as String? ?? 'Announcement',
                  subtitle: '${announcement['body'] ?? ''}\n$audience',
                );
              }).toList(),
            ),
    );
  }

  Widget _homeworkPanel() {
    final assignments = ((_homework?['assignments'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
    return _Panel(
      title: 'Homework',
      child: assignments.isEmpty
          ? const EmptyStateView(
              title: 'No homework assigned',
              description: 'Published class assignments will appear here.',
            )
          : Column(
              children: assignments.map((assignment) {
                final subject = assignment['subjectName'] == null
                    ? ''
                    : ' • ${assignment['subjectName']}';
                return _ListRow(
                  title: '${assignment['title'] ?? 'Homework'}',
                  subtitle:
                      'Due ${assignment['dueDate'] ?? '-'}$subject\n${assignment['instructions'] ?? ''}',
                );
              }).toList(),
            ),
    );
  }

  Widget _reportCardPanel() {
    final summary = (_reportCard?['summary'] as Map?)?.cast<String, Object?>();
    final results = ((_reportCard?['results'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
    return _Panel(
      title: 'Report Card',
      child: results.isEmpty
          ? const EmptyStateView(
              title: 'No published marks',
              description:
                  'Exam results published by the school will appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary?['percentage'] ?? '-'}% overall • ${summary?['totalObtained'] ?? 0}/${summary?['totalMax'] ?? 0}',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 10),
                ...results.map((result) {
                  return _ListRow(
                    title:
                        '${result['name'] ?? 'Exam'} • ${result['marksObtained']}/${result['maxMarks']}',
                    subtitle:
                        '${result['subjectName'] ?? 'General'} • ${result['examDate'] ?? '-'}\n${result['remarks'] ?? ''}',
                  );
                }),
              ],
            ),
    );
  }

  Widget _feesPanel() {
    final summary = (_fees?['summary'] as Map?)?.cast<String, Object?>();
    final allocations = ((_fees?['allocations'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();
    final payments = ((_fees?['payments'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList();

    final totalBilled = (summary?['totalBilled'] as num?)?.toInt() ?? 0;
    final totalPaid = (summary?['totalPaid'] as num?)?.toInt() ?? 0;
    final balanceDue = (summary?['balanceDue'] as num?)?.toInt() ?? 0;

    return _Panel(
      title: 'Fees & Payments',
      child: allocations.isEmpty && payments.isEmpty
          ? const EmptyStateView(
              title: 'No fee records found',
              description:
                  'Fee structures and payment receipts for this student will appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: AppRadii.rMd,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _feeStatColumn('Billed', '₹$totalBilled'),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.primaryBorder,
                      ),
                      _feeStatColumn('Paid', '₹$totalPaid'),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.primaryBorder,
                      ),
                      _feeStatColumn(
                        'Balance Due',
                        '₹$balanceDue',
                        isHighlight: balanceDue > 0,
                      ),
                    ],
                  ),
                ),
                if (allocations.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Text(
                      'FEE ALLOCATIONS',
                      style: AppTypography.metadata.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...allocations.map((a) {
                    final status = a['status'] as String? ?? 'pending';
                    final billed = (a['amount'] as num?)?.toInt() ?? 0;
                    final paid = (a['paidAmount'] as num?)?.toInt() ?? 0;
                    final bal = (a['balanceAmount'] as num?)?.toInt() ?? 0;
                    final badgeTone = switch (status) {
                      'paid' => BadgeTone.success,
                      'partial' => BadgeTone.warning,
                      'overdue' => BadgeTone.error,
                      _ => BadgeTone.neutral,
                    };

                    return _ListRow(
                      title: a['feeStructureName'] as String? ?? 'Fee',
                      subtitle:
                          'Due ${a['dueDate'] ?? '-'} • Billed ₹$billed • Paid ₹$paid${bal > 0 ? ' • Due ₹$bal' : ''}',
                      trailing: StatusBadge(
                        label: status.toUpperCase(),
                        tone: badgeTone,
                      ),
                    );
                  }),
                ],
                if (payments.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Text(
                      'RECENT RECEIPTS',
                      style: AppTypography.metadata.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...payments.map((p) {
                    final amount = (p['amountPaid'] as num?)?.toInt() ?? 0;
                    final method =
                        (p['paymentMethod'] as String? ?? 'cash').toUpperCase();
                    final paidAt = p['paidAt'] as String? ?? '';
                    final dateStr =
                        paidAt.length >= 10 ? paidAt.substring(0, 10) : paidAt;

                    return _ListRow(
                      title: 'Receipt ${p['receiptNumber'] ?? '—'} • ₹$amount',
                      subtitle:
                          '${p['feeStructureName'] ?? 'Fee'} • $method${dateStr.isNotEmpty ? ' • $dateStr' : ''}',
                      trailing: const StatusBadge(
                        label: 'PAID',
                        tone: BadgeTone.success,
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }

  Widget _feeStatColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.statusError : AppColors.primaryText,
          ),
        ),
      ],
    );
  }

  Map<String, Object?>? get _selectedStudent {
    if (_students.isEmpty) return null;
    return _students.firstWhere(
      (student) => student['id'] == _selectedStudentId,
      orElse: () => _students.first,
    );
  }
}

class _PortalTopBar extends StatelessWidget {
  const _PortalTopBar({required this.onRefresh, required this.onSignOut});

  final VoidCallback? onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: Row(
        children: [
          const Text(
            'Schoolic.',
            style: TextStyle(
              fontFamily: 'Switzer',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Student & Parent Portal',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondaryText, height: 1.35),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

String _dayName(Object? day) {
  const names = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };
  return names[day as int?] ?? 'Day';
}

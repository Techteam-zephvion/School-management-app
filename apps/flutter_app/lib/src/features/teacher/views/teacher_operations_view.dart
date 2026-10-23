import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';

class TeacherOperationsView extends ConsumerStatefulWidget {
  const TeacherOperationsView({
    required this.assignments,
    this.initialTab = 0,
    super.key,
  });

  final List<Map<String, Object?>> assignments;
  final int initialTab;

  @override
  ConsumerState<TeacherOperationsView> createState() =>
      _TeacherOperationsViewState();
}

class _TeacherOperationsViewState extends ConsumerState<TeacherOperationsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  String? _notice;
  List<Map<String, Object?>> _myLeaves = const [];
  List<Map<String, Object?>> _studentLeaves = const [];
  List<Map<String, Object?>> _calendar = const [];
  List<Map<String, Object?>> _ptmSlots = const [];
  List<Map<String, Object?>> _reportCards = const [];
  List<Map<String, Object?>> _schemes = const [];
  List<Map<String, Object?>> _riskAlerts = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant TeacherOperationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabs.animateTo(widget.initialTab.clamp(0, 4));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
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
      final responses = await Future.wait([
        api.getList('/api/v1/teacher/my-leaves', session: session),
        api.getList('/api/v1/teacher/student-leaves', session: session),
        api.getList('/api/v1/teacher/calendar', session: session),
        api.getList('/api/v1/teacher/ptm/slots', session: session),
        api.getList('/api/v1/teacher/report-cards', session: session),
        api.getList('/api/v1/teacher/grading-schemes', session: session),
        api.getList('/api/v1/teacher/at-risk-students', session: session),
      ]);
      if (!mounted) return;
      setState(() {
        _myLeaves = responses[0];
        _studentLeaves = responses[1];
        _calendar = responses[2];
        _ptmSlots = responses[3];
        _reportCards = responses[4];
        _schemes = responses[5];
        _riskAlerts = responses[6];
      });
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _success(String message) {
    setState(() {
      _notice = message;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Teacher operations',
          description: 'Manage leave, student requests, meetings, report cards, and student support.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          FeedbackBanner(
            message: 'Unable to load teacher operations. $_error',
            tone: FeedbackTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
        if (_notice != null)
          FeedbackBanner(
            message: _notice!,
            tone: FeedbackTone.success,
            onDismiss: () => setState(() => _notice = null),
          ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'My leave'),
            Tab(text: 'Student leave'),
            Tab(text: 'Calendar & PTM'),
            Tab(text: 'Report cards'),
            Tab(text: 'At-risk students'),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          SizedBox(
            height: MediaQuery.sizeOf(context).height - 250,
            child: TabBarView(
              controller: _tabs,
              children: [
                _leaveTab(),
                _studentLeaveTab(),
                _calendarPtmTab(),
                _reportCardsTab(),
                _riskTab(),
              ],
            ),
          ),
      ],
    );
  }

  int _approvedDays(String type) {
    int count = 0;
    for (final l in _myLeaves) {
      if (l['status'] == 'approved' &&
          (l['leaveType'] as String? ?? '').toLowerCase() ==
              type.toLowerCase()) {
        final start = DateTime.tryParse(l['startDate'] as String? ?? '');
        final end = DateTime.tryParse(l['endDate'] as String? ?? '');
        if (start != null && end != null) {
          count += end.difference(start).inDays + 1;
        } else {
          count += 1;
        }
      }
    }
    return count;
  }

  Widget _balanceCard(
    String label,
    int remaining,
    int total,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$remaining',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    TextSpan(
                      text: ' / $total days',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leaveTab() {
    final casualRem = (12 - _approvedDays('casual')).clamp(0, 12);
    final sickRem = (10 - _approvedDays('sick')).clamp(0, 10);
    final earnedRem = (15 - _approvedDays('earned')).clamp(0, 15);

    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3,
                  child: _balanceCard(
                    'Casual Leave',
                    casualRem,
                    12,
                    Icons.beach_access_outlined,
                    AppColors.brandCyanDark,
                  ),
                ),
                SizedBox(
                  width: isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3,
                  child: _balanceCard(
                    'Sick Leave',
                    sickRem,
                    10,
                    Icons.healing_outlined,
                    AppColors.statusWarning,
                  ),
                ),
                SizedBox(
                  width: isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3,
                  child: _balanceCard(
                    'Earned Leave',
                    earnedRem,
                    15,
                    Icons.stars_outlined,
                    AppColors.statusSuccess,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _applyForLeave,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Apply for leave'),
          ),
        ),
        const SizedBox(height: 14),
        if (_myLeaves.isEmpty)
          const EmptyStateView(
            title: 'No leave applications',
            description: 'Select Apply for leave to submit your first request.',
            icon: Icons.event_available_outlined,
          )
        else
          ..._myLeaves.map(
            (leave) => _recordCard(
              title: '${leave['leaveType'] ?? 'Leave'}',
              subtitle: '${leave['startDate']} – ${leave['endDate']}',
              status: leave['status'] as String?,
              body: leave['reason'] as String?,
            ),
          ),
      ],
    );
  }

  Future<void> _applyForLeave() async {
    final type = ValueNotifier('casual');
    final start = TextEditingController(text: _dateAfter(1));
    final end = TextEditingController(text: _dateAfter(1));
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for leave'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: type,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'Leave type'),
                  items: const [
                    DropdownMenuItem(value: 'casual', child: Text('Casual')),
                    DropdownMenuItem(value: 'sick', child: Text('Sick')),
                    DropdownMenuItem(value: 'earned', child: Text('Earned')),
                    DropdownMenuItem(
                      value: 'maternity_paternity',
                      child: Text('Maternity or paternity'),
                    ),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (next) => type.value = next ?? value,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: start,
                decoration: const InputDecoration(
                  labelText: 'Start date',
                  helperText: 'Use YYYY-MM-DD.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: end,
                decoration: const InputDecoration(
                  labelText: 'End date',
                  helperText: 'Use YYYY-MM-DD.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit application'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    if (reason.text.trim().length < 2) {
      setState(() => _error = 'Add a reason before submitting leave.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref.read(apiClientProvider).postJson('/api/v1/teacher/my-leaves', {
        'leaveType': type.value,
        'startDate': start.text.trim(),
        'endDate': end.text.trim(),
        'reason': reason.text.trim(),
      }, session: session);
      _success('Leave application submitted.');
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to submit leave. ${exception.message}');
    }
  }

  Widget _studentLeaveTab() {
    if (_studentLeaves.isEmpty) {
      return const EmptyStateView(
        title: 'No student leave requests',
        description:
            'New requests from your assigned students will appear here.',
        icon: Icons.inbox_outlined,
      );
    }
    return ListView(
      children: _studentLeaves.map((leave) {
        final isPending = leave['status'] == 'pending';
        return _recordCard(
          title: '${leave['studentName'] ?? leave['fullName'] ?? 'Student'}',
          subtitle: '${leave['startDate']} – ${leave['endDate']}',
          status: leave['status'] as String?,
          body: leave['reason'] as String?,
          actions: isPending
              ? [
                  OutlinedButton(
                    onPressed: () => _reviewStudentLeave(leave, 'rejected'),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed: () => _reviewStudentLeave(leave, 'approved'),
                    child: const Text('Approve'),
                  ),
                ]
              : null,
        );
      }).toList(),
    );
  }

  Future<void> _reviewStudentLeave(
    Map<String, Object?> leave,
    String status,
  ) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'approved' ? 'Approve leave' : 'Reject leave'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review notes',
            helperText: 'Optional note visible in the leave record.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              status == 'approved' ? 'Approve leave' : 'Reject leave',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    final id = leave['id'];
    if (session == null || id == null) return;
    try {
      await ref.read(apiClientProvider).putJson(
        '/api/v1/teacher/student-leaves/$id/status',
        {
          'status': status,
          if (notes.text.trim().isNotEmpty) 'reviewerNotes': notes.text.trim(),
        },
        session: session,
      );
      _success(
        'Student leave ${status == 'approved' ? 'approved' : 'rejected'}.',
      );
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to review leave. ${exception.message}');
    }
  }

  Widget _calendarPtmTab() {
    return ListView(
      children: [
        Text('Calendar', style: AppTypography.sectionHeading),
        const SizedBox(height: 10),
        if (_calendar.isEmpty)
          const Text(
            'No upcoming calendar events.',
            style: AppTypography.bodySecondary,
          )
        else
          ..._calendar.map(
            (event) => _recordCard(
              title: event['title'] as String? ?? 'Calendar event',
              subtitle:
                  '${event['startDate'] ?? ''} – ${event['endDate'] ?? ''}',
              status: event['eventType'] as String?,
              body: event['description'] as String?,
            ),
          ),
        const SizedBox(height: 18),
        Text('Parent-teacher meetings', style: AppTypography.sectionHeading),
        const SizedBox(height: 10),
        if (_ptmSlots.isEmpty)
          const Text(
            'No PTM slots assigned.',
            style: AppTypography.bodySecondary,
          )
        else
          ..._ptmSlots.map(
            (slot) => _recordCard(
              title: '${slot['studentName'] ?? 'Available slot'}',
              subtitle:
                  '${slot['eventDate'] ?? slot['date'] ?? ''} • ${slot['startTime'] ?? ''}–${slot['endTime'] ?? ''}',
              status: slot['status'] as String?,
              body: slot['parentNotes'] as String?,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _updatePtmSlot(slot),
                  icon: const Icon(Icons.edit_note_outlined, size: 16),
                  label: const Text('Add meeting notes'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _updatePtmSlot(Map<String, Object?> slot) async {
    final notes = TextEditingController(
      text: slot['teacherNotes'] as String? ?? '',
    );
    String status = slot['status'] as String? ?? 'booked';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Update meeting'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Meeting status',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(value: 'booked', child: Text('Booked')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Teacher notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save meeting'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final session = ref.read(authControllerProvider).session;
    final id = slot['id'];
    if (session == null || id == null) return;
    try {
      await ref.read(apiClientProvider).putJson(
        '/api/v1/teacher/ptm/slots/$id/notes',
        {'teacherNotes': notes.text.trim(), 'status': status},
        session: session,
      );
      _success('Meeting updated.');
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to update meeting. ${exception.message}');
    }
  }

  Widget _reportCardsTab() {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.assignments.isEmpty || _schemes.isEmpty
                ? null
                : _generateReportCards,
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('Generate report cards'),
          ),
        ),
        if (_schemes.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'An administrator must configure a grading scheme before report cards can be generated.',
            style: AppTypography.bodySecondary,
          ),
        ],
        const SizedBox(height: 14),
        if (_reportCards.isEmpty)
          const EmptyStateView(
            title: 'No report cards yet',
            description: 'Generate report cards after marks and a grading scheme are ready.',
            icon: Icons.description_outlined,
          )
        else
          ..._reportCards.map(
            (card) => _recordCard(
              title: '${card['studentName'] ?? 'Student report card'}',
              subtitle:
                  '${card['term'] ?? ''} • ${card['percentage'] ?? card['overallPercentage'] ?? '—'}%',
              status: card['isPublished'] == true ? 'published' : 'draft',
              body: card['teacherRemarks'] as String?,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _setReportCardPublished(
                    card,
                    card['isPublished'] != true,
                  ),
                  icon: Icon(
                    card['isPublished'] == true
                        ? Icons.visibility_off_outlined
                        : Icons.publish_outlined,
                    size: 16,
                  ),
                  label: Text(
                    card['isPublished'] == true ? 'Return to draft' : 'Publish',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _generateReportCards() async {
    var assignment = widget.assignments.first;
    var scheme = _schemes.first;
    var term = 'annual';
    final remarks = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Generate report cards'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<Map<String, Object?>>(
                  initialValue: assignment,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class and subject',
                  ),
                  items: widget.assignments
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item['className']} ${item['sectionName']} • ${item['subjectName'] ?? 'Class'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => assignment = value ?? assignment),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, Object?>>(
                  initialValue: scheme,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Grading scheme',
                  ),
                  items: _schemes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item['name'] ?? 'Grading scheme'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => scheme = value ?? scheme),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: term,
                  decoration: const InputDecoration(labelText: 'Term'),
                  items: const [
                    DropdownMenuItem(value: 'term_1', child: Text('Term 1')),
                    DropdownMenuItem(value: 'term_2', child: Text('Term 2')),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                    DropdownMenuItem(
                      value: 'all_terms',
                      child: Text('All terms'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => term = value ?? term),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarks,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Default teacher remarks',
                    helperText:
                        'Optional. You can review remarks before publishing.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Generate report cards'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/teacher/report-cards/generate',
        {
          'academicYearId': assignment['academicYearId'],
          'classId': assignment['classId'],
          'sectionId': assignment['sectionId'],
          'schemeId': scheme['id'],
          'term': term,
          if (remarks.text.trim().isNotEmpty)
            'teacherRemarks': remarks.text.trim(),
        },
        session: session,
      );
      _success('Report cards generated. Review them before publication.');
      await _load();
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to generate report cards. ${exception.message}',
      );
    }
  }

  Future<void> _setReportCardPublished(
    Map<String, Object?> card,
    bool isPublished,
  ) async {
    final session = ref.read(authControllerProvider).session;
    final id = card['id'] as String?;
    if (session == null || id == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .publishTeacherReportCard(
            session: session,
            reportCardId: id,
            isPublished: isPublished,
          );
      _success(
        isPublished
            ? 'Report card published to the portal.'
            : 'Report card returned to draft.',
      );
      await _load();
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to update report card. ${exception.message}',
      );
    }
  }

  Widget _riskTab() {
    if (_riskAlerts.isEmpty) {
      return const EmptyStateView(
        title: 'No active risk alerts',
        description: 'Students needing intervention in your assigned classes will appear here.',
        icon: Icons.health_and_safety_outlined,
      );
    }
    return ListView(
      children: _riskAlerts
          .map(
            (alert) => _recordCard(
              title: '${alert['studentName'] ?? 'Student'}',
              subtitle:
                  'Risk score ${alert['compositeScore'] ?? '—'} • ${alert['riskLevel'] ?? 'unrated'}',
              status:
                  alert['status'] as String? ?? alert['riskLevel'] as String?,
              body: _riskSummary(alert),
              actions: [
                FilledButton.tonalIcon(
                  onPressed: () => _recordIntervention(alert),
                  icon: const Icon(Icons.add_task_outlined, size: 16),
                  label: const Text('Record intervention'),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  String _riskSummary(Map<String, Object?> alert) {
    final factors = alert['riskFactors'] ?? alert['factors'];
    return factors == null
        ? 'Open this alert and record the support provided.'
        : '$factors';
  }

  Future<void> _recordIntervention(Map<String, Object?> alert) async {
    final action = TextEditingController();
    final notes = TextEditingController();
    var status = 'acknowledged';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Record student intervention'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: action,
                  decoration: const InputDecoration(
                    labelText: 'Action taken',
                    helperText: 'For example: Parent meeting scheduled.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Intervention notes',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Alert status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'acknowledged',
                      child: Text('Acknowledged'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save intervention'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (action.text.trim().length < 2 || notes.text.trim().length < 3) {
      setState(() => _error = 'Add the action taken and intervention notes.');
      return;
    }
    final studentId =
        alert['studentId'] ??
        (alert['student'] is Map ? (alert['student'] as Map)['id'] : null);
    final session = ref.read(authControllerProvider).session;
    if (session == null || studentId == null) {
      setState(
        () => _error = 'This alert does not include a student identifier.',
      );
      return;
    }
    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/teacher/at-risk-students/$studentId/intervene',
        {
          'action': action.text.trim(),
          'notes': notes.text.trim(),
          'status': status,
        },
        session: session,
      );
      _success('Intervention recorded.');
      await _load();
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to record intervention. ${exception.message}',
      );
    }
  }

  Widget _recordCard({
    required String title,
    required String subtitle,
    String? status,
    String? body,
    List<Widget>? actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: AppTypography.subsectionHeading),
              if (status != null) StatusBadge.fromStatusString(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.metadata),
          if (body != null && body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body, style: AppTypography.bodySecondary),
          ],
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

String _dateAfter(int days) {
  final date = DateTime.now().add(Duration(days: days));
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

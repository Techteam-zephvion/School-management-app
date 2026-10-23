import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/status_badge.dart';

class StudentServicesView extends ConsumerStatefulWidget {
  const StudentServicesView({
    required this.studentId,
    required this.timetableEntries,
    super.key,
  });

  final String studentId;
  final List<Map<String, Object?>> timetableEntries;

  @override
  ConsumerState<StudentServicesView> createState() =>
      _StudentServicesViewState();
}

class _StudentServicesViewState extends ConsumerState<StudentServicesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  String? _notice;
  List<Map<String, Object?>> _conversations = const [];
  List<Map<String, Object?>> _notifications = const [];
  List<Map<String, Object?>> _leaves = const [];
  List<Map<String, Object?>> _calendar = const [];
  List<Map<String, Object?>> _ptmSlots = const [];
  List<Map<String, Object?>> _certificates = const [];
  List<Map<String, Object?>> _consents = const [];
  List<Map<String, Object?>> _requests = const [];
  Map<String, Object?> _transport = const {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentServicesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) _load();
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
      final query = '?studentId=${widget.studentId}';
      final responses = await Future.wait<Object>([
        api.getList('/api/v1/portal/chat/conversations', session: session),
        api.getList('/api/v1/portal/notifications', session: session),
        api.getList('/api/v1/portal/leaves$query', session: session),
        api.getList('/api/v1/portal/calendar', session: session),
        api.getList('/api/v1/portal/ptm/slots', session: session),
        api.getJson('/api/v1/portal/transport$query', session: session),
        api.getList('/api/v1/portal/certificates$query', session: session),
        api.getList('/api/v1/portal/dpdp/consents', session: session),
        api.getList('/api/v1/portal/dpdp/dsr', session: session),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = responses[0] as List<Map<String, Object?>>;
        _notifications = responses[1] as List<Map<String, Object?>>;
        _leaves = responses[2] as List<Map<String, Object?>>;
        _calendar = responses[3] as List<Map<String, Object?>>;
        _ptmSlots = responses[4] as List<Map<String, Object?>>;
        _transport = responses[5] as Map<String, Object?>;
        _certificates = responses[6] as List<Map<String, Object?>>;
        _consents = responses[7] as List<Map<String, Object?>>;
        _requests = responses[8] as List<Map<String, Object?>>;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Services', style: AppTypography.pageTitle),
                  const SizedBox(height: 4),
                  const Text(
                    'Messages, leave, meetings, transport, certificates, and privacy requests.',
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh services',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null)
          FeedbackBanner(
            message: 'Unable to load services. $_error',
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
            Tab(text: 'Messages'),
            Tab(text: 'Notifications'),
            Tab(text: 'Leave'),
            Tab(text: 'Calendar & PTM'),
            Tab(text: 'Transport'),
            Tab(text: 'Certificates'),
            Tab(text: 'Privacy'),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          SizedBox(
            height: MediaQuery.sizeOf(context).height - 260,
            child: TabBarView(
              controller: _tabs,
              children: [
                _messagesTab(),
                _notificationsTab(),
                _leaveTab(),
                _calendarTab(),
                _transportTab(),
                _certificatesTab(),
                _privacyTab(),
              ],
            ),
          ),
      ],
    );
  }

  List<Map<String, Object?>> get _teachers {
    final byId = <String, Map<String, Object?>>{};
    for (final entry in widget.timetableEntries) {
      final id = entry['staffId'] as String?;
      if (id != null) {
        byId[id] = {
          'id': id,
          'name': entry['staffName'] ?? 'Teacher',
          'subject': entry['subjectName'] ?? 'Class',
        };
      }
    }
    return byId.values.toList();
  }

  Widget _messagesTab() {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _teachers.isEmpty ? null : _startConversation,
            icon: const Icon(Icons.add_comment_outlined, size: 16),
            label: const Text('Message a teacher'),
          ),
        ),
        if (_teachers.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'A teacher will be available after the timetable is assigned.',
            style: AppTypography.bodySecondary,
          ),
        ],
        const SizedBox(height: 14),
        if (_conversations.isEmpty)
          const EmptyStateView(
            title: 'No conversations yet',
            description: 'Select Message a teacher to ask a question or request support.',
            icon: Icons.chat_bubble_outline,
          )
        else
          ..._conversations.map(
            (conversation) => _card(
              title:
                  '${conversation['teacherName'] ?? conversation['subject'] ?? 'Teacher'}',
              subtitle: '${conversation['subject'] ?? 'Conversation'}',
              status: conversation['status'] as String?,
              body: conversation['lastMessage'] as String?,
              actions: [
                FilledButton.tonal(
                  onPressed: () => _openConversation(conversation),
                  child: const Text('Open conversation'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _startConversation() async {
    var teacher = _teachers.first;
    final subject = TextEditingController();
    final message = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Message a teacher'),
          content: SizedBox(
            width: 500,
            child: ListView(
              shrinkWrap: true,
              children: [
                DropdownButtonFormField<Map<String, Object?>>(
                  initialValue: teacher,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Teacher'),
                  items: _teachers
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item['name']} • ${item['subject']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => teacher = value ?? teacher),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
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
              child: const Text('Send message'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (subject.text.trim().isEmpty || message.text.trim().isEmpty) {
      setState(() => _error = 'Add a subject and message before sending.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/portal/chat/conversations',
        {
          'studentId': widget.studentId,
          'teacherStaffId': teacher['id'],
          'subject': subject.text.trim(),
          'initialMessage': message.text.trim(),
        },
        session: session,
      );
      _success('Message sent.');
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to send message. ${exception.message}');
    }
  }

  Future<void> _openConversation(Map<String, Object?> conversation) async {
    final session = ref.read(authControllerProvider).session;
    final id = conversation['id'];
    if (session == null || id == null) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .getJson(
            '/api/v1/portal/chat/conversations/$id/messages',
            session: session,
          );
      if (!mounted) return;
      final messages = ((response['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .toList();
      final reply = TextEditingController();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${conversation['subject'] ?? 'Conversation'}'),
          content: SizedBox(
            width: 560,
            height: 440,
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text('No messages yet.'))
                      : ListView.separated(
                          itemCount: messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) => _card(
                            title:
                                '${messages[index]['senderName'] ?? messages[index]['senderRole'] ?? 'Message'}',
                            subtitle: '${messages[index]['createdAt'] ?? ''}',
                            body: messages[index]['content'] as String?,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reply,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reply'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                if (reply.text.trim().isEmpty) return;
                await ref.read(apiClientProvider).postJson(
                  '/api/v1/portal/chat/conversations/$id/messages',
                  {'content': reply.text.trim()},
                  session: session,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _success('Reply sent.');
                await _load();
              },
              child: const Text('Send reply'),
            ),
          ],
        ),
      );
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to open conversation. ${exception.message}',
      );
    }
  }

  Widget _notificationsTab() {
    if (_notifications.isEmpty) {
      return const EmptyStateView(
        title: 'No notifications',
        description: 'School alerts and updates will appear here.',
        icon: Icons.notifications_none,
      );
    }
    return ListView(
      children: _notifications
          .map(
            (item) => _card(
              title: item['title'] as String? ?? 'Notification',
              subtitle: '${item['createdAt'] ?? item['sentAt'] ?? ''}',
              status: item['status'] as String?,
              body: (item['body'] ?? item['message']) as String?,
            ),
          )
          .toList(),
    );
  }

  Widget _leaveTab() {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _applyForLeave,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Apply for student leave'),
          ),
        ),
        const SizedBox(height: 14),
        if (_leaves.isEmpty)
          const EmptyStateView(
            title: 'No leave applications',
            description:
                'Submit an application when the student will be absent.',
            icon: Icons.event_busy_outlined,
          )
        else
          ..._leaves.map(
            (leave) => _card(
              title: '${leave['startDate']} – ${leave['endDate']}',
              subtitle: leave['reason'] as String? ?? 'Leave request',
              status: leave['status'] as String?,
              body: leave['reviewerNotes'] as String?,
            ),
          ),
      ],
    );
  }

  Future<void> _applyForLeave() async {
    final start = TextEditingController(text: _dateAfter(1));
    final end = TextEditingController(text: _dateAfter(1));
    final reason = TextEditingController();
    final document = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for student leave'),
        content: SizedBox(
          width: 500,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final field in [
                (start, 'Start date', 'Use YYYY-MM-DD.'),
                (end, 'End date', 'Use YYYY-MM-DD.'),
                (reason, 'Reason', null),
                (document, 'Medical document URL', 'Optional HTTPS link.'),
              ]) ...[
                TextField(
                  controller: field.$1,
                  maxLines: field.$2 == 'Reason' ? 3 : 1,
                  decoration: InputDecoration(
                    labelText: field.$2,
                    helperText: field.$3,
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
    if (confirmed != true) return;
    if (reason.text.trim().length < 2) {
      setState(() => _error = 'Add a reason before submitting leave.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref.read(apiClientProvider).postJson('/api/v1/portal/leaves', {
        'studentId': widget.studentId,
        'startDate': start.text.trim(),
        'endDate': end.text.trim(),
        'reason': reason.text.trim(),
        if (document.text.trim().isNotEmpty)
          'documentUrl': document.text.trim(),
      }, session: session);
      _success('Leave application submitted.');
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to submit leave. ${exception.message}');
    }
  }

  Widget _calendarTab() {
    return ListView(
      children: [
        Text('School calendar', style: AppTypography.sectionHeading),
        const SizedBox(height: 10),
        if (_calendar.isEmpty)
          const Text('No upcoming events.', style: AppTypography.bodySecondary)
        else
          ..._calendar.map(
            (event) => _card(
              title: event['title'] as String? ?? 'School event',
              subtitle:
                  '${event['startDate'] ?? ''} – ${event['endDate'] ?? ''}',
              status: event['eventType'] as String?,
              body: event['description'] as String?,
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Parent-teacher meeting slots',
          style: AppTypography.sectionHeading,
        ),
        const SizedBox(height: 10),
        if (_ptmSlots.isEmpty)
          const Text(
            'No PTM slots are available.',
            style: AppTypography.bodySecondary,
          )
        else
          ..._ptmSlots.map((slot) {
            final status = slot['status'] as String? ?? 'available';
            final isBookedForStudent = slot['studentId'] == widget.studentId;
            return _card(
              title: '${slot['teacherName'] ?? 'Teacher'}',
              subtitle:
                  '${slot['eventDate'] ?? slot['date'] ?? ''} • ${slot['startTime'] ?? ''}–${slot['endTime'] ?? ''}',
              status: status,
              body: slot['parentNotes'] as String?,
              actions: status == 'available'
                  ? [
                      FilledButton.tonal(
                        onPressed: () => _bookPtm(slot),
                        child: const Text('Book slot'),
                      ),
                    ]
                  : isBookedForStudent
                  ? [
                      OutlinedButton(
                        onPressed: () => _cancelPtm(slot),
                        child: const Text('Cancel booking'),
                      ),
                    ]
                  : null,
            );
          }),
      ],
    );
  }

  Future<void> _bookPtm(Map<String, Object?> slot) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Book PTM slot'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes for the teacher',
            helperText: 'Optional topic or question for the meeting.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Book slot'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null || slot['id'] == null) return;
    try {
      await ref.read(apiClientProvider).postJson('/api/v1/portal/ptm/book', {
        'slotId': slot['id'],
        'studentId': widget.studentId,
        if (notes.text.trim().isNotEmpty) 'parentNotes': notes.text.trim(),
      }, session: session);
      _success('PTM slot booked.');
      await _load();
    } on ApiException catch (exception) {
      setState(() => _error = 'Unable to book this slot. ${exception.message}');
    }
  }

  Future<void> _cancelPtm(Map<String, Object?> slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel PTM booking?'),
        content: const Text(
          'The meeting slot will become available to other families.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null || slot['id'] == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .putJson(
            '/api/v1/portal/ptm/cancel/${slot['id']}',
            const {},
            session: session,
          );
      _success('PTM booking cancelled.');
      await _load();
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to cancel this booking. ${exception.message}',
      );
    }
  }

  Widget _transportTab() {
    if (_transport['isAllocated'] != true) {
      return const EmptyStateView(
        title: 'No transport assigned',
        description: 'Contact the school transport office if a route should be assigned.',
        icon: Icons.directions_bus_outlined,
      );
    }
    final allocation =
        (_transport['allocation'] as Map?)?.cast<String, Object?>() ??
        _transport;
    return ListView(
      children: [
        _card(
          title:
              '${allocation['routeName'] ?? allocation['routeNumber'] ?? 'School transport'}',
          subtitle: '${allocation['vehicleNumber'] ?? 'Vehicle pending'}',
          status: allocation['status'] as String? ?? 'active',
          body:
              'Stop: ${allocation['stopName'] ?? '—'}\nPickup: ${allocation['pickupTime'] ?? '—'} • Drop: ${allocation['dropTime'] ?? '—'}\nDriver: ${allocation['driverName'] ?? '—'} • ${allocation['driverPhone'] ?? 'No phone listed'}',
        ),
      ],
    );
  }

  Widget _certificatesTab() {
    if (_certificates.isEmpty) {
      return const EmptyStateView(
        title: 'No certificates issued',
        description:
            'Official certificates issued by the school will appear here.',
        icon: Icons.verified_outlined,
      );
    }
    return ListView(
      children: _certificates
          .map(
            (item) => _card(
              title: '${item['certificateType'] ?? 'Official certificate'}',
              subtitle:
                  '${item['certificateNumber'] ?? item['serialNumber'] ?? ''}',
              status: item['status'] as String?,
              body:
                  'Issued ${item['issueDate'] ?? '—'}\nVerification code: ${item['verificationCode'] ?? '—'}',
            ),
          )
          .toList(),
    );
  }

  Widget _privacyTab() {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _submitPrivacyRequest,
            icon: const Icon(Icons.privacy_tip_outlined, size: 16),
            label: const Text('Submit privacy request'),
          ),
        ),
        const SizedBox(height: 14),
        Text('Consent records', style: AppTypography.sectionHeading),
        const SizedBox(height: 8),
        if (_consents.isEmpty)
          const Text(
            'No consent records found.',
            style: AppTypography.bodySecondary,
          )
        else
          ..._consents.map(
            (item) => _card(
              title: '${item['consentType'] ?? 'Consent'}',
              subtitle: '${item['recordedAt'] ?? item['createdAt'] ?? ''}',
              status: item['status'] as String?,
              body: 'Verified via ${item['verifiedVia'] ?? 'school record'}',
            ),
          ),
        const SizedBox(height: 18),
        Text('Data requests', style: AppTypography.sectionHeading),
        const SizedBox(height: 8),
        if (_requests.isEmpty)
          const Text(
            'No privacy requests submitted.',
            style: AppTypography.bodySecondary,
          )
        else
          ..._requests.map(
            (item) => _card(
              title: '${item['requestType'] ?? 'Data request'}',
              subtitle: '${item['createdAt'] ?? ''}',
              status: item['status'] as String?,
              body: (item['reason'] ?? item['resolutionNotes']) as String?,
            ),
          ),
      ],
    );
  }

  Future<void> _submitPrivacyRequest() async {
    var type = 'data_access';
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Submit privacy request'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Request type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'data_access',
                      child: Text('Access my data'),
                    ),
                    DropdownMenuItem(
                      value: 'data_rectification',
                      child: Text('Correct my data'),
                    ),
                    DropdownMenuItem(
                      value: 'data_erasure_anonymization',
                      child: Text('Erase or anonymize my data'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason and details',
                    helperText: 'Describe what you need the school to review.',
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
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (reason.text.trim().length < 5) {
      setState(
        () => _error = 'Describe the privacy request in at least 5 characters.',
      );
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref.read(apiClientProvider).postJson('/api/v1/portal/dpdp/dsr', {
        'studentId': widget.studentId,
        'requestType': type,
        'reason': reason.text.trim(),
      }, session: session);
      _success('Privacy request submitted.');
      await _load();
    } on ApiException catch (exception) {
      setState(
        () => _error = 'Unable to submit privacy request. ${exception.message}',
      );
    }
  }

  Widget _card({
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
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.metadata),
          ],
          if (body != null && body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(body, style: AppTypography.bodySecondary),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../components/empty_state_view.dart';
import '../components/feedback_banner.dart';
import '../components/page_header.dart';
import '../components/status_badge.dart';

enum AnnouncementWorkspace { admin, teacher }

class AnnouncementsView extends ConsumerStatefulWidget {
  const AnnouncementsView({
    required this.workspace,
    required this.endpoint,
    this.classes = const [],
    this.sections = const [],
    this.assignments = const [],
    super.key,
  });

  final AnnouncementWorkspace workspace;
  final String endpoint;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> assignments;

  @override
  ConsumerState<AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends ConsumerState<AnnouncementsView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, Object?>> _announcements = [];
  String _audience = 'school';
  String _priority = 'normal';
  String? _classId;
  String? _sectionId;
  bool _loading = true;
  bool _publishing = false;
  String? _error;
  String? _notice;

  bool get _isTeacher => widget.workspace == AnnouncementWorkspace.teacher;

  @override
  void initState() {
    super.initState();
    if (_isTeacher) {
      _audience = 'class_section';
      if (widget.assignments.isNotEmpty) {
        final first = widget.assignments.first;
        _classId = first['classId'] as String?;
        _sectionId = first['sectionId'] as String?;
      }
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant AnnouncementsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isTeacher && _classId == null && widget.assignments.isNotEmpty) {
      final first = widget.assignments.first;
      _classId = first['classId'] as String?;
      _sectionId = first['sectionId'] as String?;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(apiClientProvider)
          .getList(widget.endpoint, session: session);
      if (mounted) setState(() => _announcements = rows);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _publishing) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 3 || body.length < 3) {
      setState(() => _error = 'Add a title and message before publishing.');
      return;
    }
    if (_audience == 'class_section' &&
        (_classId == null || _sectionId == null)) {
      setState(() => _error = 'Choose a class section for this announcement.');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(apiClientProvider).postJson(widget.endpoint, {
        'audience': _audience,
        'priority': _priority,
        'title': title,
        'body': body,
        if (_audience == 'class_section') 'classId': _classId,
        if (_audience == 'class_section') 'sectionId': _sectionId,
      }, session: session);
      _title.clear();
      _body.clear();
      await _load();
      if (mounted) setState(() => _notice = 'Announcement published.');
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: _isTeacher ? 'Announcements' : 'Announcements',
          description: _isTeacher
              ? 'Share updates with assigned class sections and follow school notices.'
              : 'Publish school-wide and class-section communications from one place.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          FeedbackBanner(
            message: _error!,
            tone: FeedbackTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
        if (_notice != null)
          FeedbackBanner(
            message: _notice!,
            tone: FeedbackTone.success,
            onDismiss: () => setState(() => _notice = null),
          ),
        _composer(isPhone: isPhone),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_announcements.isEmpty)
          const EmptyStateView(
            title: 'No announcements yet',
            description: 'Published school and class updates will appear here.',
            icon: Icons.campaign_outlined,
          )
        else
          ..._announcements.map(_announcementCard),
      ],
    );
  }

  Widget _composer({required bool isPhone}) {
    return Container(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New announcement', style: AppTypography.subsectionHeading),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_isTeacher)
                SizedBox(
                  width: isPhone ? double.infinity : 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: const [
                      DropdownMenuItem(
                        value: 'school',
                        child: Text('Whole school'),
                      ),
                      DropdownMenuItem(
                        value: 'class_section',
                        child: Text('Class section'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _audience = value ?? 'school';
                      if (_audience == 'school') {
                        _classId = null;
                        _sectionId = null;
                      }
                    }),
                  ),
                ),
              SizedBox(
                width: isPhone ? double.infinity : 160,
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(
                      value: 'important',
                      child: Text('Important'),
                    ),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) =>
                      setState(() => _priority = value ?? 'normal'),
                ),
              ),
              if (_audience == 'class_section') ..._targetControls(isPhone),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            maxLength: 140,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.campaign_outlined, size: 16),
              label: Text(_publishing ? 'Publishing...' : 'Publish'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _targetControls(bool isPhone) {
    if (_isTeacher) {
      final selected = _assignmentValue(_classId, _sectionId);
      return [
        SizedBox(
          width: isPhone ? double.infinity : 260,
          child: DropdownButtonFormField<String>(
            initialValue:
                widget.assignments.any(
                  (item) =>
                      _assignmentValue(item['classId'], item['sectionId']) ==
                      selected,
                )
                ? selected
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assigned section'),
            items: widget.assignments.map((assignment) {
              final value = _assignmentValue(
                assignment['classId'],
                assignment['sectionId'],
              );
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  '${assignment['className']} ${assignment['sectionName']}',
                ),
              );
            }).toList(),
            onChanged: (value) {
              final assignment = widget.assignments.firstWhere(
                (item) =>
                    _assignmentValue(item['classId'], item['sectionId']) ==
                    value,
                orElse: () => const {},
              );
              setState(() {
                _classId = assignment['classId'] as String?;
                _sectionId = assignment['sectionId'] as String?;
              });
            },
          ),
        ),
      ];
    }

    final availableSections = widget.sections
        .where((section) => section['classId'] == _classId)
        .toList();
    return [
      SizedBox(
        width: isPhone ? double.infinity : 180,
        child: DropdownButtonFormField<String>(
          initialValue: _classId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class'),
          items: widget.classes
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['id'] as String,
                  child: Text('${item['name']}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _classId = value;
            _sectionId = null;
          }),
        ),
      ),
      SizedBox(
        width: isPhone ? double.infinity : 180,
        child: DropdownButtonFormField<String>(
          initialValue:
              availableSections.any((section) => section['id'] == _sectionId)
              ? _sectionId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Section'),
          items: availableSections
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['id'] as String,
                  child: Text('${item['name']}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _sectionId = value),
        ),
      ),
    ];
  }

  Widget _announcementCard(Map<String, Object?> announcement) {
    final audience = announcement['audience'] == 'school'
        ? 'Whole school'
        : '${announcement['className'] ?? 'Class'} ${announcement['sectionName'] ?? ''}'
              .trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: _priorityLabel('${announcement['priority']}'),
                tone: _priorityTone('${announcement['priority']}'),
              ),
              Text(audience, style: AppTypography.metadata),
              Text(
                _formatDate(announcement['publishedAt']),
                style: AppTypography.metadata,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${announcement['title']}',
            style: AppTypography.subsectionHeading,
          ),
          const SizedBox(height: 6),
          Text('${announcement['body']}', style: AppTypography.body),
          const SizedBox(height: 10),
          Text(
            'By ${announcement['authorName'] ?? 'Schoolic'}',
            style: AppTypography.metadata,
          ),
        ],
      ),
    );
  }

  String _assignmentValue(Object? classId, Object? sectionId) =>
      '$classId::$sectionId';

  String _priorityLabel(String value) {
    return switch (value) {
      'urgent' => 'URGENT',
      'important' => 'IMPORTANT',
      _ => 'NOTICE',
    };
  }

  BadgeTone _priorityTone(String value) {
    return switch (value) {
      'urgent' => BadgeTone.error,
      'important' => BadgeTone.warning,
      _ => BadgeTone.neutral,
    };
  }

  String _formatDate(Object? value) {
    if (value == null) return 'Just now';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}

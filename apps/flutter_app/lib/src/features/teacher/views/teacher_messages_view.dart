import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';

class TeacherMessagesView extends ConsumerStatefulWidget {
  const TeacherMessagesView({super.key});

  @override
  ConsumerState<TeacherMessagesView> createState() =>
      _TeacherMessagesViewState();
}

class _TeacherMessagesViewState extends ConsumerState<TeacherMessagesView> {
  int _tabIndex = 0; // 0 = Parent Conversations, 1 = Availability Settings
  bool _loading = false;
  String? _error;
  String? _success;

  // Conversations
  List<Map<String, Object?>> _conversations = const [];
  Map<String, Object?>? _selectedConversation;
  List<Map<String, Object?>> _messages = const [];
  bool _loadingMessages = false;
  final TextEditingController _replyController = TextEditingController();

  // Availability Settings
  final TextEditingController _startCtrl = TextEditingController(text: '09:00');
  final TextEditingController _endCtrl = TextEditingController(text: '16:30');
  final TextEditingController _autoReplyCtrl = TextEditingController(
    text:
        'Thank you for reaching out. I am currently outside my teaching communication hours and will review your message when school resumes.',
  );
  bool _availabilityEnabled = true;
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon-Fri

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadAvailability();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _autoReplyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final list = await api.listChatConversations(session: session);
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadAvailability() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getTeacherAvailability(session: session);
      if (mounted) {
        setState(() {
          _startCtrl.text = data['startTime'] as String? ?? '09:00';
          _endCtrl.text = data['endTime'] as String? ?? '16:30';
          _autoReplyCtrl.text = (data['autoReplyMessage'] as String?) ??
              _autoReplyCtrl.text;
          _availabilityEnabled = data['isEnabled'] as bool? ?? true;

          final daysStr = data['availableDays'] as String? ?? '1,2,3,4,5';
          _selectedDays.clear();
          for (final d in daysStr.split(',')) {
            final parsed = int.tryParse(d.trim());
            if (parsed != null) _selectedDays.add(parsed);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _selectConversation(Map<String, Object?> conv) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final convId = conv['id'] as String;
    setState(() {
      _selectedConversation = conv;
      _loadingMessages = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.listChatMessages(
        session: session,
        conversationId: convId,
      );

      final msgList = ((res['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, Object?>())
          .toList();

      if (mounted) {
        setState(() {
          _messages = msgList;
          _loadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversation messages: $e';
          _loadingMessages = false;
        });
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedConversation == null) return;

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final convId = _selectedConversation!['id'] as String;
    _replyController.clear();

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.sendChatMessage(
        session: session,
        conversationId: convId,
        content: text,
      );

      final newMsg = res['message'] as Map<String, Object?>?;
      if (newMsg != null && mounted) {
        setState(() {
          _messages = [..._messages, newMsg];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to send reply: $e');
      }
    }
  }

  Future<void> _saveAvailability() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final start = _startCtrl.text.trim();
    final end = _endCtrl.text.trim();
    final autoReply = _autoReplyCtrl.text.trim();
    final daysStr = (_selectedDays.toList()..sort()).join(',');

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.updateTeacherAvailability(
        session: session,
        startTime: start,
        endTime: end,
        availableDays: daysStr,
        autoReplyMessage: autoReply,
        isEnabled: _availabilityEnabled,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _success =
              'Availability hours and auto-reply policy saved successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to save availability: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Parent-Teacher Messaging & Hours',
          description:
              'In-app parent communication, working hours protection, and automated out-of-hours replies.',
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: () {
                _loadConversations();
                _loadAvailability();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: FeedbackBanner(
              message: _error!,
              tone: FeedbackTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
          ),
        if (_success != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: FeedbackBanner(
              message: _success!,
              tone: FeedbackTone.success,
              onDismiss: () => setState(() => _success = null),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              _buildTabItem(
                'Parent Messages (${_conversations.length})',
                0,
                Icons.chat_bubble_outline,
              ),
              _buildTabItem(
                'Availability & Auto-Reply',
                1,
                Icons.schedule_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: _tabIndex == 0
              ? _buildConversationsSection()
              : _buildAvailabilitySection(),
        ),
      ],
    );
  }

  Widget _buildTabItem(String label, int index, IconData icon) {
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        borderRadius: AppRadii.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.mainBackground : Colors.transparent,
            borderRadius: AppRadii.rMd,
            border: selected ? Border.all(color: AppColors.primaryBorder) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 0: Conversations & Messaging Split View
  // -------------------------------------------------------------
  Widget _buildConversationsSection() {
    if (_loading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_conversations.isEmpty) {
      return const EmptyStateView(
        title: 'No Parent Conversations Yet',
        description:
            'When parents initiate an inquiry from the portal, threads will appear here with moderated message history.',
      );
    }

    return Row(
      children: [
        // Conversation List
        SizedBox(
          width: 340,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.primaryBorder)),
            ),
            child: ListView.separated(
              itemCount: _conversations.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.primaryBorder),
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                final isSelected = _selectedConversation?['id'] == conv['id'];
                final studentName =
                    conv['studentName'] as String? ?? 'Student';
                final parentName = conv['parentName'] as String? ?? 'Parent';
                final subject = conv['subject'] as String? ?? 'Inquiry';

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppColors.secondaryBackground,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryText.withValues(alpha: 0.08),
                    child: Text(
                      studentName.isNotEmpty ? studentName[0] : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '$parentName: $subject',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  onTap: () => _selectConversation(conv),
                );
              },
            ),
          ),
        ),
        // Active Thread Viewer
        Expanded(
          child: _selectedConversation == null
              ? const Center(
                  child: Text(
                    'Select a parent conversation from the left to read and reply.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                )
              : _buildThreadViewer(),
        ),
      ],
    );
  }

  Widget _buildThreadViewer() {
    final conv = _selectedConversation!;
    final studentName = conv['studentName'] as String? ?? 'Student';
    final parentName = conv['parentName'] as String? ?? 'Parent';
    final subject = conv['subject'] as String? ?? 'Conversation';

    return Column(
      children: [
        // Thread Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student: $studentName | Parent: $parentName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const StatusBadge(
                label: 'MODERATED',
                tone: BadgeTone.neutral,
              ),
            ],
          ),
        ),
        // Message Bubbles
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isTeacher = msg['senderRole'] == 'teacher';
                    final isAutoReply = msg['isAutoReply'] == true;
                    final content = msg['content'] as String? ?? '';
                    final createdAt = msg['createdAt'] as String?;
                    final timeStr = createdAt != null
                        ? DateFormat('hh:mm a').format(
                            DateTime.tryParse(createdAt) ?? DateTime.now(),
                          )
                        : '';

                    return Align(
                      alignment: isTeacher
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          color: isAutoReply
                              ? Colors.amber.shade50
                              : isTeacher
                                  ? AppColors.primaryText
                                  : AppColors.secondaryBackground,
                          borderRadius: AppRadii.rMd,
                          border: Border.all(
                            color: isAutoReply
                                ? Colors.amber.shade300
                                : AppColors.primaryBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isTeacher
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (isAutoReply)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '🤖 Automated Out-of-Hours Reply',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            Text(
                              content,
                              style: TextStyle(
                                fontSize: 13,
                                color: isTeacher && !isAutoReply
                                    ? Colors.white
                                    : AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isTeacher && !isAutoReply
                                    ? Colors.white70
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Reply Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            border: Border(top: BorderSide(color: AppColors.primaryBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message to the parent...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendReply(),
                ),
              ),
              IconButton(
                onPressed: _sendReply,
                icon: const Icon(Icons.send_rounded, color: AppColors.primaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Availability & Working Hours
  // -------------------------------------------------------------
  Widget _buildAvailabilitySection() {
    const daysMap = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Working Hours Protection & Auto-Reply',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'When enabled, parents sending messages outside these hours receive an automatic polite reply.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _availabilityEnabled,
                    onChanged: (val) =>
                        setState(() => _availabilityEnabled = val),
                  ),
                ],
              ),
              const Divider(height: 32, color: AppColors.primaryBorder),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Daily Start Time (24h)',
                        hintText: '09:00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Daily End Time (24h)',
                        hintText: '16:30',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Available Days of the Week:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in daysMap.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _selectedDays.contains(entry.key),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(entry.key);
                          } else {
                            _selectedDays.remove(entry.key);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _autoReplyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Automated Out-of-Hours Reply Message',
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _saveAvailability,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Availability Policy'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

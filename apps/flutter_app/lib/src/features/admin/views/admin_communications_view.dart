import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminCommunicationsView extends ConsumerStatefulWidget {
  const AdminCommunicationsView({
    required this.years,
    required this.classes,
    required this.sections,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final Future<void> Function() reload;

  @override
  ConsumerState<AdminCommunicationsView> createState() =>
      _AdminCommunicationsViewState();
}

class _AdminCommunicationsViewState
    extends ConsumerState<AdminCommunicationsView> {
  int _tabIndex = 0; // 0 = Bulk Import & Setup, 1 = Notifications & Audit
  bool _loading = false;
  String? _error;
  String? _success;

  // Onboarding
  Map<String, Object?>? _onboardingStatus;

  // Bulk Import
  String _selectedEntity = 'students';
  final TextEditingController _csvController = TextEditingController();
  Map<String, Object?>? _previewResult;
  bool _previewing = false;
  bool _committing = false;

  // Notifications
  List<Map<String, Object?>> _notifications = const [];
  String _channelFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final status = await api.getOnboardingStatus(session: session);
      final notes = await api.listNotifications(
        session: session,
        channel: _channelFilter == 'all' ? null : _channelFilter,
      );

      if (mounted) {
        setState(() {
          _onboardingStatus = status;
          _notifications = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load communications data: $e';
          _loading = false;
        });
      }
    }
  }

  void _setTemplate(String entity) {
    setState(() {
      _selectedEntity = entity;
      _previewResult = null;
      if (entity == 'students') {
        _csvController.text =
            'Name, Roll Number, Gender, Parent Name, Parent Phone, Parent Email, Class, Section\n'
            'Aarav Sharma, 101, male, Rajesh Sharma, 9876543210, rajesh@example.com, Grade 10, A\n'
            'Diya Patel, 102, female, Sunita Patel, 9876543211, sunita@example.com, Grade 10, A';
      } else if (entity == 'staff') {
        _csvController.text =
            'Full Name, Email, Phone, Employee ID, Role\n'
            'Priya Sen, priya.sen@school.edu, 9876543210, EMP-001, teacher\n'
            'Amit Verma, amit.verma@school.edu, 9876543211, EMP-002, admin';
      } else {
        _csvController.text =
            'Class, Section, Grade Order\n'
            'Grade 9, Section A, 9\n'
            'Grade 9, Section B, 9\n'
            'Grade 10, Section A, 10';
      }
    });
  }

  Future<void> _previewCsv() async {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter or paste CSV content first.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _previewing = true;
      _error = null;
      _success = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.previewBulkImport(
        session: session,
        entity: _selectedEntity,
        csv: text,
      );

      if (mounted) {
        setState(() {
          _previewResult = res;
          _previewing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Preview failed: $e';
          _previewing = false;
        });
      }
    }
  }

  Future<void> _commitImport() async {
    final preview = _previewResult;
    if (preview == null) return;

    final validRows = (preview['validRows'] as List?) ?? const [];
    if (validRows.isEmpty) {
      setState(() => _error = 'No valid rows found to import.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _committing = true;
      _error = null;
      _success = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final records = validRows
          .whereType<Map>()
          .map((r) => (r['data'] as Map).cast<String, Object?>())
          .toList();

      final res = await api.commitBulkImport(
        session: session,
        entity: _selectedEntity,
        records: records,
        academicYearId: widget.years.isNotEmpty
            ? widget.years.first['id'] as String?
            : null,
      );

      await widget.reload();
      await _loadAll();

      if (mounted) {
        setState(() {
          _committing = false;
          _previewResult = null;
          _csvController.clear();
          _success =
              'Import completed successfully! Total processed: ${res['totalProcessed'] ?? records.length} records.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Import commit failed: $e';
          _committing = false;
        });
      }
    }
  }

  Future<void> _triggerFeeReminders() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.triggerFeeReminders(session: session, days: 7);
      await _loadAll();

      if (mounted) {
        setState(() {
          _loading = false;
          _success =
              'Dispatched ${res['dispatchedCount'] ?? 0} fee reminders out of ${res['totalPending'] ?? 0} pending fees via WhatsApp/SMS.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to trigger fee reminders: $e';
          _loading = false;
        });
      }
    }
  }

  void _openBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String channel = 'in_app';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: 'Send Multi-Channel Notification',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Dispatch a priority announcement or notice across WhatsApp, SMS, Push, or In-App.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: channel,
                      decoration: const InputDecoration(labelText: 'Channel'),
                      items: const [
                        DropdownMenuItem(
                          value: 'in_app',
                          child: Text('In-App Notification'),
                        ),
                        DropdownMenuItem(
                          value: 'whatsapp',
                          child: Text('WhatsApp Message'),
                        ),
                        DropdownMenuItem(
                          value: 'sms',
                          child: Text('SMS Text Message'),
                        ),
                        DropdownMenuItem(
                          value: 'push',
                          child: Text('Mobile Push Alert'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => channel = v ?? 'in_app'),
                    ),
                    const SizedBox(height: 12),
                    if (channel == 'sms' || channel == 'whatsapp') ...[
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Recipient Phone Number',
                          hintText: '+919876543210 (Leave blank for broadcast)',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notification Title',
                        hintText: 'e.g. Annual Sports Day Schedule',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message Body',
                        hintText: 'Enter announcement details...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            final body = bodyCtrl.text.trim();
                            if (title.isEmpty || body.isEmpty) return;

                            Navigator.of(dialogCtx).pop();
                            final session =
                                ref.read(authControllerProvider).session;
                            if (session == null) return;

                            setState(() => _loading = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.sendNotification(
                                session: session,
                                channel: channel,
                                title: title,
                                body: body,
                                recipientPhone: phoneCtrl.text.trim().isNotEmpty
                                    ? phoneCtrl.text.trim()
                                    : null,
                              );
                              await _loadAll();
                              if (mounted) {
                                setState(() {
                                  _loading = false;
                                  _success =
                                      'Notification dispatched successfully across $channel!';
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _loading = false;
                                  _error = 'Failed to dispatch: $e';
                                });
                              }
                            }
                          },
                          child: const Text('Dispatch Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openOnboardingWizardDialog() {
    final schoolNameCtrl = TextEditingController(
      text: (_onboardingStatus?['school'] as Map?)?['name'] as String? ??
          'My School',
    );
    final yearNameCtrl = TextEditingController(text: 'Academic Year 2026-27');
    final startCtrl = TextEditingController(text: '2026-04-01');
    final endCtrl = TextEditingController(text: '2027-03-31');
    final classesCtrl = TextEditingController(
      text: 'Grade 9: A, B\nGrade 10: A, B\nGrade 11: Science, Commerce',
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AppDialog(
          title: 'Institutional Onboarding Setup Wizard',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configure the school foundation: academic year, initial classes, and sections in one step.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: schoolNameCtrl,
                  decoration: const InputDecoration(labelText: 'School Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearNameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Academic Year Title'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Starts On (YYYY-MM-DD)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ends On (YYYY-MM-DD)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Classes & Sections (One per line: Class: A, B)',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final sName = schoolNameCtrl.text.trim();
                        final yName = yearNameCtrl.text.trim();
                        final start = startCtrl.text.trim();
                        final end = endCtrl.text.trim();

                        final parsedClasses = <Map<String, Object?>>[];
                        for (final line in classesCtrl.text.split('\n')) {
                          final trimmed = line.trim();
                          if (!trimmed.contains(':')) continue;
                          final parts = trimmed.split(':');
                          final cName = parts[0].trim();
                          final sNames = parts[1]
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (cName.isNotEmpty && sNames.isNotEmpty) {
                            parsedClasses.add({
                              'name': cName,
                              'sections': sNames,
                            });
                          }
                        }

                        if (sName.isEmpty ||
                            yName.isEmpty ||
                            parsedClasses.isEmpty) {
                          return;
                        }

                        Navigator.of(dialogCtx).pop();
                        final session =
                            ref.read(authControllerProvider).session;
                        if (session == null) return;

                        setState(() => _loading = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.runOnboardingWizard(
                            session: session,
                            schoolName: sName,
                            academicYearName: yName,
                            startDate: start,
                            endDate: end,
                            classes: parsedClasses,
                          );
                          await widget.reload();
                          await _loadAll();

                          if (mounted) {
                            setState(() {
                              _loading = false;
                              _success =
                                  'Setup wizard successfully provisioned the academic year and class structure!';
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _loading = false;
                              _error = 'Wizard failed: $e';
                            });
                          }
                        }
                      },
                      child: const Text('Provision School'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Communications & Onboarding',
          description:
              'Bulk CSV import engine, setup wizard, automated fee reminders, absence alerts, and multi-channel audit logs.',
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: _openOnboardingWizardDialog,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Setup Wizard'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _openBroadcastDialog,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send Broadcast'),
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
              _buildTabButton('Bulk Importer & Setup', 0, Icons.upload_file),
              _buildTabButton(
                  'Automated Notifications & Audit', 1, Icons.notifications_active),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _tabIndex == 0
                  ? _buildBulkImportTab()
                  : _buildNotificationsTab(),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
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
  // TAB 0: Bulk Import & Onboarding Wizard
  // -------------------------------------------------------------
  Widget _buildBulkImportTab() {
    final status = _onboardingStatus;
    final isCompleted = status?['isCompleted'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        // Onboarding Status Strip
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color: isCompleted
                  ? AppColors.statusSuccess
                  : AppColors.statusWarning,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.pending_actions,
                color: isCompleted ? AppColors.statusSuccess : AppColors.statusWarning,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted
                          ? 'Institution Onboarding Complete'
                          : 'First-Run Setup Recommended',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'School: ${(status?['school'] as Map?)?['name'] ?? 'Schoolic'} | '
                      'Academic Year: ${status?['hasAcademicYear'] == true ? 'Active' : 'Missing'} | '
                      'Classes: ${status?['classCount'] ?? 0} | '
                      'Staff: ${status?['staffCount'] ?? 0} | '
                      'Students: ${status?['studentCount'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _openOnboardingWizardDialog,
                child: const Text('Re-run Wizard'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Entity Selector
        Row(
          children: [
            const Text(
              'Select Import Target:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Students & Guardians'),
              selected: _selectedEntity == 'students',
              onSelected: (_) => _setTemplate('students'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Staff & Teachers'),
              selected: _selectedEntity == 'staff',
              onSelected: (_) => _setTemplate('staff'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Classes & Sections'),
              selected: _selectedEntity == 'classes_sections',
              onSelected: (_) => _setTemplate('classes_sections'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // CSV Editor Box
        Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CSV Data (Comma, Semicolon, or Tab Separated)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: () => _setTemplate(_selectedEntity),
                    icon: const Icon(Icons.file_copy_outlined, size: 16),
                    label: const Text('Load Sample Template'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _csvController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Paste CSV text or edit headers here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _previewing ? null : _previewCsv,
                    icon: _previewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Validate & Preview Rows'),
                  ),
                  if (_previewResult != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _committing ? null : _commitImport,
                      icon: _committing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(
                        'Commit Import (${_previewResult?['validCount'] ?? 0} valid)',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Preview Stats
        if (_previewResult != null) ...[
          StatStrip(
            items: [
              StatItemData(
                label: 'Total Rows',
                value: '${_previewResult?['totalRows'] ?? 0}',
              ),
              StatItemData(
                label: 'Valid Rows',
                value: '${_previewResult?['validCount'] ?? 0}',
              ),
              StatItemData(
                label: 'Invalid / Errors',
                value: '${_previewResult?['invalidCount'] ?? 0}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ((_previewResult?['invalidRows'] as List?)?.isNotEmpty ?? false) ...[
            const Text(
              'Validation Errors to Fix Before Commit:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.statusError,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.08),
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.statusError.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in (_previewResult?['invalidRows'] as List).take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Row ${row['rowNumber']}: ${((row['errors'] as List?) ?? []).join(', ')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.statusError,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Automated Notifications & Audit Logs
  // -------------------------------------------------------------
  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        // Quick Action Triggers Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Automated Communication Triggers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Instantly dispatch multi-channel alerts to parents with automated Indian phone formatting and template assembly.',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _triggerFeeReminders,
                    icon: const Icon(Icons.currency_rupee, size: 18),
                    label: const Text('Trigger Fee Reminders (WhatsApp/SMS)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openBroadcastDialog,
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Custom Broadcast Notice'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Channel Filters
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notification Audit Trail',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                const Text('Channel: ', style: TextStyle(fontSize: 13)),
                DropdownButton<String>(
                  value: _channelFilter,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Channels')),
                    DropdownMenuItem(
                        value: 'whatsapp', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'sms', child: Text('SMS')),
                    DropdownMenuItem(value: 'in_app', child: Text('In-App')),
                    DropdownMenuItem(value: 'push', child: Text('Push Alert')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _channelFilter = v);
                      _loadAll();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Notifications List
        if (_notifications.isEmpty)
          const EmptyStateView(
            title: 'No Notifications Dispatched Yet',
            description:
                'Use the automated triggers above to send absence alerts or fee reminders.',
          )
        else
          for (final note in _notifications) _buildNotificationCard(note),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, Object?> note) {
    final channel = note['channel'] as String? ?? 'in_app';
    final status = note['status'] as String? ?? 'delivered';
    final title = note['title'] as String? ?? 'Untitled Notification';
    final body = note['body'] as String? ?? '';
    final createdAt = note['createdAt'] as String?;
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.tryParse(createdAt) ?? DateTime.now())
        : 'Just now';

    IconData icon;
    Color iconColor;
    switch (channel) {
      case 'whatsapp':
        icon = Icons.chat_bubble_outline;
        iconColor = Colors.green;
        break;
      case 'sms':
        icon = Icons.sms_outlined;
        iconColor = Colors.blue;
        break;
      case 'push':
        icon = Icons.notifications_none;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.inbox_outlined;
        iconColor = Colors.amber.shade800;
        break;
    }

    final isSuccess = status == 'delivered' || status == 'sent';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusBadge(
                      label: channel.toUpperCase(),
                      tone: BadgeTone.neutral,
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: status.toUpperCase(),
                      tone: isSuccess ? BadgeTone.success : BadgeTone.error,
                    ),
                    if (note['recipientPhone'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'To: ${note['recipientPhone']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

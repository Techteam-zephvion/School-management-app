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

class AdminComplianceView extends ConsumerStatefulWidget {
  const AdminComplianceView({
    required this.students,
    super.key,
  });

  final List<Map<String, Object?>> students;

  @override
  ConsumerState<AdminComplianceView> createState() =>
      _AdminComplianceViewState();
}

class _AdminComplianceViewState extends ConsumerState<AdminComplianceView> {
  int _tabIndex = 0; // 0 = DPDP Consents, 1 = DSR Requests, 2 = Audit Logs
  bool _loading = false;
  String? _error;
  String? _success;

  List<Map<String, Object?>> _consents = [];
  List<Map<String, Object?>> _dsrRequests = [];
  List<Map<String, Object?>> _auditLogs = [];

  String? _consentFilterStatus;
  String? _dsrFilterStatus;
  String? _auditFilterAction;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
      final results = await Future.wait([
        api.listDpdpConsents(
          session: session,
          status: _consentFilterStatus,
        ),
        api.listDsrRequests(
          session: session,
          status: _dsrFilterStatus,
        ),
        api.listAuditLogs(
          session: session,
          action: _auditFilterAction,
          limit: 100,
        ),
      ]);

      if (mounted) {
        setState(() {
          _consents = results[0];
          _dsrRequests = results[1];
          _auditLogs = results[2];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load compliance records: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openRecordConsentDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    String? selectedStudentId =
        widget.students.isNotEmpty ? widget.students.first['id'] as String? : null;
    final parentNameController = TextEditingController();
    final parentPhoneController = TextEditingController();
    String consentType = 'enrollment_data_processing';
    String verifiedVia = 'portal_submission';

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Record Parental Consent (DPDP 2023)',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedStudentId == null ||
                    parentNameController.text.trim().isEmpty ||
                    parentPhoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                Navigator.of(dialogCtx).pop();
                try {
                  final api = ref.read(apiClientProvider);
                  await api.recordDpdpConsent(
                    session: session,
                    studentId: selectedStudentId!,
                    parentGuardianName: parentNameController.text.trim(),
                    parentGuardianPhone: parentPhoneController.text.trim(),
                    consentType: consentType,
                    verifiedVia: verifiedVia,
                  );
                  setState(() => _success = 'Parental consent captured and audited.');
                  _loadAll();
                } catch (e) {
                  setState(() => _error = 'Failed to record consent: $e');
                }
              },
              child: const Text('Record Consent'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capture verifiable consent from parent or legal guardian for minor data processing.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                decoration: const InputDecoration(labelText: 'Select Student *'),
                items: widget.students
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String?,
                        child: Text(
                            '${s['fullName']} (${s['admissionNumber'] ?? s['rollNumber'] ?? ''})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedStudentId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: parentNameController,
                decoration: const InputDecoration(labelText: 'Parent / Guardian Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: parentPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Guardian Phone Number *',
                  hintText: '+919876543210',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: consentType,
                decoration: const InputDecoration(labelText: 'Consent Scope / Type *'),
                items: const [
                  DropdownMenuItem(
                    value: 'enrollment_data_processing',
                    child: Text('Academic & Institutional Enrollment'),
                  ),
                  DropdownMenuItem(
                    value: 'biometric_attendance',
                    child: Text('Biometric / RFID Attendance Verification'),
                  ),
                  DropdownMenuItem(
                    value: 'media_publication',
                    child: Text('School Website & Newsletter Photos'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => consentType = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: verifiedVia,
                decoration: const InputDecoration(labelText: 'Verification Method *'),
                items: const [
                  DropdownMenuItem(
                    value: 'portal_submission',
                    child: Text('Parent Portal Digital Consent'),
                  ),
                  DropdownMenuItem(
                    value: 'signed_form',
                    child: Text('Physical Signed Admission Form'),
                  ),
                  DropdownMenuItem(
                    value: 'sms_otp',
                    child: Text('Mobile OTP Verification'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => verifiedVia = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openResolveDsrDialog(Map<String, Object?> request) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final id = request['id'] as String;
    final requestType = request['requestType'] as String? ?? 'data_access';
    final notesController = TextEditingController();
    String status = 'fulfilled';
    bool anonymizeStudent = requestType == 'data_erasure_anonymization';

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Resolve Data Subject Request',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter resolution notes')),
                  );
                  return;
                }

                Navigator.of(dialogCtx).pop();
                try {
                  final api = ref.read(apiClientProvider);
                  await api.resolveDsrRequest(
                    session: session,
                    requestId: id,
                    status: status,
                    resolutionNotes: notesController.text.trim(),
                    anonymizeStudent: anonymizeStudent,
                  );
                  setState(() => _success = 'DSR Request resolved successfully.');
                  _loadAll();
                } catch (e) {
                  setState(() => _error = 'Failed to resolve request: $e');
                }
              },
              child: const Text('Complete Resolution'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request ID: $id\nType: $requestType',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Reason: ${request['reason'] ?? 'Not specified'}',
                style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Resolution Status *'),
                items: const [
                  DropdownMenuItem(value: 'fulfilled', child: Text('Fulfilled / Granted')),
                  DropdownMenuItem(value: 'in_review', child: Text('Under Legal Review')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected / Board Exception')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Resolution Notes / Documentation *',
                  hintText: 'Describe actions taken to fulfill or reasons for rejection.',
                ),
              ),
              if (requestType == 'data_erasure_anonymization') ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Anonymize Student PII Record'),
                  subtitle: const Text(
                      'Redacts name, guardian phone, and contact while keeping academic aggregate statistics for regulatory compliance.'),
                  value: anonymizeStudent,
                  onChanged: (val) =>
                      setDialogState(() => anonymizeStudent = val ?? false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grantedConsents =
        _consents.where((c) => c['status'] == 'granted').length;
    final pendingDsr =
        _dsrRequests.where((r) => r['status'] == 'pending').length;

    return Column(
      children: [
        PageHeader(
          title: 'DPDP 2023 Compliance & Audit Logs',
          description:
              'Indian Digital Personal Data Protection Act compliance, verifiable parental consent capture, Data Subject Rights (DSR) resolution, and immutable operational audit trail.',
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _openRecordConsentDialog,
              icon: const Icon(Icons.security, size: 18),
              label: const Text('Record Consent'),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: StatStrip(
            items: [
              StatItemData(
                label: 'Valid Consents',
                value: '$grantedConsents / ${_consents.length}',
                helper: 'DPDP Active',
              ),
              StatItemData(
                label: 'Pending DSR Requests',
                value: '$pendingDsr',
                helper: pendingDsr > 0 ? 'Action Required' : 'All Settled',
              ),
              StatItemData(
                label: 'Audited Operations',
                value: '${_auditLogs.length}',
                helper: 'Immutable Trail',
              ),
            ],
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
              _buildTabItem('Parental Consents (${_consents.length})', 0, Icons.verified_user),
              _buildTabItem('Data Subject Rights (${_dsrRequests.length})', 1, Icons.privacy_tip),
              _buildTabItem('Audit Log Trail (${_auditLogs.length})', 2, Icons.history),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _tabIndex == 0
                  ? _buildConsentsTab()
                  : _tabIndex == 1
                      ? _buildDsrTab()
                      : _buildAuditTab(),
        ),
      ],
    );
  }

  Widget _buildTabItem(String label, int index, IconData icon) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        borderRadius: AppRadii.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainBackground : Colors.transparent,
            borderRadius: AppRadii.rMd,
            border: isSelected
                ? Border.all(color: AppColors.primaryText.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentsTab() {
    if (_consents.isEmpty) {
      return const EmptyStateView(
        title: 'No parental consents recorded yet',
        description: 'Capture verifiable DPDP 2023 parental consent using the button above.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _consents.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.primaryBorder),
      itemBuilder: (context, index) {
        final c = _consents[index];
        final studentName = c['studentName'] as String? ?? 'Student';
        final parentName = c['parentGuardianName'] as String? ?? 'Guardian';
        final phone = c['parentGuardianPhone'] as String? ?? '';
        final scope = c['consentType'] as String? ?? '';
        final status = c['status'] as String? ?? 'granted';
        final verifiedVia = c['verifiedVia'] as String? ?? 'portal_submission';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          title: Text(
            '$studentName — Guardian: $parentName ($phone)',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Scope: $scope • Verified via: $verifiedVia',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          trailing: StatusBadge(
            label: status.toUpperCase(),
            tone: status == 'granted' ? BadgeTone.success : BadgeTone.neutral,
          ),
        );
      },
    );
  }

  Widget _buildDsrTab() {
    if (_dsrRequests.isEmpty) {
      return const EmptyStateView(
        title: 'No Data Subject Rights requests',
        description: 'Requests submitted by parents or students for access or erasure will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _dsrRequests.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.primaryBorder),
      itemBuilder: (context, index) {
        final r = _dsrRequests[index];
        final studentName = r['studentName'] as String? ?? 'General Account';
        final requestType = r['requestType'] as String? ?? '';
        final status = r['status'] as String? ?? 'pending';
        final reason = r['reason'] as String? ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          title: Text(
            '$studentName — Request: $requestType',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Reason: $reason',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(
                label: status.toUpperCase(),
                tone: status == 'fulfilled'
                    ? BadgeTone.success
                    : status == 'pending'
                        ? BadgeTone.warning
                        : BadgeTone.neutral,
              ),
              const SizedBox(width: 8),
              if (status == 'pending' || status == 'in_review')
                OutlinedButton(
                  onPressed: () => _openResolveDsrDialog(r),
                  child: const Text('Resolve'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditTab() {
    if (_auditLogs.isEmpty) {
      return const EmptyStateView(
        title: 'No audit log entries recorded',
        description: 'Operations affecting student and financial records are automatically tracked here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _auditLogs.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.primaryBorder),
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = log['action'] as String? ?? 'action';
        final resource = log['resourceType'] as String? ?? 'record';
        final userEmail = log['userEmail'] as String? ?? 'system';
        final role = log['userRole'] as String? ?? 'admin';
        final createdAtStr = log['createdAt'] as String?;
        String formattedDate = '';
        if (createdAtStr != null) {
          try {
            formattedDate =
                DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(createdAtStr));
          } catch (_) {
            formattedDate = createdAtStr;
          }
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          title: Text(
            '$action on $resource',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            'Actor: $userEmail ($role) • $formattedDate',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          trailing: const Icon(Icons.shield_outlined, size: 18, color: AppColors.statusInfo),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminAdmissionsView extends ConsumerStatefulWidget {
  const AdminAdmissionsView({
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
  ConsumerState<AdminAdmissionsView> createState() => _AdminAdmissionsViewState();
}

class _AdminAdmissionsViewState extends ConsumerState<AdminAdmissionsView> {
  String _activeTab = 'applications'; // 'applications', 'inquiries', 'capacity'
  bool _loading = true;
  String? _error;
  String? _notice;

  Map<String, Object?> _summary = const {};
  List<Map<String, Object?>> _applications = const [];

  String? _filterClassId;
  String _filterStatus = 'all';
  final _searchController = TextEditingController();

  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadAdmissionsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmissionsData() async {
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
      final api = ref.read(apiClientProvider);
      final summary = await api.getJson('/api/v1/admin/admissions/summary', session: session);
      final applications = await api.getList('/api/v1/admin/admissions/applications', session: session);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _applications = applications;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load admission applications.';
        _loading = false;
      });
    }
  }

  List<Map<String, Object?>> get _formalApplications {
    final query = _searchController.text.trim().toLowerCase();
    return _applications.where((a) {
      final status = (a['status'] as String? ?? 'applied');
      if (status == 'inquiry') return false;
      if (_filterClassId != null && a['applyingForClassId'] != _filterClassId) return false;
      if (_filterStatus != 'all' && status != _filterStatus) return false;
      if (query.isNotEmpty) {
        final name = (a['applicantName'] as String? ?? '').toLowerCase();
        final parent = (a['parentName'] as String? ?? '').toLowerCase();
        final phone = (a['parentPhone'] as String? ?? '').toLowerCase();
        final appNum = (a['applicationNumber'] as String? ?? '').toLowerCase();
        if (!name.contains(query) && !parent.contains(query) && !phone.contains(query) && !appNum.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, Object?>> get _inquiries {
    final query = _searchController.text.trim().toLowerCase();
    return _applications.where((a) {
      final status = (a['status'] as String? ?? '');
      if (status != 'inquiry') return false;
      if (_filterClassId != null && a['applyingForClassId'] != _filterClassId) return false;
      if (query.isNotEmpty) {
        final name = (a['applicantName'] as String? ?? '').toLowerCase();
        final parent = (a['parentName'] as String? ?? '').toLowerCase();
        final phone = (a['parentPhone'] as String? ?? '').toLowerCase();
        if (!name.contains(query) && !parent.contains(query) && !phone.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Map<String, Object?>> get _classBreakdown {
    final raw = _summary['classBreakdown'] as List<dynamic>? ?? const [];
    return raw.cast<Map<String, Object?>>();
  }

  BadgeTone _statusTone(String status) {
    switch (status) {
      case 'inquiry':
        return BadgeTone.neutral;
      case 'applied':
        return BadgeTone.info;
      case 'under_review':
        return BadgeTone.warning;
      case 'approved':
      case 'enrolled':
        return BadgeTone.success;
      case 'rejected':
        return BadgeTone.error;
      default:
        return BadgeTone.neutral;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'inquiry':
        return 'Inquiry';
      case 'applied':
        return 'Applied';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'enrolled':
        return 'Enrolled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Admissions & Operations',
          description: 'Manage admissions pipeline, review documents, track class intake capacity, and enroll applicants.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _openNewApplicationDialog,
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('New Application'),
          ),
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _openNewApplicationDialog(defaultAsInquiry: true),
              icon: const Icon(Icons.contact_mail_outlined, size: 16),
              label: const Text('Add Inquiry'),
            ),
          ],
        ),
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
        const SizedBox(height: 16),
        _buildStatStrip(),
        const SizedBox(height: 16),
        _buildSubNav(),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_activeTab == 'applications')
          _buildApplicationsTab()
        else if (_activeTab == 'inquiries')
          _buildInquiriesTab()
        else
          _buildCapacityTab(),
      ],
    );
  }

  Widget _buildStatStrip() {
    final byStatus = _summary['byStatus'] as Map<String, dynamic>? ?? const {};
    final total = (_summary['totalApplications'] as num?)?.toInt() ?? 0;
    final underReview = (byStatus['under_review'] as num?)?.toInt() ?? 0;
    final approved = (byStatus['approved'] as num?)?.toInt() ?? 0;
    final enrolled = (byStatus['enrolled'] as num?)?.toInt() ?? 0;

    return StatStrip(
      items: [
        StatItemData(
          label: 'Total Pipeline',
          value: total.toString(),
          helper: 'All inquiries & applicants',
        ),
        StatItemData(
          label: 'Under Review',
          value: underReview.toString(),
          helper: 'Pending verification',
        ),
        StatItemData(
          label: 'Approved for Intake',
          value: approved.toString(),
          helper: 'Ready for enrollment',
        ),
        StatItemData(
          label: 'Successfully Enrolled',
          value: enrolled.toString(),
          helper: 'Active student profiles created',
        ),
      ],
    );
  }

  Widget _buildSubNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _navTab('applications', 'Applications Pipeline (${_formalApplications.length})'),
            const SizedBox(width: 24),
            _navTab('inquiries', 'Inquiries & Leads (${_inquiries.length})'),
            const SizedBox(width: 24),
            _navTab('capacity', 'Class Capacity & Seats (${_classBreakdown.length})'),
          ],
        ),
      ),
    );
  }

  Widget _navTab(String tab, String label) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primaryText : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.primaryText : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationsTab() {
    final items = _formalApplications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        const SizedBox(height: 16),
        if (items.isEmpty)
          EmptyStateView(
            title: 'No applications found',
            description: 'No admission applications match your current search or filter criteria.',
            actionLabel: 'New Application',
            onAction: _openNewApplicationDialog,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildApplicationCard(items[index]),
          ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search applicant, parent, phone...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        DropdownButton<String?>(
          value: _filterClassId,
          hint: const Text('All Classes'),
          underline: const SizedBox(),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Classes'),
            ),
            ...widget.classes.map(
              (c) => DropdownMenuItem<String?>(
                value: c['id'] as String?,
                child: Text(c['name'] as String? ?? 'Class'),
              ),
            ),
          ],
          onChanged: (val) => setState(() => _filterClassId = val),
        ),
        DropdownButton<String>(
          value: _filterStatus,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
            DropdownMenuItem(value: 'applied', child: Text('Applied')),
            DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'enrolled', child: Text('Enrolled')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _filterStatus = val);
          },
        ),
      ],
    );
  }

  Widget _buildApplicationCard(Map<String, Object?> app) {
    final id = app['id'] as String? ?? '';
    final appNumber = app['applicationNumber'] as String? ?? '';
    final name = app['applicantName'] as String? ?? '';
    final className = app['className'] as String? ?? '';
    final parent = app['parentName'] as String? ?? '';
    final phone = app['parentPhone'] as String? ?? '';
    final email = app['parentEmail'] as String?;
    final status = app['status'] as String? ?? 'applied';
    final rawDate = app['applicationDate'] as String?;
    final dateStr = rawDate != null ? _formatDate(rawDate) : 'Recently';
    final totalDocs = (app['totalDocuments'] as num?)?.toInt() ?? 0;
    final verifiedDocs = (app['verifiedDocuments'] as num?)?.toInt() ?? 0;
    final enrolledNumber = app['enrolledStudentAdmissionNumber'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rMd,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          appNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: _formatStatus(status),
                          tone: _statusTone(status),
                        ),
                        if (enrolledNumber != null) ...[
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: 'ID: $enrolledNumber',
                            tone: BadgeTone.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Applying for $className • Applied on $dateStr',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: AppRadii.rSm,
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Text(
                      '$verifiedDocs / $totalDocs Docs Verified',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.primaryBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent/Guardian: $parent',
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: $phone${email != null ? ' • Email: $email' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openApplicationDetailDialog(id),
                    icon: const Icon(Icons.assignment_turned_in_outlined, size: 14),
                    label: const Text('Review & Docs'),
                  ),
                  if (status == 'approved')
                    FilledButton.icon(
                      onPressed: () => _openEnrollDialog(app),
                      icon: const Icon(Icons.how_to_reg_outlined, size: 14),
                      label: const Text('Enroll Student'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInquiriesTab() {
    final items = _inquiries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        const SizedBox(height: 16),
        if (items.isEmpty)
          EmptyStateView(
            title: 'No inquiries recorded',
            description: 'Track prospective student inquiries, admissions inquiries, and visit leads here.',
            actionLabel: 'Add Inquiry',
            onAction: () => _openNewApplicationDialog(defaultAsInquiry: true),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inq = items[index];
              final id = inq['id'] as String? ?? '';
              final name = inq['applicantName'] as String? ?? '';
              final className = inq['className'] as String? ?? '';
              final parent = inq['parentName'] as String? ?? '';
              final phone = inq['parentPhone'] as String? ?? '';
              final previousSchool = inq['previousSchool'] as String?;
              final notes = inq['notes'] as String?;
              final dateStr = inq['applicationDate'] != null ? _formatDate(inq['applicationDate'] as String) : '';

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  border: Border.all(color: AppColors.primaryBorder),
                  borderRadius: AppRadii.rMd,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const StatusBadge(label: 'Inquiry Lead', tone: BadgeTone.neutral),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target Class: $className • Contact: $parent ($phone) • Date: $dateStr',
                            style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                          ),
                          if (previousSchool != null && previousSchool.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Previous School: $previousSchool',
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                            ),
                          ],
                          if (notes != null && notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notes: $notes',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.primaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _convertInquiryToApplication(id),
                      icon: const Icon(Icons.arrow_forward_outlined, size: 14),
                      label: const Text('Convert to Formal Application'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCapacityTab() {
    final breakdown = _classBreakdown;

    if (breakdown.isEmpty) {
      return const EmptyStateView(
        title: 'No classes configured',
        description: 'Set up classes and sections in Schoolic to calculate intake capacity.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.secondaryText),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Standard nominal intake capacity is calculated per grade level. Track available vacancies against current enrolled students and pipeline applicants.',
                  style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: breakdown.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final row = breakdown[index];
            final name = row['className'] as String? ?? 'Class';
            final capacity = (row['capacity'] as num?)?.toInt() ?? 40;
            final enrolled = (row['enrolledCount'] as num?)?.toInt() ?? 0;
            final available = (row['availableSeats'] as num?)?.toInt() ?? (capacity - enrolled);
            final applicationsCount = (row['applicationsCount'] as num?)?.toInt() ?? 0;
            final pendingCount = (row['pendingCount'] as num?)?.toInt() ?? 0;
            final approvedCount = (row['approvedCount'] as num?)?.toInt() ?? 0;

            final occupancy = capacity > 0 ? (enrolled / capacity).clamp(0.0, 1.0) : 0.0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mainBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        '$enrolled / $capacity Seats Filled ($available Vacancies)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: AppRadii.rSm,
                    child: LinearProgressIndicator(
                      value: occupancy,
                      minHeight: 8,
                      backgroundColor: AppColors.secondaryBackground,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryText),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Applications: $applicationsCount',
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                      Row(
                        children: [
                          Text(
                            'Pending: $pendingCount',
                            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Approved: $approvedCount',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusSuccess),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final parsed = DateTime.parse(iso);
      return _dateFormat.format(parsed);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _convertInquiryToApplication(String id) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.patchJson(
        '/api/v1/admin/admissions/applications/$id',
        {'status': 'applied'},
        session: session,
      );
      if (!mounted) return;
      setState(() => _notice = 'Inquiry successfully converted to formal application.');
      await _loadAdmissionsData();
      await widget.reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to update inquiry.');
    }
  }

  Future<void> _openNewApplicationDialog({bool defaultAsInquiry = false}) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _NewApplicationDialog(
        years: widget.years,
        classes: widget.classes,
        defaultAsInquiry: defaultAsInquiry,
      ),
    );

    if (created == true) {
      if (!mounted) return;
      setState(() => _notice = defaultAsInquiry ? 'Inquiry recorded.' : 'Application submitted.');
      await _loadAdmissionsData();
      await widget.reload();
    }
  }

  Future<void> _openApplicationDetailDialog(String id) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ApplicationDetailDialog(
        applicationId: id,
        classes: widget.classes,
        sections: widget.sections,
      ),
    );

    if (changed == true) {
      await _loadAdmissionsData();
      await widget.reload();
    }
  }

  Future<void> _openEnrollDialog(Map<String, Object?> app) async {
    final enrolled = await showDialog<bool>(
      context: context,
      builder: (context) => _EnrollApplicantDialog(
        application: app,
        sections: widget.sections,
      ),
    );

    if (enrolled == true) {
      if (!mounted) return;
      setState(() => _notice = 'Applicant successfully enrolled as active student.');
      await _loadAdmissionsData();
      await widget.reload();
    }
  }
}

class _NewApplicationDialog extends ConsumerStatefulWidget {
  const _NewApplicationDialog({
    required this.years,
    required this.classes,
    required this.defaultAsInquiry,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final bool defaultAsInquiry;

  @override
  ConsumerState<_NewApplicationDialog> createState() => _NewApplicationDialogState();
}

class _NewApplicationDialogState extends ConsumerState<_NewApplicationDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _academicYearId;
  String? _classId;
  final _nameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _previousSchoolController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _gender = 'male';
  DateTime? _dob;
  late String _status;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.defaultAsInquiry ? 'inquiry' : 'applied';
    if (widget.years.isNotEmpty) {
      _academicYearId = widget.years.first['id'] as String?;
    }
    if (widget.classes.isNotEmpty) {
      _classId = widget.classes.first['id'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _previousSchoolController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_academicYearId == null || _classId == null) {
      setState(() => _error = 'Please select Academic Year and Target Class.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'academicYearId': _academicYearId,
        'applyingForClassId': _classId,
        'applicantName': _nameController.text.trim(),
        'parentName': _parentNameController.text.trim(),
        'parentPhone': _phoneController.text.trim(),
        if (_emailController.text.trim().isNotEmpty) 'parentEmail': _emailController.text.trim(),
        'gender': _gender,
        if (_dob != null) 'dateOfBirth': _dob!.toIso8601String().substring(0, 10),
        if (_previousSchoolController.text.trim().isNotEmpty) 'previousSchool': _previousSchoolController.text.trim(),
        if (_addressController.text.trim().isNotEmpty) 'address': _addressController.text.trim(),
        'status': _status,
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      };

      await api.postJson('/api/v1/admin/admissions/applications', payload, session: session);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to create application.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.defaultAsInquiry ? 'Record Admission Inquiry' : 'New Admission Application',
      subtitle: 'Capture student applicant details and contact information.',
      maxWidth: 540,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.defaultAsInquiry ? 'Save Inquiry' : 'Submit Application'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                FeedbackBanner(message: _error!, tone: FeedbackTone.error),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _academicYearId,
                      decoration: const InputDecoration(labelText: 'Academic Year *'),
                      items: widget.years.map((y) {
                        return DropdownMenuItem(
                          value: y['id'] as String?,
                          child: Text(y['name'] as String? ?? 'Year'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _academicYearId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _classId,
                      decoration: const InputDecoration(labelText: 'Applying For Class *'),
                      items: widget.classes.map((c) {
                        return DropdownMenuItem(
                          value: c['id'] as String?,
                          child: Text(c['name'] as String? ?? 'Class'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _classId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Applicant Full Name *'),
                validator: (val) => (val == null || val.trim().length < 2) ? 'Name must be at least 2 characters' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDob,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date of Birth'),
                        child: Text(
                          _dob != null ? DateFormat('dd MMM yyyy').format(_dob!) : 'Select Date',
                          style: TextStyle(
                            color: _dob != null ? AppColors.primaryText : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentNameController,
                decoration: const InputDecoration(labelText: 'Parent / Guardian Name *'),
                validator: (val) => (val == null || val.trim().length < 2) ? 'Parent name required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Primary Phone *'),
                      validator: (val) => (val == null || val.trim().length < 7) ? 'Valid phone required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email Address'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _previousSchoolController,
                decoration: const InputDecoration(labelText: 'Previous School / Kindergarten'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Residential Address'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Internal Admissions Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationDetailDialog extends ConsumerStatefulWidget {
  const _ApplicationDetailDialog({
    required this.applicationId,
    required this.classes,
    required this.sections,
  });

  final String applicationId;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;

  @override
  ConsumerState<_ApplicationDetailDialog> createState() => _ApplicationDetailDialogState();
}

class _ApplicationDetailDialogState extends ConsumerState<_ApplicationDetailDialog> {
  bool _loading = true;
  String? _error;
  String? _notice;
  Map<String, Object?>? _application;

  final _newDocTitleController = TextEditingController();
  final _newDocNumberController = TextEditingController();
  bool _addingDoc = false;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  @override
  void dispose() {
    _newDocTitleController.dispose();
    _newDocNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadApplication() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getJson('/api/v1/admin/admissions/applications/${widget.applicationId}', session: session);
      if (!mounted) return;
      setState(() {
        _application = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load application details.';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final updated = await api.patchJson(
        '/api/v1/admin/admissions/applications/${widget.applicationId}',
        {'status': status},
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _application = updated;
        _notice = 'Status updated to $status.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _updateDocStatus(String docId, String status) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.patchJson(
        '/api/v1/admin/admissions/documents/$docId',
        {'status': status},
        session: session,
      );
      await _loadApplication();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _addDocument() async {
    final title = _newDocTitleController.text.trim();
    if (title.isEmpty) return;

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.postJson(
        '/api/v1/admin/admissions/applications/${widget.applicationId}/documents',
        {
          'title': title,
          'status': 'pending',
          if (_newDocNumberController.text.trim().isNotEmpty) 'documentNumber': _newDocNumberController.text.trim(),
        },
        session: session,
      );
      _newDocTitleController.clear();
      _newDocNumberController.clear();
      setState(() => _addingDoc = false);
      await _loadApplication();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _application == null) {
      return AppDialog(
        title: 'Application Details',
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final app = _application!;
    final appNumber = app['applicationNumber'] as String? ?? '';
    final name = app['applicantName'] as String? ?? '';
    final className = app['className'] as String? ?? '';
    final status = app['status'] as String? ?? 'applied';
    final docs = (app['documents'] as List<dynamic>? ?? const []).cast<Map<String, Object?>>();
    final isApproved = status == 'approved';
    final isEnrolled = status == 'enrolled';

    return AppDialog(
      title: name,
      subtitle: '$appNumber • Applying for $className',
      maxWidth: 620,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
        if (isApproved && !isEnrolled)
          FilledButton.icon(
            onPressed: () async {
              final enrolled = await showDialog<bool>(
                context: context,
                builder: (context) => _EnrollApplicantDialog(
                  application: app,
                  sections: widget.sections,
                ),
              );
              if (enrolled == true) {
                await _loadApplication();
              }
            },
            icon: const Icon(Icons.how_to_reg_outlined, size: 14),
            label: const Text('Enroll Student'),
          ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              FeedbackBanner(message: _error!, tone: FeedbackTone.error),
              const SizedBox(height: 12),
            ],
            if (_notice != null) ...[
              FeedbackBanner(message: _notice!, tone: FeedbackTone.success),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Text('Pipeline Status: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: status,
                    isDense: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'inquiry', child: Text('Inquiry Lead')),
                      DropdownMenuItem(value: 'applied', child: Text('Applied')),
                      DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                      DropdownMenuItem(value: 'approved', child: Text('Approved for Intake')),
                      DropdownMenuItem(value: 'enrolled', child: Text('Enrolled')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: isEnrolled ? null : (val) => val != null ? _updateStatus(val) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Verification Documents Checklist', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryBorder),
                borderRadius: AppRadii.rMd,
              ),
              child: Column(
                children: [
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No verification checklist documents attached.', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                    )
                  else
                    ...docs.map((d) {
                      final docId = d['id'] as String? ?? '';
                      final title = d['title'] as String? ?? '';
                      final docStatus = d['status'] as String? ?? 'pending';
                      final docNum = d['documentNumber'] as String?;
                      final verifiedBy = d['verifiedByStaffName'] as String?;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  if (docNum != null && docNum.isNotEmpty)
                                    Text('Doc ID: $docNum', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                  if (verifiedBy != null)
                                    Text('Verified by $verifiedBy', style: const TextStyle(fontSize: 11, color: AppColors.statusSuccess)),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: docStatus,
                              isDense: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                                DropdownMenuItem(value: 'verified', child: Text('Verified')),
                                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                              ],
                              onChanged: (val) => val != null ? _updateDocStatus(docId, val) : null,
                            ),
                          ],
                        ),
                      );
                    }),
                  if (_addingDoc)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newDocTitleController,
                            decoration: const InputDecoration(labelText: 'Document Title (e.g. Immunization Record)'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newDocNumberController,
                            decoration: const InputDecoration(labelText: 'Document Reference Number (optional)'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _addingDoc = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _addDocument,
                                child: const Text('Add Document'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _addingDoc = true),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Document to Checklist'),
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
}

class _EnrollApplicantDialog extends ConsumerStatefulWidget {
  const _EnrollApplicantDialog({
    required this.application,
    required this.sections,
  });

  final Map<String, Object?> application;
  final List<Map<String, Object?>> sections;

  @override
  ConsumerState<_EnrollApplicantDialog> createState() => _EnrollApplicantDialogState();
}

class _EnrollApplicantDialogState extends ConsumerState<_EnrollApplicantDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _sectionId;
  final _admNumberController = TextEditingController();
  final _rollNumberController = TextEditingController();

  bool _submitting = false;
  String? _error;

  List<Map<String, Object?>> get _validSections {
    final classId = widget.application['applyingForClassId'] as String?;
    return widget.sections.where((s) => s['classId'] == classId).toList();
  }

  @override
  void initState() {
    super.initState();
    final valid = _validSections;
    if (valid.isNotEmpty) {
      _sectionId = valid.first['id'] as String?;
    }
    final appNumber = widget.application['applicationNumber'] as String? ?? '';
    _admNumberController.text = appNumber.replaceAll('APP-', 'ADM-');
  }

  @override
  void dispose() {
    _admNumberController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sectionId == null) {
      setState(() => _error = 'Please select a classroom section.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final appId = widget.application['id'] as String?;
    if (appId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'sectionId': _sectionId,
        'admissionNumber': _admNumberController.text.trim(),
        if (_rollNumberController.text.trim().isNotEmpty) 'rollNumber': _rollNumberController.text.trim(),
      };

      await api.postJson('/api/v1/admin/admissions/applications/$appId/enroll', payload, session: session);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to enroll applicant.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.application['applicantName'] as String? ?? 'Applicant';
    final className = widget.application['className'] as String? ?? 'Class';
    final valid = _validSections;

    return AppDialog(
      title: 'Enroll $name',
      subtitle: 'Assign to $className section and assign official admission ID.',
      maxWidth: 480,
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _enroll,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Complete Enrollment'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              FeedbackBanner(message: _error!, tone: FeedbackTone.error),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _sectionId,
              decoration: const InputDecoration(labelText: 'Assigned Classroom Section *'),
              items: valid.map((s) {
                return DropdownMenuItem(
                  value: s['id'] as String?,
                  child: Text('Section ${s['name'] ?? ''}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _sectionId = val),
              validator: (val) => val == null ? 'Please select section' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _admNumberController,
              decoration: const InputDecoration(labelText: 'Admission Number / Student ID *'),
              validator: (val) => (val == null || val.trim().length < 2) ? 'Admission number required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rollNumberController,
              decoration: const InputDecoration(labelText: 'Roll Number (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}

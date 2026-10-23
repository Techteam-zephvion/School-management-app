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
import '../../student/utils/fee_receipt_pdf.dart';

class AdminFeesView extends ConsumerStatefulWidget {
  const AdminFeesView({
    required this.years,
    required this.classes,
    required this.sections,
    required this.students,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> students;
  final Future<void> Function() reload;

  @override
  ConsumerState<AdminFeesView> createState() => _AdminFeesViewState();
}

class _AdminFeesViewState extends ConsumerState<AdminFeesView> {
  String _activeTab = 'allocations'; // 'allocations', 'structures', 'payments'
  bool _loading = true;
  String? _error;
  String? _notice;

  Map<String, Object?> _summary = const {};
  List<Map<String, Object?>> _structures = const [];
  List<Map<String, Object?>> _allocations = const [];
  List<Map<String, Object?>> _payments = const [];
  List<Map<String, Object?>> _concessions = const [];
  List<Map<String, Object?>> _refunds = const [];

  String? _filterClassId;
  String? _filterSectionId;
  String _filterStatus = 'all';
  final _searchController = TextEditingController();

  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeeData() async {
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
      final summary = await api.getJson(
        '/api/v1/admin/fees/summary',
        session: session,
      );
      final structures = await api.getList(
        '/api/v1/admin/fees/structures',
        session: session,
      );
      final allocations = await api.getList(
        '/api/v1/admin/fees/allocations',
        session: session,
      );
      final payments = await api.getList(
        '/api/v1/admin/fees/payments',
        session: session,
      );
      final concessions = await api.listFeeConcessions(session: session);
      final refunds = await api.listFeeRefunds(session: session);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _structures = structures;
        _allocations = allocations;
        _payments = payments;
        _concessions = concessions;
        _refunds = refunds;
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
        _error = 'Unable to load fee records.';
        _loading = false;
      });
    }
  }

  List<Map<String, Object?>> get _filteredAllocations {
    final query = _searchController.text.trim().toLowerCase();
    return _allocations.where((a) {
      if (_filterClassId != null && a['classId'] != _filterClassId)
        return false;
      if (_filterSectionId != null && a['sectionId'] != _filterSectionId)
        return false;
      if (_filterStatus != 'all' && a['status'] != _filterStatus) return false;
      if (query.isNotEmpty) {
        final name = (a['studentName'] as String? ?? '').toLowerCase();
        final adm = (a['admissionNumber'] as String? ?? '').toLowerCase();
        final roll = (a['rollNumber'] as String? ?? '').toLowerCase();
        final fee = (a['feeStructureName'] as String? ?? '').toLowerCase();
        if (!name.contains(query) &&
            !adm.contains(query) &&
            !roll.contains(query) &&
            !fee.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Fees & Finance',
          description: 'Configure fee structures, track student dues, record payments, and audit receipts.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _openAssignFeeDialog,
            icon: const Icon(Icons.assignment_ind_outlined, size: 16),
            label: const Text('Assign Student Fee'),
          ),
          secondaryActions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _openAddStructureDialog,
              icon: const Icon(Icons.add_outlined, size: 16),
              label: const Text('Add Fee Structure'),
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
        else if (_activeTab == 'allocations')
          _buildAllocationsTab()
        else if (_activeTab == 'structures')
          _buildStructuresTab()
        else if (_activeTab == 'payments')
          _buildPaymentsTab()
        else if (_activeTab == 'concessions')
          _buildConcessionsTab()
        else
          _buildRefundsTab(),
      ],
    );
  }

  Widget _buildStatStrip() {
    final billed = (_summary['totalBilled'] as num?)?.toInt() ?? 0;
    final collected = (_summary['totalCollected'] as num?)?.toInt() ?? 0;
    final outstanding = (_summary['totalOutstanding'] as num?)?.toInt() ?? 0;
    final overdueCount = (_summary['overdueCount'] as num?)?.toInt() ?? 0;

    return StatStrip(
      items: [
        StatItemData(
          label: 'Total Billed',
          value: _currencyFormat.format(billed),
          helper: 'Allocated across students',
        ),
        StatItemData(
          label: 'Total Collected',
          value: _currencyFormat.format(collected),
          helper: 'Receipts recorded',
        ),
        StatItemData(
          label: 'Outstanding Due',
          value: _currencyFormat.format(outstanding),
          helper: 'Pending collection',
        ),
        StatItemData(
          label: 'Overdue Dues',
          value: overdueCount.toString(),
          helper: 'Past due date',
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
            _navTab(
              'allocations',
              'Student Dues & Allocations (${_allocations.length})',
            ),
            const SizedBox(width: 24),
            _navTab('structures', 'Fee Structures (${_structures.length})'),
            const SizedBox(width: 24),
            _navTab('payments', 'Receipts Ledger (${_payments.length})'),
            const SizedBox(width: 24),
            _navTab(
              'concessions',
              'Concessions & Waivers (${_concessions.length})',
            ),
            const SizedBox(width: 24),
            _navTab('refunds', 'Refunds (${_refunds.length})'),
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

  Widget _buildAllocationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFiltersRow(),
        const SizedBox(height: 12),
        if (_filteredAllocations.isEmpty)
          const EmptyStateView(
            title: 'No student fee allocations found',
            description: 'Assign a fee structure to students or adjust your active filters.',
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBorder),
              borderRadius: AppRadii.rMd,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.secondaryBackground,
                ),
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Class & Section')),
                  DataColumn(label: Text('Fee Structure')),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Billed')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Balance')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _filteredAllocations.map((a) {
                  final billed = (a['amount'] as num?)?.toInt() ?? 0;
                  final paid = (a['paidAmount'] as num?)?.toInt() ?? 0;
                  final balance = (a['balanceAmount'] as num?)?.toInt() ?? 0;
                  final status = a['status'] as String? ?? 'pending';

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              a['studentName'] as String? ?? '—',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Adm: ${a['admissionNumber'] ?? '—'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text('${a['className']} ${a['sectionName']}'.trim()),
                      ),
                      DataCell(Text(a['feeStructureName'] as String? ?? '—')),
                      DataCell(Text(a['dueDate'] as String? ?? '—')),
                      DataCell(Text(_currencyFormat.format(billed))),
                      DataCell(Text(_currencyFormat.format(paid))),
                      DataCell(
                        Text(
                          _currencyFormat.format(balance),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: balance > 0
                                ? AppColors.statusError
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(
                        balance > 0
                            ? FilledButton.tonal(
                                onPressed: () => _openRecordPaymentDialog(a),
                                child: const Text('Collect Fee'),
                              )
                            : const Text(
                                'Fully Paid',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFiltersRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search student or fee...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        DropdownButton<String?>(
          value: _filterClassId,
          hint: const Text('All Classes'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Classes')),
            ...widget.classes.map(
              (c) => DropdownMenuItem(
                value: c['id'] as String?,
                child: Text(c['name'] as String? ?? ''),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _filterClassId = val;
              _filterSectionId = null;
            });
          },
        ),
        DropdownButton<String>(
          value: _filterStatus,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'partial', child: Text('Partial')),
            DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
            DropdownMenuItem(value: 'paid', child: Text('Paid')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _filterStatus = val);
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'paid':
        return const StatusBadge(label: 'Paid', tone: BadgeTone.success);
      case 'partial':
        return const StatusBadge(label: 'Partial', tone: BadgeTone.warning);
      case 'overdue':
        return const StatusBadge(label: 'Overdue', tone: BadgeTone.error);
      default:
        return const StatusBadge(label: 'Pending', tone: BadgeTone.neutral);
    }
  }

  Widget _buildStructuresTab() {
    if (_structures.isEmpty) {
      return const EmptyStateView(
        title: 'No fee structures configured',
        description: 'Create tuition, transport, or lab fee structures to start billing students.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rMd,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.secondaryBackground,
          ),
          columns: const [
            DataColumn(label: Text('Fee Name')),
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Academic Year')),
            DataColumn(label: Text('Frequency')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Default Due Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _structures.map((s) {
            final amount = (s['amount'] as num?)?.toInt() ?? 0;
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s['name'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (s['description'] != null &&
                          (s['description'] as String).isNotEmpty)
                        Text(
                          s['description'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(s['code'] as String? ?? '—')),
                DataCell(Text(s['academicYearName'] as String? ?? '—')),
                DataCell(
                  Text((s['frequency'] as String? ?? 'term').toUpperCase()),
                ),
                DataCell(
                  Text(
                    _currencyFormat.format(amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(s['dueDate'] as String? ?? '—')),
                DataCell(
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.account_tree_outlined, size: 18),
                        tooltip: 'Manage fee heads',
                        onPressed: () => _manageStructureHeads(s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Delete structure',
                        onPressed: () => _deleteStructure(s['id'] as String),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return const EmptyStateView(
        title: 'No payment receipts issued yet',
        description: 'Collected fee payments will generate official receipts recorded in this ledger.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rMd,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.secondaryBackground,
          ),
          columns: const [
            DataColumn(label: Text('Receipt #')),
            DataColumn(label: Text('Date & Time')),
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Fee Structure')),
            DataColumn(label: Text('Amount Paid')),
            DataColumn(label: Text('Payment Method')),
            DataColumn(label: Text('Recorded By')),
            DataColumn(label: Text('Action')),
          ],
          rows: _payments.map((p) {
            final amount = (p['amountPaid'] as num?)?.toInt() ?? 0;
            final paidAt = p['paidAt'] as String? ?? '';
            final formattedDate = paidAt.length >= 10
                ? paidAt.substring(0, 10)
                : paidAt;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    p['receiptNumber'] as String? ?? '—',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(Text(formattedDate)),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p['studentName'] as String? ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Adm: ${p['admissionNumber'] ?? '—'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(p['feeStructureName'] as String? ?? '—')),
                DataCell(
                  Text(
                    _currencyFormat.format(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                DataCell(
                  Text((p['paymentMethod'] as String? ?? 'cash').toUpperCase()),
                ),
                DataCell(Text(p['recordedByStaffName'] as String? ?? 'Admin')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    tooltip: 'View Receipt',
                    onPressed: () => _viewReceiptModal(p),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _deleteStructure(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: const Text(
          'Are you sure you want to delete this fee structure? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/api/v1/admin/fees/structures/$id', session: session);
      setState(() => _notice = 'Fee structure deleted.');
      await _loadFeeData();
    } catch (_) {
      setState(() => _error = 'Unable to delete fee structure.');
    }
  }

  void _openAddStructureDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddStructureModal(
        years: widget.years,
        onCreated: () {
          _loadFeeData();
          setState(() => _notice = 'Fee structure created successfully.');
        },
      ),
    );
  }

  void _openAssignFeeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AssignFeeModal(
        students: widget.students,
        structures: _structures,
        years: widget.years,
        onAssigned: () {
          _loadFeeData();
          setState(() => _notice = 'Fee allocated to student successfully.');
        },
      ),
    );
  }

  void _openRecordPaymentDialog(Map<String, Object?> allocation) {
    showDialog(
      context: context,
      builder: (ctx) => _RecordPaymentModal(
        allocation: allocation,
        onPaid: (receipt) {
          _loadFeeData();
          setState(
            () => _notice =
                'Payment recorded. Receipt ${receipt['receiptNumber']} issued.',
          );
        },
      ),
    );
  }

  Widget _buildConcessionsTab() {
    if (_concessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubHeader(
            'Fee Concessions & Scholarships',
            _openAddConcessionDialog,
          ),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No fee concessions configured yet.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubHeader(
          'Fee Concessions & Scholarships',
          _openAddConcessionDialog,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Concession Name')),
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Discount Value')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _concessions.map((c) {
              final type = c['type'] as String? ?? 'flat';
              final val = (c['value'] as num?)?.toInt() ?? 0;
              final displayVal = type == 'percentage'
                  ? '$val%'
                  : _currencyFormat.format(val);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      c['name'] as String? ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(
                      c['code'] as String? ?? '—',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(
                    Text((c['category'] as String? ?? 'merit').toUpperCase()),
                  ),
                  DataCell(
                    Text(
                      displayVal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusSuccess,
                      ),
                    ),
                  ),
                  const DataCell(
                    StatusBadge(label: 'ACTIVE', tone: BadgeTone.success),
                  ),
                  DataCell(
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _openApplyConcessionDialog(c),
                          child: const Text('Apply to student'),
                        ),
                        TextButton(
                          onPressed: _showAppliedConcessions,
                          child: const Text('View applied'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRefundsTab() {
    if (_refunds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSubHeader('Fee Refunds Ledger', _openAddRefundDialog),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No payment refunds issued yet.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubHeader('Fee Refunds Ledger', _openAddRefundDialog),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Refund #')),
              DataColumn(label: Text('Student')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Mode')),
              DataColumn(label: Text('Reason')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _refunds.map((r) {
              final amount = (r['amount'] as num?)?.toInt() ?? 0;
              final status = (r['status'] as String? ?? 'pending')
                  .toLowerCase();

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      r['refundNumber'] as String? ?? '—',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(r['studentName'] as String? ?? 'Student')),
                  DataCell(
                    Text(
                      _currencyFormat.format(amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      (r['mode'] as String? ?? 'bank_transfer').toUpperCase(),
                    ),
                  ),
                  DataCell(Text(r['reason'] as String? ?? '—')),
                  DataCell(
                    StatusBadge(
                      label: status.toUpperCase(),
                      tone: status == 'processed' || status == 'approved'
                          ? BadgeTone.success
                          : BadgeTone.neutral,
                    ),
                  ),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Update refund status',
                      enabled: status != 'processed' && status != 'rejected',
                      onSelected: (value) => _updateRefundStatus(r, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'approved',
                          child: Text('Approve refund'),
                        ),
                        PopupMenuItem(
                          value: 'processed',
                          child: Text('Mark processed'),
                        ),
                        PopupMenuItem(
                          value: 'rejected',
                          child: Text('Reject refund'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Record'),
        ),
      ],
    );
  }

  Future<void> _openApplyConcessionDialog(
    Map<String, Object?> concession,
  ) async {
    if (_allocations.isEmpty) {
      setState(
        () => _error =
            'Create a student fee allocation before applying a concession.',
      );
      return;
    }
    var allocation = _allocations.first;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Apply ${concession['name'] ?? 'concession'}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, Object?>>(
                  initialValue: allocation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Student fee allocation',
                  ),
                  items: _allocations
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item['studentName']} • ${item['feeStructureName']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => allocation = value ?? allocation),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    helperText: 'Optional audit note for this concession.',
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
              child: const Text('Apply concession'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .applyStudentConcession(
            session: session,
            studentId: allocation['studentId'] as String,
            allocationId: allocation['id'] as String,
            concessionId: concession['id'] as String,
            reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
          );
      setState(
        () => _notice = 'Concession applied to ${allocation['studentName']}.',
      );
      await _loadFeeData();
    } catch (error) {
      setState(() => _error = 'Unable to apply concession: $error');
    }
  }

  Future<void> _showAppliedConcessions() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final rows = await ref
          .read(apiClientProvider)
          .listStudentConcessions(session: session);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Applied concessions'),
          content: SizedBox(
            width: 620,
            height: 420,
            child: rows.isEmpty
                ? const Center(child: Text('No concessions have been applied.'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${row['studentName'] ?? 'Student'}'),
                        subtitle: Text(
                          '${row['concessionName'] ?? row['name'] ?? 'Concession'} • ${row['reason'] ?? 'No note'}',
                        ),
                        trailing: StatusBadge.fromStatusString(
                          row['status'] as String? ?? 'active',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      setState(() => _error = 'Unable to load applied concessions: $error');
    }
  }

  Future<void> _updateRefundStatus(
    Map<String, Object?> refund,
    String status,
  ) async {
    final session = ref.read(authControllerProvider).session;
    final id = refund['id'] as String?;
    if (session == null || id == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .updateFeeRefundStatus(
            session: session,
            refundId: id,
            status: status,
          );
      setState(() => _notice = 'Refund status updated to $status.');
      await _loadFeeData();
    } catch (error) {
      setState(() => _error = 'Unable to update refund: $error');
    }
  }

  Future<void> _manageStructureHeads(Map<String, Object?> structure) async {
    final session = ref.read(authControllerProvider).session;
    final id = structure['id'] as String?;
    if (session == null || id == null) return;
    List<Map<String, Object?>> heads;
    try {
      heads = await ref
          .read(apiClientProvider)
          .listFeeStructureHeads(session: session, feeStructureId: id);
    } catch (error) {
      setState(() => _error = 'Unable to load fee heads: $error');
      return;
    }
    if (!mounted) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    var optional = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('Fee heads • ${structure['name']}'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (heads.isEmpty)
                  const Text(
                    'No component heads yet.',
                    style: AppTypography.bodySecondary,
                  )
                else
                  ...heads.map(
                    (head) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${head['headName']}'),
                      subtitle: Text(
                        head['isOptional'] == true ? 'Optional' : 'Required',
                      ),
                      trailing: Text(
                        _currencyFormat.format(head['amount'] ?? 0),
                      ),
                    ),
                  ),
                const Divider(),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'New head name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: optional,
                  onChanged: (value) =>
                      setDialogState(() => optional = value ?? false),
                  title: const Text('Optional fee head'),
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
                final parsed = int.tryParse(amount.text.trim());
                if (name.text.trim().length < 2 || parsed == null || parsed < 0)
                  return;
                await ref
                    .read(apiClientProvider)
                    .createFeeStructureHead(
                      session: session,
                      feeStructureId: id,
                      headName: name.text.trim(),
                      amount: parsed,
                      isOptional: optional,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() => _notice = 'Fee head added.');
                await _loadFeeData();
              },
              child: const Text('Add fee head'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddConcessionDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    String type = 'percentage';
    String category = 'merit';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Create Fee Concession Policy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Concession Name *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Policy Code * (e.g. SIBLING15)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percentage (%)'),
                  ),
                  DropdownMenuItem(
                    value: 'flat',
                    child: Text('Flat Amount (₹)'),
                  ),
                ],
                onChanged: (val) =>
                    setDialogState(() => type = val ?? 'percentage'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: type == 'percentage'
                      ? 'Percentage (e.g. 15)'
                      : 'Amount in ₹',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'merit',
                    child: Text('Merit Scholarship'),
                  ),
                  DropdownMenuItem(
                    value: 'sibling',
                    child: Text('Sibling Discount'),
                  ),
                  DropdownMenuItem(
                    value: 'staff_ward',
                    child: Text('Staff Ward'),
                  ),
                  DropdownMenuItem(
                    value: 'financial_aid',
                    child: Text('Financial Aid / EWS'),
                  ),
                  DropdownMenuItem(
                    value: 'sports',
                    child: Text('Sports Quota'),
                  ),
                ],
                onChanged: (val) =>
                    setDialogState(() => category = val ?? 'merit'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final val = int.tryParse(valueController.text.trim()) ?? 0;
                if (nameController.text.trim().isEmpty ||
                    codeController.text.trim().isEmpty ||
                    val <= 0) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(apiClientProvider)
                      .createFeeConcession(
                        session: session,
                        name: nameController.text.trim(),
                        code: codeController.text.trim(),
                        type: type,
                        value: val,
                        category: category,
                      );
                  setState(() => _notice = 'Concession policy created.');
                  await _loadFeeData();
                } catch (e) {
                  setState(() => _error = 'Failed to create concession: $e');
                }
              },
              child: const Text('Create Policy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddRefundDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _allocations.isEmpty) return;

    String? selectedAllocationId = _allocations.first['id'] as String?;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String mode = 'bank_transfer';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Issue Fee Refund'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedAllocationId,
                decoration: const InputDecoration(
                  labelText: 'Select Student Allocation *',
                ),
                items: _allocations
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String?,
                        child: Text(
                          '${a['studentName']} — ${a['feeStructureName']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedAllocationId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Refund Amount (₹) *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Refund *',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: const [
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('Bank Transfer (NEFT/RTGS)'),
                  ),
                  DropdownMenuItem(value: 'cash', child: Text('Cash Counter')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(
                    value: 'gateway_refund',
                    child: Text('Payment Gateway (Cashfree)'),
                  ),
                ],
                onChanged: (val) =>
                    setDialogState(() => mode = val ?? 'bank_transfer'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amt = int.tryParse(amountController.text.trim()) ?? 0;
                if (selectedAllocationId == null ||
                    amt <= 0 ||
                    reasonController.text.trim().isEmpty) {
                  return;
                }
                final alloc = _allocations.firstWhere(
                  (a) => a['id'] == selectedAllocationId,
                );
                final studentId = alloc['studentId'] as String;

                Navigator.pop(ctx);
                try {
                  await ref
                      .read(apiClientProvider)
                      .createFeeRefund(
                        session: session,
                        allocationId: selectedAllocationId!,
                        studentId: studentId,
                        amount: amt,
                        reason: reasonController.text.trim(),
                        mode: mode,
                      );
                  setState(
                    () => _notice = 'Refund request recorded successfully.',
                  );
                  await _loadFeeData();
                } catch (e) {
                  setState(() => _error = 'Failed to record refund: $e');
                }
              },
              child: const Text('Submit Refund'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewReceiptModal(Map<String, Object?> payment) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceiptModal(payment: payment),
    );
  }
}

class _AddStructureModal extends ConsumerStatefulWidget {
  const _AddStructureModal({required this.years, required this.onCreated});
  final List<Map<String, Object?>> years;
  final VoidCallback onCreated;

  @override
  ConsumerState<_AddStructureModal> createState() => _AddStructureModalState();
}

class _AddStructureModalState extends ConsumerState<_AddStructureModal> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _dueDate = TextEditingController(
    text: DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 30))),
  );
  String? _yearId;
  String _frequency = 'term';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.years.isNotEmpty) {
      _yearId = widget.years.first['id'] as String?;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _amount.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Add Fee Structure',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save Structure'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.statusError),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _yearId,
              decoration: const InputDecoration(labelText: 'Academic Year *'),
              items: widget.years
                  .map(
                    (y) => DropdownMenuItem(
                      value: y['id'] as String,
                      child: Text(y['name'] as String? ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _yearId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Fee Name *',
                hintText: 'e.g. Annual Tuition Fee',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Fee Code *',
                hintText: 'e.g. TUIT-2026',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                hintText: 'e.g. 25000',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency *'),
              items: const [
                DropdownMenuItem(value: 'one_time', child: Text('One Time')),
                DropdownMenuItem(value: 'term', child: Text('Term')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'annual', child: Text('Annual')),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? 'term'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueDate,
              decoration: const InputDecoration(
                labelText: 'Default Due Date (YYYY-MM-DD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _yearId == null) return;

    final amountNum = int.tryParse(_amount.text.trim());
    if (_name.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        amountNum == null ||
        amountNum <= 0) {
      setState(
        () => _error = 'Please fill all required fields with valid values.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/admin/fees/structures',
        {
          'academicYearId': _yearId,
          'name': _name.text.trim(),
          'code': _code.text.trim().toUpperCase(),
          'amount': amountNum,
          'frequency': _frequency,
          'dueDate': _dueDate.text.trim().isNotEmpty
              ? _dueDate.text.trim()
              : null,
          'description': _description.text.trim().isNotEmpty
              ? _description.text.trim()
              : null,
        },
        session: session,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to create fee structure.';
        _saving = false;
      });
    }
  }
}

class _AssignFeeModal extends ConsumerStatefulWidget {
  const _AssignFeeModal({
    required this.students,
    required this.structures,
    required this.years,
    required this.onAssigned,
  });

  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> structures;
  final List<Map<String, Object?>> years;
  final VoidCallback onAssigned;

  @override
  ConsumerState<_AssignFeeModal> createState() => _AssignFeeModalState();
}

class _AssignFeeModalState extends ConsumerState<_AssignFeeModal> {
  String? _studentId;
  String? _structureId;
  final _amount = TextEditingController();
  final _dueDate = TextEditingController(
    text: DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 15))),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Assign Fee to Student',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Assigning...' : 'Assign Fee'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.statusError),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _studentId,
              decoration: const InputDecoration(labelText: 'Student *'),
              items: widget.students
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['fullName']} (${s['admissionNumber']})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _studentId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _structureId,
              decoration: const InputDecoration(labelText: 'Fee Structure *'),
              items: widget.structures
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['name']} (₹${s['amount']})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _structureId = v;
                  final match = widget.structures.firstWhere(
                    (s) => s['id'] == v,
                    orElse: () => const {},
                  );
                  if (match['amount'] != null) {
                    _amount.text = match['amount'].toString();
                  }
                  if (match['dueDate'] != null &&
                      (match['dueDate'] as String).isNotEmpty) {
                    _dueDate.text = match['dueDate'] as String;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Billed Amount (₹) *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dueDate,
              decoration: const InputDecoration(
                labelText: 'Due Date (YYYY-MM-DD) *',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _studentId == null || _structureId == null) {
      setState(() => _error = 'Please select student and fee structure.');
      return;
    }

    final amountNum = int.tryParse(_amount.text.trim());
    if (amountNum == null || amountNum <= 0 || _dueDate.text.trim().isEmpty) {
      setState(() => _error = 'Please enter valid amount and due date.');
      return;
    }

    final selectedStructure = widget.structures.firstWhere(
      (s) => s['id'] == _structureId,
    );
    final academicYearId = selectedStructure['academicYearId'] as String?;

    if (academicYearId == null) {
      setState(() => _error = 'Invalid academic year in fee structure.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).postJson(
        '/api/v1/admin/fees/allocations',
        {
          'studentId': _studentId,
          'feeStructureId': _structureId,
          'academicYearId': academicYearId,
          'amount': amountNum,
          'dueDate': _dueDate.text.trim(),
        },
        session: session,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssigned();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to assign fee to student.';
        _saving = false;
      });
    }
  }
}

class _RecordPaymentModal extends ConsumerStatefulWidget {
  const _RecordPaymentModal({required this.allocation, required this.onPaid});
  final Map<String, Object?> allocation;
  final void Function(Map<String, Object?> receipt) onPaid;

  @override
  ConsumerState<_RecordPaymentModal> createState() =>
      _RecordPaymentModalState();
}

class _RecordPaymentModalState extends ConsumerState<_RecordPaymentModal> {
  final _amountPaid = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMethod = 'cash';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final balance = (widget.allocation['balanceAmount'] as num?)?.toInt() ?? 0;
    _amountPaid.text = balance > 0 ? balance.toString() : '';
  }

  @override
  void dispose() {
    _amountPaid.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = (widget.allocation['balanceAmount'] as num?)?.toInt() ?? 0;
    final studentName = widget.allocation['studentName'] as String? ?? '';
    final feeName = widget.allocation['feeStructureName'] as String? ?? '';

    return AppDialog(
      title: 'Collect Fee Payment',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Recording...' : 'Collect & Issue Receipt'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  Text(
                    'Student: $studentName',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('Fee: $feeName', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Balance Outstanding: ₹$balance',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusError,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.statusError),
                ),
              ),
            TextField(
              controller: _amountPaid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount to Collect (₹) *',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method *'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'upi', child: Text('UPI / QR')),
                DropdownMenuItem(
                  value: 'card',
                  child: Text('Credit / Debit Card'),
                ),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Bank Transfer (NEFT/IMPS)'),
                ),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ref,
              decoration: const InputDecoration(
                labelText: 'Transaction / Cheque Ref (Optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Receipt Notes (Optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final amountNum = int.tryParse(_amountPaid.text.trim());
    if (amountNum == null || amountNum <= 0) {
      setState(() => _error = 'Please enter a valid payment amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final receipt = await ref.read(apiClientProvider).postJson(
        '/api/v1/admin/fees/payments',
        {
          'allocationId': widget.allocation['id'],
          'amountPaid': amountNum,
          'paymentMethod': _paymentMethod,
          'transactionReference': _ref.text.trim().isNotEmpty
              ? _ref.text.trim()
              : null,
          'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        },
        session: session,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onPaid(receipt);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to record payment.';
        _saving = false;
      });
    }
  }
}

class _ReceiptModal extends StatelessWidget {
  const _ReceiptModal({required this.payment});
  final Map<String, Object?> payment;

  @override
  Widget build(BuildContext context) {
    final receiptNum = payment['receiptNumber'] as String? ?? '—';
    final amount = (payment['amountPaid'] as num?)?.toInt() ?? 0;
    final method = (payment['paymentMethod'] as String? ?? 'cash')
        .toUpperCase();
    final student = payment['studentName'] as String? ?? '—';
    final adm = payment['admissionNumber'] as String? ?? '—';
    final fee = payment['feeStructureName'] as String? ?? '—';
    final paidAt = payment['paidAt'] as String? ?? '';
    final recordedBy =
        payment['recordedByStaffName'] as String? ?? 'Administrator';
    final ref = payment['transactionReference'] as String?;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Fee Payment Receipt',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Container(
        width: 440,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: AppRadii.rMd,
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Schoolic.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: AppRadii.rSm,
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _receiptRow('Receipt Number', receiptNum, isBold: true),
            _receiptRow(
              'Date & Time',
              paidAt.length >= 19
                  ? paidAt.substring(0, 19).replaceAll('T', ' ')
                  : paidAt,
            ),
            _receiptRow('Student Name', student),
            _receiptRow('Admission No', adm),
            _receiptRow('Fee Category', fee),
            _receiptRow('Payment Method', method),
            if (ref != null && ref.isNotEmpty)
              _receiptRow('Reference / UTR', ref),
            _receiptRow('Received By', recordedBy),
            const Divider(height: 24),
            _receiptRow('Total Amount Paid', '₹$amount', isLarge: true),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.print, size: 16),
          label: const Text('Print Receipt'),
          onPressed: () {
            printOrShareFeeReceipt(
              FeeReceiptData(
                schoolName: 'Schoolic Academy',
                receiptNumber: receiptNum,
                studentName: student,
                admissionNumber: adm,
                className: 'Institutional',
                sectionName: '',
                feeName: fee,
                amountPaid: amount,
                paymentMethod: method,
                paidAt: paidAt,
                transactionReference: ref,
              ),
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close Receipt'),
        ),
      ],
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 16 : 13,
              fontWeight: (isBold || isLarge)
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isLarge ? AppColors.accent : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

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

class AdminInsightsView extends ConsumerStatefulWidget {
  const AdminInsightsView({
    required this.classes,
    required this.sections,
    this.initialTab = 0,
    super.key,
  });

  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final int initialTab;

  @override
  ConsumerState<AdminInsightsView> createState() => _AdminInsightsViewState();
}

class _AdminInsightsViewState extends ConsumerState<AdminInsightsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 0: At-Risk Early Warning State
  List<Map<String, Object?>> _atRiskAlerts = const [];
  bool _loadingAtRisk = false;
  bool _evaluatingAtRisk = false;
  String? _atRiskClassId;
  String? _atRiskSectionId;
  String? _atRiskLevel;
  String? _atRiskStatus;

  // Tab 1: Natural Language Analytics State
  final _nlQueryController = TextEditingController();
  bool _loadingNlQuery = false;
  Map<String, Object?>? _nlResult;

  // Tab 2: Attendance AI Insights State (Existing)
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  String? _classId;
  String? _sectionId;
  bool _loadingAttendance = false;
  String? _error;
  Map<String, Object?>? _result;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    final now = DateTime.now();
    _endDate.text = _iso(now);
    _startDate.text = _iso(now.subtract(const Duration(days: 13)));
    _loadAtRiskAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nlQueryController.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // TAB 0: At-Risk Early Warning Engine
  // ---------------------------------------------------------------------------

  Future<void> _loadAtRiskAlerts() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() => _loadingAtRisk = true);
    try {
      final rows = await ref.read(apiClientProvider).getAtRiskStudents(
            session: session,
            classId: _atRiskClassId,
            sectionId: _atRiskSectionId,
            riskLevel: _atRiskLevel,
            status: _atRiskStatus,
          );
      setState(() => _atRiskAlerts = rows);
    } catch (e) {
      // In tests or local dev when db is empty, maintain empty list
    } finally {
      if (mounted) setState(() => _loadingAtRisk = false);
    }
  }

  Future<void> _runRiskEvaluation() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _evaluatingAtRisk = true;
      _error = null;
    });
    try {
      final results = await ref.read(apiClientProvider).evaluateStudentRiskScores(
            session: session,
            classId: _atRiskClassId,
            sectionId: _atRiskSectionId,
          );
      if (results.isNotEmpty) {
        setState(() => _atRiskAlerts = results);
      } else {
        await _loadAtRiskAlerts();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multi-factor student risk scores evaluated successfully'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _evaluatingAtRisk = false);
    }
  }

  Future<void> _openInterventionDialog(Map<String, Object?> alert) async {
    final studentId = (alert['studentId'] as String?) ?? '';
    final studentName = (alert['studentName'] as String?) ?? 'Student';
    final currentStatus = (alert['status'] as String?) ?? 'active';

    final actionController = TextEditingController(text: 'Academic Remediation & Counseling');
    final notesController = TextEditingController();
    String selectedStatus = currentStatus;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Log Staff Intervention',
          subtitle: 'Record counselor or faculty action for $studentName',
          maxWidth: 480,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      if (notesController.text.trim().length < 3) return;
                      final session = ref.read(authControllerProvider).session;
                      if (session == null) return;

                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(apiClientProvider).recordStudentIntervention(
                              session: session,
                              studentId: studentId,
                              action: actionController.text.trim(),
                              notes: notesController.text.trim(),
                              status: selectedStatus,
                            );
                        if (!mounted) return;
                        nav.pop();
                        _loadAtRiskAlerts();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Intervention recorded successfully'),
                            backgroundColor: AppColors.statusSuccess,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => submitting = false);
                      }
                    },
              icon: submitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Intervention'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: actionController,
                decoration: const InputDecoration(
                  labelText: 'Intervention Action',
                  hintText: 'e.g. Parent Call, Counseling, Remedial Session',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Intervention Notes',
                  hintText: 'Describe discussions, action plans, and student commitments...',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Alert Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active Alert')),
                  DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged & Monitoring')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Natural Language Analytics Engine
  // ---------------------------------------------------------------------------

  Future<void> _runNaturalLanguageQuery([String? predefinedQuery]) async {
    final queryText = (predefinedQuery ?? _nlQueryController.text).trim();
    if (queryText.isEmpty) return;
    if (predefinedQuery != null) {
      _nlQueryController.text = predefinedQuery;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loadingNlQuery = true;
      _error = null;
    });

    try {
      final response = await ref.read(apiClientProvider).executeNaturalLanguageQuery(
            session: session,
            query: queryText,
          );
      setState(() => _nlResult = response);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingNlQuery = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Attendance AI Insights Engine (Existing)
  // ---------------------------------------------------------------------------

  Future<void> _generateAttendanceInsights() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loadingAttendance = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).postJson(
        '/api/v1/admin/ai/attendance-insights',
        {
          'startDate': _startDate.text.trim(),
          'endDate': _endDate.text.trim(),
          if (_classId != null) 'classId': _classId,
          if (_sectionId != null) 'sectionId': _sectionId,
        },
        session: session,
      );
      setState(() => _result = response);
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Institutional Intelligence',
          description:
              'Applied predictive AI, early warning student distress alerts, and zero-prompt-leakage natural language queries.',
          primaryAction: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _evaluatingAtRisk ? null : _runRiskEvaluation,
                icon: _evaluatingAtRisk
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(_evaluatingAtRisk ? 'Evaluating...' : 'Evaluate Risk Model'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_error != null) ...[
          FeedbackBanner(
            message: _error!,
            tone: FeedbackTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
        ],

        // Subtabs
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryText,
            unselectedLabelColor: AppColors.secondaryText,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2.5,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.warning_amber_rounded, size: 17),
                text: 'At-Risk Early Warning',
              ),
              Tab(
                icon: Icon(Icons.psychology_rounded, size: 17),
                text: 'Natural Language Queries',
              ),
              Tab(
                icon: Icon(Icons.auto_awesome_outlined, size: 17),
                text: 'Attendance AI Synthesis',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tab Content
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            switch (_tabController.index) {
              case 0:
                return _buildAtRiskTab();
              case 1:
                return _buildNaturalLanguageTab();
              case 2:
                return _buildAttendanceInsightsTab();
              default:
                return _buildAtRiskTab();
            }
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: At-Risk Early Warning UI
  // ---------------------------------------------------------------------------

  Widget _buildAtRiskTab() {
    final criticalCount = _atRiskAlerts.where((a) => a['riskLevel'] == 'critical').length;
    final highCount = _atRiskAlerts.where((a) => a['riskLevel'] == 'high').length;
    final moderateCount = _atRiskAlerts.where((a) => a['riskLevel'] == 'moderate').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI Strip
        StatStrip(
          items: [
            StatItemData(
              label: 'Total Monitored',
              value: '${_atRiskAlerts.length}',
              helper: 'Enrolled students',
            ),
            StatItemData(
              label: 'Critical Risk',
              value: '$criticalCount',
              helper: 'Score ≥ 70',
            ),
            StatItemData(
              label: 'High Risk',
              value: '$highCount',
              helper: 'Score 45 - 69',
            ),
            StatItemData(
              label: 'Moderate',
              value: '$moderateCount',
              helper: 'Score 20 - 44',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _atRiskClassId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Classes')),
                    ...widget.classes.map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String?,
                        child: Text('${c['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _atRiskClassId = val;
                      _atRiskSectionId = null;
                    });
                    _loadAtRiskAlerts();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _atRiskSectionId,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sections')),
                    ...widget.sections
                        .where((s) => _atRiskClassId == null || s['classId'] == _atRiskClassId)
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String?,
                            child: Text('${s['name']}'),
                          ),
                        ),
                  ],
                  onChanged: (val) {
                    setState(() => _atRiskSectionId = val);
                    _loadAtRiskAlerts();
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _atRiskLevel,
                  decoration: const InputDecoration(
                    labelText: 'Risk Level',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Levels')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical Risk')),
                    DropdownMenuItem(value: 'high', child: Text('High Risk')),
                    DropdownMenuItem(value: 'moderate', child: Text('Moderate Risk')),
                    DropdownMenuItem(value: 'low', child: Text('Low Risk')),
                  ],
                  onChanged: (val) {
                    setState(() => _atRiskLevel = val);
                    _loadAtRiskAlerts();
                  },
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _atRiskClassId = null;
                    _atRiskSectionId = null;
                    _atRiskLevel = null;
                    _atRiskStatus = null;
                  });
                  _loadAtRiskAlerts();
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Reset filters'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // List of Alerts
        if (_loadingAtRisk)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_atRiskAlerts.isEmpty)
          const EmptyStateView(
            title: 'No student risk alerts found',
            description:
                'Tap "Evaluate Risk Model" above to calculate multi-factor distress indicators across active cohorts.',
            icon: Icons.verified_user_outlined,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _atRiskAlerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final alert = _atRiskAlerts[index];
              final score = (alert['compositeScore'] as num?)?.toInt() ?? 0;
              final attScore = (alert['attendanceScore'] as num?)?.toInt() ?? 0;
              final acadScore = (alert['academicScore'] as num?)?.toInt() ?? 0;
              final feeScore = (alert['feeScore'] as num?)?.toInt() ?? 0;
              final factors = (alert['factors'] as List?)?.map((e) => '$e').toList() ?? const [];
              final interventions = (alert['interventions'] as List?) ?? const [];
              final status = (alert['status'] as String?) ?? 'active';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color: score >= 70
                        ? AppColors.statusError.withValues(alpha: 0.35)
                        : AppColors.primaryBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    '${alert['studentName'] ?? 'Student'}',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  StatusBadge.riskLevel('${alert['riskLevel']}'),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryBackground,
                                      borderRadius: AppRadii.rSm,
                                      border: Border.all(color: AppColors.primaryBorder),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Class: ${alert['className']} - ${alert['sectionName']}  •  Admission No: ${alert['admissionNumber']}',
                                style: AppTypography.metadata,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: score >= 70
                                        ? AppColors.statusError
                                        : score >= 45
                                            ? AppColors.statusWarning
                                            : AppColors.statusSuccess,
                                  ),
                                ),
                                const Text(
                                  ' / 100',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Composite Risk',
                              style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Factor Metrics Breakdown Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: AppRadii.rSm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _factorItem('Attendance Stress (40%)', '$attScore/100', attScore >= 60),
                          _factorItem('Academic Stress (40%)', '$acadScore/100', acadScore >= 60),
                          _factorItem('Financial Arrears (20%)', '$feeScore/100', feeScore >= 60),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Trigger Factors
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: factors.map((factor) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: AppRadii.rSm,
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, size: 6, color: AppColors.statusWarning),
                              const SizedBox(width: 5),
                              Text(
                                factor,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    if (interventions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Logged Interventions (${interventions.length}):',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...interventions.take(2).map((item) {
                        final i = item as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• ${i['action']} by ${i['staffName']}: "${i['notes']}"',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openInterventionDialog(alert),
                          icon: const Icon(Icons.support_agent_rounded, size: 14),
                          label: const Text('Log Intervention'),
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

  Widget _factorItem(String label, String value, bool isHigh) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isHigh ? AppColors.statusError : AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Natural Language Analytics UI
  // ---------------------------------------------------------------------------

  Widget _buildNaturalLanguageTab() {
    final columns = ((_nlResult?['columns'] as List?) ?? const []).map((c) => '$c').toList();
    final data = ((_nlResult?['data'] as List?) ?? const []).cast<Map<String, Object?>>();
    final followUps = ((_nlResult?['suggestedFollowUps'] as List?) ?? const []).map((f) => '$f').toList();
    final explanation = _nlResult?['explanation'] as String?;
    final intent = _nlResult?['intent'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Query Input Field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 22, color: AppColors.accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Natural Language Database Query Engine',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccess.withValues(alpha: 0.1),
                      borderRadius: AppRadii.rSm,
                      border: Border.all(color: AppColors.statusSuccess.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'ZERO PROMPT LEAKAGE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusSuccess,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nlQueryController,
                      onSubmitted: (_) => _runNaturalLanguageQuery(),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        color: AppColors.primaryText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. List fee defaulters in Grade 7 with dues above ₹5,000...',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.mainBackground,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _nlQueryController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _nlQueryController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _loadingNlQuery ? null : () => _runNaturalLanguageQuery(),
                    icon: _loadingNlQuery
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(_loadingNlQuery ? 'Running...' : 'Run Query'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Starter chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Suggested: ',
                    style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                  ),
                  _starterChip('Fee defaulters with balance > ₹5000'),
                  _starterChip('Classes with low attendance'),
                  _starterChip('Academic toppers in board exams'),
                  _starterChip('Staff on leave and substitute status'),
                  _starterChip('Total student cohort strength'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Result presentation
        if (_loadingNlQuery)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_nlResult == null)
          const EmptyStateView(
            title: 'Ask any institutional query in plain English',
            description:
                'Schoolic parses parameters safely and executes read-only deterministic queries over Neon Postgres without cloud prompt leakage.',
            icon: Icons.chat_bubble_outline_rounded,
          )
        else ...[
          // Explanation & Intent Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'INTENT: ${(intent ?? 'ANALYTICS').toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${data.length} results)',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        explanation ?? 'Institutional records processed successfully.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Follow up chips
          if (followUps.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Recommended Follow-ups: ',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                ),
                ...followUps.map(
                  (f) => ActionChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.arrow_outward_rounded, size: 12),
                    onPressed: () => _runNaturalLanguageQuery(f),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Results Table
          if (data.isEmpty)
            const EmptyStateView(
              title: 'No matching records found for this query threshold',
              description: 'Try querying with a lower amount threshold or broader criteria.',
              icon: Icons.table_rows_outlined,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ClipRRect(
                borderRadius: AppRadii.rMd,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.secondaryBackground),
                  border: TableBorder.all(color: AppColors.primaryBorder),
                  columns: columns
                      .map(
                        (col) => DataColumn(
                          label: Text(
                            col,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: data.map((row) {
                    return DataRow(
                      cells: columns.map((col) {
                        final val = row[col] ?? '—';
                        return DataCell(
                          Text(
                            '$val',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              color: AppColors.primaryText,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _starterChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 11)),
      onPressed: () => _runNaturalLanguageQuery(text),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Attendance AI Synthesis UI (Existing)
  // ---------------------------------------------------------------------------

  Widget _buildAttendanceInsightsTab() {
    final metrics = (_result?['metrics'] as Map?)?.cast<String, Object?>();
    final findings = ((_result?['observedChanges'] as List?) ?? const []).cast<Map<String, Object?>>();
    final followUps = ((_result?['recommendedFollowUp'] as List?) ?? const []).map((e) => '$e').toList();
    final limitations = ((_result?['limitations'] as List?) ?? const []).map((e) => '$e').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filters(),
        const SizedBox(height: 20),
        if (_result == null)
          _emptyState()
        else ...[
          Text('${_result!['overview']}', style: AppTypography.body),
          const SizedBox(height: 18),
          if (metrics != null)
            StatStrip(
              items: [
                StatItemData(label: 'Sessions', value: '${metrics['submittedSessions'] ?? 0}', helper: 'Submitted'),
                StatItemData(label: 'Pending', value: '${metrics['pendingSessions'] ?? 0}', helper: 'From timetable'),
                StatItemData(label: 'Attendance', value: '${metrics['attendancePercentage'] ?? '—'}%', helper: 'Present + late'),
                StatItemData(label: 'Records', value: '${metrics['totalRecords'] ?? 0}', helper: 'Attendance rows'),
              ],
            ),
          const SizedBox(height: 24),
          _section('Observed Changes', findings.map(_findingTile).toList()),
          const SizedBox(height: 20),
          _section('Recommended Follow-up', followUps.map((text) => _textTile(Icons.task_alt_outlined, text)).toList()),
          const SizedBox(height: 20),
          _section('Limitations', limitations.map((text) => _textTile(Icons.info_outline, text)).toList()),
        ],
      ],
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dateField('Start', _startDate),
          _dateField('End', _endDate),
          _select('Class', _classId, widget.classes, (value) => setState(() {
                _classId = value;
                _sectionId = null;
              })),
          _select(
            'Section',
            _sectionId,
            widget.sections.where((section) => _classId == null || section['classId'] == _classId).toList(),
            (value) => setState(() => _sectionId = value),
          ),
          FilledButton.icon(
            onPressed: _loadingAttendance ? null : _generateAttendanceInsights,
            icon: _loadingAttendance
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(_loadingAttendance ? 'Synthesizing...' : 'Generate insights'),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _classId = null;
              _sectionId = null;
            }),
            icon: const Icon(Icons.clear, size: 14),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Widget _select(String label, String? value, List<Map<String, Object?>> options, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String?>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('All $label')),
          ...options.map((option) => DropdownMenuItem<String?>(value: option['id'] as String, child: Text('${option['name']}'))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: const Text(
        'Choose a date range above and tap "Generate insights". Statistical metrics are calculated deterministically by Schoolic before the AI writes recommendations.',
        style: AppTypography.bodySecondary,
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.subsectionHeading),
        const SizedBox(height: 10),
        if (children.isEmpty) const Text('No items returned.', style: AppTypography.bodySecondary) else ...children,
      ],
    );
  }

  Widget _findingTile(Map<String, Object?> finding) {
    final figures = ((finding['supportingFigures'] as List?) ?? const []).map((e) => '$e').toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${finding['title']}', style: AppTypography.bodyMedium),
          const SizedBox(height: 4),
          Text('${finding['observation']}', style: AppTypography.bodySecondary),
          if (figures.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...figures.map((figure) => Text('- $figure', style: AppTypography.metadata)),
          ],
          const SizedBox(height: 8),
          Text('Follow-up: ${finding['followUp']}', style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _textTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodySecondary)),
        ],
      ),
    );
  }
}

String _iso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

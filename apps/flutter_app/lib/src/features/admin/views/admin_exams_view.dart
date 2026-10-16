import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';
import '../utils/report_card_pdf.dart';

class AdminExamsView extends ConsumerStatefulWidget {
  const AdminExamsView({
    required this.exams,
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> exams;
  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final Future<void> Function() reload;

  @override
  ConsumerState<AdminExamsView> createState() => _AdminExamsViewState();
}

class _AdminExamsViewState extends ConsumerState<AdminExamsView> {
  int _selectedTab = 0; // 0: Exams, 1: Grading Schemes, 2: Report Cards

  // Exams Composer State
  final _name = TextEditingController();
  final _examDate = TextEditingController(text: _defaultExamDate());
  final _maxMarks = TextEditingController(text: '100');
  String? _yearId;
  String? _classId;
  String? _sectionId;
  String? _subjectId;
  String _status = 'draft';
  Map<String, Object?>? _editing;
  bool _saving = false;
  String? _error;
  String? _notice;

  // Grading Schemes State
  List<Map<String, Object?>> _schemes = [];
  bool _loadingSchemes = false;

  // Report Cards State
  List<Map<String, Object?>> _reportCards = [];
  bool _loadingReportCards = false;
  String? _filterClassId;
  String? _filterSectionId;
  String _filterTerm = 'all';

  @override
  void initState() {
    super.initState();
    _selectDefaults();
    _loadSchemes();
    _loadReportCards();
  }

  @override
  void didUpdateWidget(covariant AdminExamsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectDefaults();
  }

  @override
  void dispose() {
    _name.dispose();
    _examDate.dispose();
    _maxMarks.dispose();
    super.dispose();
  }

  void _selectDefaults() {
    _yearId ??= widget.years.isEmpty
        ? null
        : widget.years.first['id'] as String?;
    _classId ??= widget.classes.isEmpty
        ? null
        : widget.classes.first['id'] as String?;
    _sectionId ??= _sectionsForClass().isEmpty
        ? null
        : _sectionsForClass().first['id'] as String?;
  }

  List<Map<String, Object?>> _sectionsForClass() {
    return widget.sections
        .where((section) => _classId == null || section['classId'] == _classId)
        .toList();
  }

  Future<void> _loadSchemes() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() => _loadingSchemes = true);
    try {
      final list = await ref.read(apiClientProvider).getGradingSchemes(session: session);
      if (mounted) setState(() => _schemes = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingSchemes = false);
    }
  }

  Future<void> _loadReportCards() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() => _loadingReportCards = true);
    try {
      final list = await ref.read(apiClientProvider).getReportCards(
            session: session,
            classId: _filterClassId,
            sectionId: _filterSectionId,
            term: _filterTerm == 'all' ? null : _filterTerm,
          );
      if (mounted) setState(() => _reportCards = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingReportCards = false);
    }
  }

  Future<void> _seedDefaultSchemes() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() => _loadingSchemes = true);
    try {
      final list = await ref.read(apiClientProvider).seedDefaultBoardSchemes(session: session);
      setState(() {
        _schemes = list;
        _notice = 'Standard CBSE, ICSE, and State Board CCE schemes seeded successfully.';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSchemes = false);
    }
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _saving) return;
    if (_yearId == null || _classId == null || _sectionId == null) {
      setState(() => _error = 'Choose year, class, and section before saving.');
      return;
    }
    final maxMarks = int.tryParse(_maxMarks.text.trim());
    if (_name.text.trim().length < 2 || maxMarks == null) {
      setState(() => _error = 'Add an exam name and numeric max marks.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });

    try {
      final body = {
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        'subjectId': _subjectId,
        'name': _name.text.trim(),
        'examDate': _examDate.text.trim(),
        'maxMarks': maxMarks,
        'status': _status,
      };

      if (_editing == null) {
        await ref
            .read(apiClientProvider)
            .postJson('/api/v1/admin/exams', body, session: session);
        _notice = 'Exam created.';
      } else {
        await ref.read(apiClientProvider).putJson(
              '/api/v1/admin/exams/${_editing!['id']}',
              body,
              session: session,
            );
        _notice = 'Exam updated.';
      }
      _clear();
      await widget.reload();
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, Object?> exam) async {
    final session = ref.read(authControllerProvider).session;
    final id = exam['id'];
    if (session == null || id == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteJson('/api/v1/admin/exams/$id', session: session);
      await widget.reload();
      setState(() => _notice = 'Exam removed.');
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    }
  }

  void _edit(Map<String, Object?> exam) {
    setState(() {
      _editing = exam;
      _yearId = exam['academicYearId'] as String?;
      _classId = exam['classId'] as String?;
      _sectionId = exam['sectionId'] as String?;
      _subjectId = exam['subjectId'] as String?;
      _name.text = exam['name'] as String? ?? '';
      _examDate.text = exam['examDate'] as String? ?? _defaultExamDate();
      _maxMarks.text = '${exam['maxMarks'] ?? 100}';
      _status = exam['status'] as String? ?? 'draft';
      _selectedTab = 0;
    });
  }

  void _clear() {
    _editing = null;
    _name.clear();
    _examDate.text = _defaultExamDate();
    _maxMarks.text = '100';
    _status = 'draft';
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;
    final loc = ref.watch(appLocalizationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: loc.text('academics'),
          description: 'Board-specific grading schemes (CBSE/ICSE/State), evaluation weightages, exams, and printable report cards.',
          secondaryActions: const [
            LanguagePickerDropdown(isCompact: true),
          ],
          primaryAction: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTab == 1)
                FilledButton.tonalIcon(
                  onPressed: _loadingSchemes ? null : _seedDefaultSchemes,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Seed Board Presets'),
                )
              else if (_selectedTab == 2)
                FilledButton.icon(
                  onPressed: _showGenerateReportCardsDialog,
                  icon: const Icon(Icons.post_add, size: 16),
                  label: const Text('Bulk Generate Cards'),
                )
              else
                FilledButton.icon(
                  onPressed: widget.reload,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(loc.text('refresh')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Stats Strip
        StatStrip(
          items: [
            StatItemData(
              label: 'Exams Scheduled',
              value: '${widget.exams.length}',
              helper: 'Active Terms',
            ),
            StatItemData(
              label: 'Grading Schemes',
              value: '${_schemes.length}',
              helper: 'CBSE / ICSE / State',
            ),
            StatItemData(
              label: 'Report Cards',
              value: '${_reportCards.length}',
              helper: 'Generated Records',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Subtabs Navigation
        _buildSubtabsBar(loc),
        const SizedBox(height: 16),

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

        // Active Tab View
        if (_selectedTab == 0) ...[
          _composer(isPhone: isPhone),
          const SizedBox(height: 18),
          if (widget.exams.isEmpty)
            const EmptyStateView(
              title: 'No exams yet',
              description: 'Create exams to open mark entry for teachers.',
              icon: Icons.assignment_outlined,
            )
          else
            ...widget.exams.map(_examCard),
        ] else if (_selectedTab == 1) ...[
          _buildGradingSchemesTab(),
        ] else ...[
          _buildReportCardsTab(),
        ],
      ],
    );
  }

  Widget _buildSubtabsBar(AppLocalizations loc) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(0, 'Exams Schedule (${widget.exams.length})', Icons.assignment),
            _buildTabButton(1, 'Board Schemes & Scales (${_schemes.length})', Icons.grade),
            _buildTabButton(2, 'Official Report Cards (${_reportCards.length})', Icons.receipt_long),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Switzer',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: GRADING SCHEMES & SCALES
  // ---------------------------------------------------------------------------
  Widget _buildGradingSchemesTab() {
    if (_loadingSchemes) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_schemes.isEmpty) {
      return EmptyStateView(
        title: 'No grading schemes configured',
        description: 'Initialize standard CBSE (9-point), ICSE, and State Board CCE frameworks with one click.',
        icon: Icons.grade_outlined,
        actionLabel: 'Seed Board Presets',
        onAction: _seedDefaultSchemes,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _schemes.map(_buildSchemeCard).toList(),
    );
  }

  Widget _buildSchemeCard(Map<String, Object?> scheme) {
    final name = scheme['name'] as String? ?? 'Grading Scheme';
    final board = (scheme['board'] as String? ?? 'cbse').toUpperCase();
    final passPct = scheme['passingPercentage'] ?? 33;
    final isDefault = scheme['isDefault'] == true;
    final scales = (scheme['scales'] as List<dynamic>?) ?? const [];
    final components = (scheme['components'] as List<dynamic>?) ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(
          color: isDefault ? AppColors.accent.withValues(alpha: 0.5) : AppColors.primaryBorder,
        ),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  board,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              if (isDefault)
                const StatusBadge(
                  label: 'Default Board',
                  tone: BadgeTone.success,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Passing Requirement: $passPct% minimum in aggregate and core subjects.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: 12),

          // Evaluation Components
          if (components.isNotEmpty) ...[
            const Text(
              'ASSESSMENT COMPONENTS & WEIGHTAGES',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: components.map((c) {
                final compName = c['name'] ?? '';
                final wt = c['weightagePercentage'] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    '$compName ($wt%)',
                    style: const TextStyle(fontFamily: 'Switzer', fontSize: 12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Grading Scales
          if (scales.isNotEmpty) ...[
            const Text(
              'GRADING SCALE (MARKS TO GRADE POINT)',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scales.map((s) {
                final grade = s['grade'] ?? '';
                final min = s['minScore'] ?? 0;
                final max = s['maxScore'] ?? 100;
                final gp = s['gradePoint'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    '$grade: $min-$max% ($gp GP)',
                    style: const TextStyle(fontFamily: 'Switzer', fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: OFFICIAL REPORT CARDS
  // ---------------------------------------------------------------------------
  Widget _buildReportCardsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterClassId,
                  decoration: const InputDecoration(labelText: 'Filter Class'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Classes')),
                    ...widget.classes.map((c) {
                      return DropdownMenuItem(
                        value: c['id'] as String?,
                        child: Text('${c['name']}'),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterClassId = val;
                      _filterSectionId = null;
                    });
                    _loadReportCards();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterTerm,
                  decoration: const InputDecoration(labelText: 'Term'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Terms')),
                    DropdownMenuItem(value: 'annual', child: Text('Annual Term')),
                    DropdownMenuItem(value: 'term_1', child: Text('Term 1')),
                    DropdownMenuItem(value: 'term_2', child: Text('Term 2')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _filterTerm = val);
                      _loadReportCards();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_loadingReportCards)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reportCards.isEmpty)
          EmptyStateView(
            title: 'No report cards generated',
            description: 'Generate bulk board-formatted report cards for any class and section.',
            icon: Icons.receipt_long_outlined,
            actionLabel: 'Generate Report Cards',
            onAction: _showGenerateReportCardsDialog,
          )
        else
          ..._reportCards.map(_buildReportCardItem),
      ],
    );
  }

  Widget _buildReportCardItem(Map<String, Object?> rc) {
    final id = rc['id'] as String? ?? '';
    final studentName = rc['studentName'] as String? ?? 'Student';
    final admNo = rc['admissionNumber'] as String? ?? '—';
    final className = rc['className'] as String? ?? 'Class';
    final sectionName = rc['sectionName'] as String? ?? 'Section';
    final percentage = rc['overallPercentage'] as String? ?? '0%';
    final grade = rc['overallGrade'] as String? ?? '—';
    final gradePoint = rc['overallGradePoint'] as String?;
    final resultStatus = rc['resultStatus'] as String? ?? 'promoted';
    final isPublished = rc['isPublished'] == true;
    final term = (rc['term'] as String? ?? 'annual').toUpperCase();
    final board = (rc['board'] as String? ?? 'cbse').toUpperCase();
    final attendanceRate = rc['attendancePercentage'] as String? ?? '100%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            foregroundColor: AppColors.accent,
            child: Text(grade, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        board,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: resultStatus.toUpperCase(),
                      tone: resultStatus.toLowerCase().contains('fail') ? BadgeTone.error : BadgeTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Adm No: $admNo | $className — $sectionName | Term: $term | Attendance: $attendanceRate',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  'Aggregate: $percentage | Grade: $grade ${gradePoint != null ? "($gradePoint GP)" : ""}',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: isPublished ? 'Unpublish from Portal' : 'Publish to Student/Parent Portal',
            icon: Icon(
              isPublished ? Icons.visibility : Icons.visibility_off,
              color: isPublished ? AppColors.accent : AppColors.secondaryText,
            ),
            onPressed: () async {
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              await ref.read(apiClientProvider).publishReportCard(
                    reportCardId: id,
                    isPublished: !isPublished,
                    session: session,
                  );
              _loadReportCards();
            },
          ),
          FilledButton.tonalIcon(
            onPressed: () => _printReportCard(rc),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReportCard(Map<String, Object?> rc) async {
    final scholasticData = (rc['scholasticParsed'] as List<dynamic>?)?.cast<Map<String, Object?>>() ??
        const [];
    final coScholasticData = (rc['coScholasticParsed'] as List<dynamic>?)?.cast<Map<String, Object?>>() ??
        const [];

    final pdfData = ReportCardPdfData(
      schoolName: 'Schoolic Model International School',
      schoolAffiliation: 'CBSE Affiliation No. 1930482',
      schoolAddress: '100ft Road, Indiranagar, Bengaluru, Karnataka - 560038',
      studentName: rc['studentName'] as String? ?? 'Student',
      admissionNumber: rc['admissionNumber'] as String? ?? '—',
      rollNumber: rc['rollNumber'] as String?,
      className: rc['className'] as String? ?? 'Class',
      sectionName: rc['sectionName'] as String? ?? 'Section',
      termName: rc['term'] as String? ?? 'Annual',
      schemeName: rc['schemeName'] as String? ?? 'Standard Scheme',
      board: rc['board'] as String? ?? 'CBSE',
      overallPercentage: rc['overallPercentage'] as String? ?? '0%',
      overallGrade: rc['overallGrade'] as String? ?? '—',
      overallGradePoint: rc['overallGradePoint'] as String?,
      attendanceRate: rc['attendancePercentage'] as String? ?? '100%',
      resultStatus: rc['resultStatus'] as String? ?? 'Promoted',
      scholasticRows: scholasticData,
      coScholasticRows: coScholasticData,
      teacherRemarks: rc['teacherRemarks'] as String?,
      principalRemarks: rc['principalRemarks'] as String?,
      issueDate: DateTime.now().toString().split(' ')[0],
    );

    await printOrShareReportCard(pdfData);
  }

  void _showGenerateReportCardsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _GenerateReportCardsDialog(
        years: widget.years,
        classes: widget.classes,
        sections: widget.sections,
        schemes: _schemes,
        onGenerated: () {
          _loadReportCards();
          setState(() {
            _selectedTab = 2;
            _notice = 'Report cards successfully generated and ready for preview/printing.';
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXISTING EXAMS SCHEDULER WIDGETS
  // ---------------------------------------------------------------------------
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing == null ? 'Schedule an Exam' : 'Edit Exam Shell',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_editing != null)
                TextButton(
                  onPressed: () => setState(_clear),
                  child: const Text('Cancel Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isPhone ? double.infinity : 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _yearId,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: widget.years.map((y) {
                    return DropdownMenuItem(
                      value: y['id'] as String,
                      child: Text('${y['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _yearId = val),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classes.map((c) {
                    return DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _classId = val;
                      final secs = _sectionsForClass();
                      _sectionId = secs.isEmpty ? null : secs.first['id'] as String?;
                    });
                  },
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _sectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: _sectionsForClass().map((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _sectionId = val),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 200,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _subjectId,
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('General / All')),
                    ...widget.subjects.map((sub) {
                      return DropdownMenuItem(
                        value: sub['id'] as String?,
                        child: Text('${sub['name']}'),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _subjectId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isPhone ? double.infinity : 280,
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Exam Title',
                    hintText: 'Mid-Term Physics, Annual Mathematics',
                  ),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 160,
                child: TextField(
                  controller: _examDate,
                  decoration: const InputDecoration(
                    labelText: 'Exam Date',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 120,
                child: TextField(
                  controller: _maxMarks,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Marks'),
                ),
              ),
              SizedBox(
                width: isPhone ? double.infinity : 160,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'published', child: Text('Published')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(_editing == null ? 'Schedule Exam' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examCard(Map<String, Object?> exam) {
    final name = exam['name'] as String? ?? 'Untitled';
    final date = exam['examDate'] as String? ?? '';
    final maxMarks = exam['maxMarks'] ?? 100;
    final status = exam['status'] as String? ?? 'draft';
    final subject = exam['subjectName'] as String? ?? 'General';
    final cls = exam['className'] ?? '';
    final sec = exam['sectionName'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
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
                        fontFamily: 'Switzer',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: status.toUpperCase(),
                      tone: status == 'published'
                          ? BadgeTone.success
                          : status == 'archived'
                              ? BadgeTone.neutral
                              : BadgeTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: $date | Subject: $subject | $cls — $sec | Max Marks: $maxMarks',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit exam',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _edit(exam),
          ),
          IconButton(
            tooltip: 'Delete exam',
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.statusError),
            onPressed: () => _delete(exam),
          ),
        ],
      ),
    );
  }

  static String _defaultExamDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// -----------------------------------------------------------------------------
// Bulk Generate Report Cards Modal Dialog
// -----------------------------------------------------------------------------
class _GenerateReportCardsDialog extends ConsumerStatefulWidget {
  const _GenerateReportCardsDialog({
    required this.years,
    required this.classes,
    required this.sections,
    required this.schemes,
    required this.onGenerated,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> schemes;
  final VoidCallback onGenerated;

  @override
  ConsumerState<_GenerateReportCardsDialog> createState() =>
      _GenerateReportCardsDialogState();
}

class _GenerateReportCardsDialogState
    extends ConsumerState<_GenerateReportCardsDialog> {
  String? _yearId;
  String? _classId;
  String? _sectionId;
  String? _schemeId;
  String _term = 'annual';
  final _remarks = TextEditingController(
    text: 'Good academic performance and regular participation.',
  );
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.years.isNotEmpty) _yearId = widget.years.first['id'] as String?;
    if (widget.classes.isNotEmpty) _classId = widget.classes.first['id'] as String?;
    final secs = _sectionsForClass();
    if (secs.isNotEmpty) _sectionId = secs.first['id'] as String?;
    if (widget.schemes.isNotEmpty) _schemeId = widget.schemes.first['id'] as String?;
  }

  List<Map<String, Object?>> _sectionsForClass() {
    return widget.sections
        .where((s) => _classId == null || s['classId'] == _classId)
        .toList();
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null || _generating) return;
    if (_yearId == null || _classId == null || _sectionId == null || _schemeId == null) {
      setState(() => _error = 'Please select academic year, class, section, and grading scheme.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).generateReportCards(
            session: session,
            academicYearId: _yearId!,
            classId: _classId!,
            sectionId: _sectionId!,
            schemeId: _schemeId!,
            term: _term,
            teacherRemarks: _remarks.text.trim(),
          );
      widget.onGenerated();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Bulk Generate Report Cards',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _generating ? null : _submit,
          icon: _generating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Generate Cards'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            FeedbackBanner(
              message: _error!,
              tone: FeedbackTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _yearId,
            decoration: const InputDecoration(labelText: 'Academic Year'),
            items: widget.years.map((y) {
              return DropdownMenuItem(
                value: y['id'] as String,
                child: Text('${y['name']}'),
              );
            }).toList(),
            onChanged: (val) => setState(() => _yearId = val),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: widget.classes.map((c) {
                    return DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _classId = val;
                      final secs = _sectionsForClass();
                      _sectionId = secs.isEmpty ? null : secs.first['id'] as String?;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: _sectionsForClass().map((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text('${s['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _sectionId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _schemeId,
            decoration: const InputDecoration(labelText: 'Grading Scheme & Board'),
            items: widget.schemes.map((s) {
              final b = (s['board'] ?? 'CBSE').toString().toUpperCase();
              return DropdownMenuItem(
                value: s['id'] as String,
                child: Text('${s['name']} ($b)'),
              );
            }).toList(),
            onChanged: (val) => setState(() => _schemeId = val),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _term,
            decoration: const InputDecoration(labelText: 'Academic Term'),
            items: const [
              DropdownMenuItem(value: 'annual', child: Text('Annual Term (Full Year)')),
              DropdownMenuItem(value: 'term_1', child: Text('Term 1 (Half Yearly)')),
              DropdownMenuItem(value: 'term_2', child: Text('Term 2')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _term = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarks,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'General Faculty Remarks',
              hintText: 'Overall assessment remarks for student cohort',
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';

class AdminInsightsView extends ConsumerStatefulWidget {
  const AdminInsightsView({
    required this.classes,
    required this.sections,
    super.key,
  });

  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;

  @override
  ConsumerState<AdminInsightsView> createState() => _AdminInsightsViewState();
}

class _AdminInsightsViewState extends ConsumerState<AdminInsightsView> {
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  String? _classId;
  String? _sectionId;
  bool _loading = false;
  String? _error;
  Map<String, Object?>? _result;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate.text = _iso(now);
    _startDate.text = _iso(now.subtract(const Duration(days: 13)));
  }

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() {
      _loading = true;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = (_result?['metrics'] as Map?)?.cast<String, Object?>();
    final findings = ((_result?['observedChanges'] as List?) ?? const []).cast<Map<String, Object?>>();
    final followUps = ((_result?['recommendedFollowUp'] as List?) ?? const []).map((e) => '$e').toList();
    final limitations = ((_result?['limitations'] as List?) ?? const []).map((e) => '$e').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Insights',
          description: 'AI-assisted attendance analysis grounded in verified Schoolic records.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(_loading ? 'Generating...' : 'Generate insights'),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          FeedbackBanner(
            message: _error!,
            tone: FeedbackTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
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
      width: 150,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _select(String label, String? value, List<Map<String, Object?>> options, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
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
        'Choose a range and generate insights. Counts are calculated by Schoolic before the AI writes recommendations.',
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

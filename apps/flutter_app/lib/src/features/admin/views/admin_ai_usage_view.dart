import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';

class AdminAiUsageView extends ConsumerStatefulWidget {
  const AdminAiUsageView({super.key});

  @override
  ConsumerState<AdminAiUsageView> createState() => _AdminAiUsageViewState();
}

class _AdminAiUsageViewState extends ConsumerState<AdminAiUsageView> {
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  Map<String, Object?>? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate.text = DateFormat('yyyy-MM-dd').format(now);
    _startDate.text = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 13)));
    _load();
  }

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
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
      final query = Uri(queryParameters: {
        if (_startDate.text.trim().isNotEmpty) 'startDate': _startDate.text.trim(),
        if (_endDate.text.trim().isNotEmpty) 'endDate': _endDate.text.trim(),
      }).query;
      final response = await ref.read(apiClientProvider).getJson('/api/v1/admin/ai/usage?$query', session: session);
      setState(() => _summary = response);
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = ((_summary?['totals'] as Map?) ?? const {}).cast<String, Object?>();
    final byFeature = ((_summary?['byFeature'] as List?) ?? const []).cast<Map<String, Object?>>();
    final byGeneration = ((_summary?['byGenerationType'] as List?) ?? const []).cast<Map<String, Object?>>();
    final daily = ((_summary?['daily'] as List?) ?? const []).cast<Map<String, Object?>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'AI Usage',
          description: 'Monitor Schoolic AI activity, failures, token availability, and response time.',
          primaryAction: FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16),
            label: Text(_loading ? 'Loading...' : 'Refresh'),
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
        const SizedBox(height: 18),
        if (_summary == null)
          const Text('No usage data loaded.', style: AppTypography.bodySecondary)
        else ...[
          StatStrip(
            items: [
              StatItemData(label: 'Requests', value: '${totals['requests'] ?? 0}', helper: 'Total'),
              StatItemData(label: 'Success', value: '${totals['successes'] ?? 0}', helper: 'Completed'),
              StatItemData(label: 'Failures', value: '${totals['failures'] ?? 0}', helper: 'Provider or validation'),
              StatItemData(label: 'Avg latency', value: _ms(totals['averageLatencyMs']), helper: 'Successful + failed'),
            ],
          ),
          const SizedBox(height: 18),
          StatStrip(
            items: [
              StatItemData(label: 'Input tokens', value: _numberOrUnknown(totals['inputTokens']), helper: 'Provider reported'),
              StatItemData(label: 'Output tokens', value: _numberOrUnknown(totals['outputTokens']), helper: 'Provider reported'),
              StatItemData(label: 'Total tokens', value: _numberOrUnknown(totals['totalTokens']), helper: 'Unknown if unavailable'),
              StatItemData(label: 'Limited', value: '${totals['limited'] ?? 0}', helper: 'Quota responses'),
            ],
          ),
          const SizedBox(height: 24),
          _usageTable('By Feature', byFeature, const ['feature', 'requests', 'successes', 'failures', 'totalTokens']),
          const SizedBox(height: 18),
          _usageTable('By Generation Type', byGeneration, const ['generationType', 'requests', 'successes', 'failures']),
          const SizedBox(height: 18),
          _usageTable('Daily Activity', daily, const ['date', 'requests', 'successes', 'failures']),
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
          SizedBox(width: 150, child: TextField(controller: _startDate, decoration: const InputDecoration(labelText: 'Start'))),
          SizedBox(width: 150, child: TextField(controller: _endDate, decoration: const InputDecoration(labelText: 'End'))),
          TextButton.icon(onPressed: _load, icon: const Icon(Icons.filter_alt_outlined, size: 16), label: const Text('Apply')),
        ],
      ),
    );
  }

  Widget _usageTable(String title, List<Map<String, Object?>> rows, List<String> keys) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.subsectionHeading),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text('No activity in this range.', style: AppTypography.bodySecondary)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: AppTypography.metadata,
                dataTextStyle: AppTypography.body,
                columns: keys.map((key) => DataColumn(label: Text(_label(key)))).toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: keys.map((key) => DataCell(Text(_format(row[key])))).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _numberOrUnknown(Object? value) => value == null ? 'Unknown' : '$value';

  String _ms(Object? value) => value == null ? 'Unknown' : '${value}ms';

  String _format(Object? value) => value == null ? 'Unknown' : '$value';

  String _label(String key) {
    return switch (key) {
      'generationType' => 'Generation Type',
      'totalTokens' => 'Total Tokens',
      _ => key[0].toUpperCase() + key.substring(1),
    };
  }
}

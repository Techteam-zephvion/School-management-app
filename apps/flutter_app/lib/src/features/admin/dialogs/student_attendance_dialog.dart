import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/status_badge.dart';

class StudentAttendanceDialog extends ConsumerStatefulWidget {
  const StudentAttendanceDialog({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  final String studentId;
  final String studentName;

  @override
  ConsumerState<StudentAttendanceDialog> createState() => _StudentAttendanceDialogState();
}

class _StudentAttendanceDialogState extends ConsumerState<StudentAttendanceDialog> {
  bool _loading = true;
  String? _error;
  Map<String, Object?>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ref.read(apiClientProvider).getJson(
            '/api/v1/admin/students/${widget.studentId}/attendance-summary',
            session: session,
          );
      setState(() => _data = res);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = ((_data?['records'] as List?) ?? const []).cast<Map<String, Object?>>();
    final rate = _data?['attendanceRate'] != null ? '${_data!['attendanceRate']}%' : '—';
    final total = _data?['totalSessions']?.toString() ?? '0';
    final present = _data?['presentCount']?.toString() ?? '0';
    final absent = _data?['absentCount']?.toString() ?? '0';
    final lateCount = _data?['lateCount']?.toString() ?? '0';
    final excused = _data?['excusedCount']?.toString() ?? '0';

    return AppDialog(
      title: widget.studentName,
      subtitle: 'Attendance history and compliance rate.',
      maxWidth: 620,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryText),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: AppColors.statusError)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Attendance metrics summary strip
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: AppRadii.rMd,
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _buildMetric('RATE', rate, AppColors.accent),
                          _buildMetric('TOTAL SESSIONS', total, AppColors.primaryText),
                          _buildMetric('PRESENT', present, AppColors.statusSuccess),
                          _buildMetric('ABSENT', absent, AppColors.statusError),
                          _buildMetric('LATE', lateCount, AppColors.statusWarning),
                          _buildMetric('EXCUSED', excused, AppColors.statusInfo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recorded session records
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recorded Sessions', style: AppTypography.subsectionHeading),
                        Text('${records.length} logged', style: AppTypography.metadata),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (records.isEmpty)
                      const EmptyStateView(
                        title: 'No attendance records',
                        description: 'This student does not have any recorded sessions yet.',
                        icon: Icons.history_outlined,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryBorder),
                          borderRadius: AppRadii.rMd,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: records.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                          itemBuilder: (context, index) {
                            final r = records[index];
                            final statusStr = '${r['status'] ?? ''}';

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text('${r['date'] ?? ''}', style: AppTypography.compactTable),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['className'] ?? ''} - ${r['sectionName'] ?? ''}',
                                          style: AppTypography.compactTableMedium,
                                        ),
                                        Text(
                                          '${r['kind'] ?? 'daily'}'.toUpperCase(),
                                          style: AppTypography.metadata,
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge.fromStatusString(statusStr),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

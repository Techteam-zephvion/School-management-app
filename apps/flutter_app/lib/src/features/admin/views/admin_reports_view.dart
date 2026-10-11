import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';

class AdminReportsView extends StatelessWidget {
  const AdminReportsView({
    required this.summaries,
    required this.students,
    required this.classes,
    required this.onExportCsv,
    super.key,
  });

  final List<Map<String, Object?>> summaries;
  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> classes;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Reports & Export',
          description: 'Institutional compliance reporting and spreadsheet data export.',
          primaryAction: FilledButton.icon(
            onPressed: summaries.isEmpty ? null : onExportCsv,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export Full Attendance CSV'),
          ),
        ),
        const SizedBox(height: 20),

        StatStrip(
          items: [
            StatItemData(
              label: 'Total Logged Sessions',
              value: '${summaries.length}',
              helper: 'Historical records',
            ),
            StatItemData(
              label: 'Enrolled Learners',
              value: '${students.length}',
              helper: 'Active students',
            ),
            StatItemData(
              label: 'Registered Cohorts',
              value: '${classes.length}',
              helper: 'All grades',
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Specifications', style: AppTypography.subsectionHeading),
              const SizedBox(height: 8),
              const Text(
                'Attendance records can be downloaded in Comma-Separated Values (CSV) format. '
                'All values are sanitized against spreadsheet formula injection (CWE-1236) '
                'for compliance with external data processors and auditing bodies.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: summaries.isEmpty ? null : onExportCsv,
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('Download CSV dataset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

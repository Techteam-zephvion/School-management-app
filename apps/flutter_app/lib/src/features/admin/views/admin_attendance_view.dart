import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/status_badge.dart';

class AdminAttendanceView extends StatelessWidget {
  const AdminAttendanceView({
    required this.summaries,
    required this.classes,
    required this.sections,
    required this.selectedClassId,
    required this.selectedSectionId,
    required this.startDateController,
    required this.endDateController,
    required this.onClassChanged,
    required this.onSectionChanged,
    required this.onFilter,
    required this.onReset,
    required this.onExportCsv,
    super.key,
  });

  final List<Map<String, Object?>> summaries;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final String? selectedClassId;
  final String? selectedSectionId;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onSectionChanged;
  final VoidCallback onFilter;
  final VoidCallback onReset;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final filteredSections = selectedClassId == null || selectedClassId!.isEmpty
        ? sections
        : sections.where((s) => s['classId'] == selectedClassId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Attendance Register',
          description: 'Historical records, daily logs, and period attendance audits.',
          primaryAction: FilledButton.icon(
            onPressed: summaries.isEmpty ? null : onExportCsv,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export CSV'),
          ),
        ),
        const SizedBox(height: 20),

        // Filter toolbar container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
                    ...classes.map(
                      (c) => DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['name']}')),
                    ),
                  ],
                  onChanged: onClassChanged,
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('sec_$selectedClassId'),
                  isExpanded: true,
                  initialValue: selectedSectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
                    ...filteredSections.map(
                      (s) => DropdownMenuItem<String?>(value: s['id'] as String, child: Text('${s['name']}')),
                    ),
                  ],
                  onChanged: onSectionChanged,
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: startDateController,
                  decoration: InputDecoration(
                    labelText: 'From Date',
                    hintText: 'yyyy-MM-dd',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: endDateController,
                  decoration: InputDecoration(
                    labelText: 'To Date',
                    hintText: 'yyyy-MM-dd',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onFilter,
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('Apply'),
              ),
              OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Attendance Table
        AppTable<Map<String, Object?>>(
          title: 'Recorded Sessions',
          subtitle: 'Filtered by selection criteria',
          items: summaries,
          count: summaries.length,
          emptyMessage: 'No attendance records match the selected filters.',
          filterPredicate: (row, query) {
            final cls = '${row['className'] ?? ''}'.toLowerCase();
            final sec = '${row['sectionName'] ?? ''}'.toLowerCase();
            final staff = '${row['staffName'] ?? ''}'.toLowerCase();
            final date = '${row['attendanceDate'] ?? ''}'.toLowerCase();
            return cls.contains(query) || sec.contains(query) || staff.contains(query) || date.contains(query);
          },
          searchHint: 'Filter by date, class, teacher...',
          columns: [
            AppTableColumn(
              header: 'Date',
              width: 110,
              cellBuilder: (context, row) => Text('${row['attendanceDate'] ?? '—'}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Cohort',
              flex: 2,
              cellBuilder: (context, row) => Text(
                '${row['className'] ?? ''} - ${row['sectionName'] ?? ''}',
                style: AppTypography.compactTableMedium,
              ),
            ),
            AppTableColumn(
              header: 'Kind',
              width: 90,
              cellBuilder: (context, row) => StatusBadge.fromStatusString('${row['kind'] ?? 'daily'}'),
            ),
            AppTableColumn(
              header: 'Period',
              width: 80,
              cellBuilder: (context, row) => Text(
                row['periodNumber'] != null ? 'Period ${row['periodNumber']}' : 'Daily',
                style: AppTypography.compactTable,
              ),
            ),
            AppTableColumn(
              header: 'Logged By',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['staffName'] ?? 'Faculty'}', style: AppTypography.compactTable),
            ),
          ],
        ),
      ],
    );
  }
}

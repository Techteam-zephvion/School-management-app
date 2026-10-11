import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/page_header.dart';

class AdminStudentsView extends StatelessWidget {
  const AdminStudentsView({
    required this.students,
    required this.onOpenAddStudent,
    required this.onOpenStudentProfile,
    super.key,
  });

  final List<Map<String, Object?>> students;
  final VoidCallback onOpenAddStudent;
  final void Function(Map<String, Object?> student) onOpenStudentProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Students Directory',
          description: 'Enrolled learners across all grades. Select any student to view their attendance profile.',
          primaryAction: FilledButton.icon(
            onPressed: onOpenAddStudent,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add student'),
          ),
        ),
        const SizedBox(height: 20),

        AppTable<Map<String, Object?>>(
          title: 'Enrolled Students',
          subtitle: 'Click any row for complete attendance metrics',
          items: students,
          count: students.length,
          emptyMessage: 'No students enrolled yet. Click "Add student" to begin.',
          onRowTap: onOpenStudentProfile,
          filterPredicate: (student, query) {
            final name = '${student['fullName'] ?? ''}'.toLowerCase();
            final adm = '${student['admissionNumber'] ?? ''}'.toLowerCase();
            final roll = '${student['rollNumber'] ?? ''}'.toLowerCase();
            return name.contains(query) || adm.contains(query) || roll.contains(query);
          },
          searchHint: 'Search by name, admission no...',
          columns: [
            AppTableColumn(
              header: 'Admission No.',
              width: 160,
              cellBuilder: (context, s) => Text(
                '${s['admissionNumber'] ?? '—'}',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            AppTableColumn(
              header: 'Full Name',
              flex: 3,
              cellBuilder: (context, s) => Text(
                '${s['fullName'] ?? '—'}',
                style: AppTypography.compactTableMedium,
              ),
            ),
            AppTableColumn(
              header: 'Roll No.',
              width: 100,
              cellBuilder: (context, s) => Text(
                '${s['rollNumber'] ?? '—'}',
                style: AppTypography.compactTable,
              ),
            ),
            AppTableColumn(
              header: 'Profile',
              width: 110,
              alignment: Alignment.centerRight,
              cellBuilder: (context, s) => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'History',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.mutedText),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

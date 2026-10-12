import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/page_header.dart';

class AdminStudentsView extends StatefulWidget {
  const AdminStudentsView({
    required this.students,
    required this.classes,
    required this.sections,
    required this.onOpenAddStudent,
    required this.onOpenStudentProfile,
    super.key,
  });

  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final VoidCallback onOpenAddStudent;
  final void Function(Map<String, Object?> student) onOpenStudentProfile;

  @override
  State<AdminStudentsView> createState() => _AdminStudentsViewState();
}

class _AdminStudentsViewState extends State<AdminStudentsView> {
  String? _selectedClassId;
  String? _selectedSectionId;

  String _cohortLabel(Map<String, Object?> student) {
    final classId = student['classId'] as String?;
    final sectionId = student['sectionId'] as String?;
    final classNameDirect = student['className'] as String?;
    final sectionNameDirect = student['sectionName'] as String?;

    final className = (classNameDirect != null && classNameDirect.isNotEmpty)
        ? classNameDirect
        : widget.classes.cast<Map<String, Object?>?>().firstWhere(
            (c) => c?['id'] == classId,
            orElse: () => null,
          )?['name'] as String?;

    final sectionName = (sectionNameDirect != null && sectionNameDirect.isNotEmpty)
        ? sectionNameDirect
        : widget.sections.cast<Map<String, Object?>?>().firstWhere(
            (s) => s?['id'] == sectionId,
            orElse: () => null,
          )?['name'] as String?;

    if (className != null && className.trim().isNotEmpty && sectionName != null && sectionName.trim().isNotEmpty) {
      return '$className - $sectionName';
    } else if (className != null && className.trim().isNotEmpty) {
      return className;
    } else if (sectionName != null && sectionName.trim().isNotEmpty) {
      return 'Section $sectionName';
    }
    return 'Unassigned';
  }

  @override
  Widget build(BuildContext context) {
    final availableSections = _selectedClassId == null || _selectedClassId!.isEmpty
        ? widget.sections
        : widget.sections.where((s) => s['classId'] == _selectedClassId).toList();

    final filteredStudents = widget.students.where((student) {
      if (_selectedClassId != null && _selectedClassId!.isNotEmpty) {
        if (student['classId'] != _selectedClassId) return false;
      }
      if (_selectedSectionId != null && _selectedSectionId!.isNotEmpty) {
        if (student['sectionId'] != _selectedSectionId) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Students Directory',
          description: 'Enrolled learners across all grades. Select any student to view their attendance profile.',
          primaryAction: FilledButton.icon(
            onPressed: widget.onOpenAddStudent,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add student'),
          ),
        ),
        const SizedBox(height: 20),

        // Filter toolbar container
        Container(
          padding: const EdgeInsets.all(14),
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
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
                    ...widget.classes.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c['id'] as String?,
                        child: Text(c['name'] as String? ?? 'Class'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClassId = val;
                      if (_selectedSectionId != null) {
                        final sectionBelongs = widget.sections.any(
                          (s) => s['id'] == _selectedSectionId && (val == null || s['classId'] == val),
                        );
                        if (!sectionBelongs) {
                          _selectedSectionId = null;
                        }
                      }
                    });
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _selectedSectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
                    ...availableSections.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s['id'] as String?,
                        child: Text(s['name'] as String? ?? 'Section'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSectionId = val),
                ),
              ),
              if (_selectedClassId != null || _selectedSectionId != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedClassId = null;
                    _selectedSectionId = null;
                  }),
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Reset filters'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        AppTable<Map<String, Object?>>(
          title: 'Enrolled Students',
          subtitle: 'Click any row for complete attendance metrics',
          items: filteredStudents,
          count: filteredStudents.length,
          emptyMessage: _selectedClassId != null || _selectedSectionId != null
              ? 'No students found matching the selected class and section filters.'
              : 'No students enrolled yet. Click "Add student" to begin.',
          onRowTap: widget.onOpenStudentProfile,
          filterPredicate: (student, query) {
            final name = '${student['fullName'] ?? ''}'.toLowerCase();
            final adm = '${student['admissionNumber'] ?? ''}'.toLowerCase();
            final roll = '${student['rollNumber'] ?? ''}'.toLowerCase();
            final cohort = _cohortLabel(student).toLowerCase();
            return name.contains(query) || adm.contains(query) || roll.contains(query) || cohort.contains(query);
          },
          searchHint: 'Search by name, admission no, cohort...',
          columns: [
            AppTableColumn(
              header: 'Admission No.',
              width: 140,
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
              header: 'Class & Section',
              width: 160,
              cellBuilder: (context, s) {
                final label = _cohortLabel(s);
                final isUnassigned = label == 'Unassigned';
                return Text(
                  label,
                  style: isUnassigned
                      ? const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          color: AppColors.mutedText,
                          fontStyle: FontStyle.italic,
                        )
                      : AppTypography.compactTableMedium,
                );
              },
            ),
            AppTableColumn(
              header: 'Roll No.',
              width: 90,
              cellBuilder: (context, s) => Text(
                '${s['rollNumber'] ?? '—'}',
                style: AppTypography.compactTable,
              ),
            ),
            AppTableColumn(
              header: 'Profile',
              width: 100,
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

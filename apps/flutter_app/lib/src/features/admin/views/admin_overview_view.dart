import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminOverviewView extends StatelessWidget {
  const AdminOverviewView({
    required this.students,
    required this.staff,
    required this.classes,
    required this.sections,
    required this.assignments,
    required this.summaries,
    required this.activeYearName,
    required this.onNavigateToSection,
    required this.onOpenAddStudent,
    required this.onOpenAddStaff,
    super.key,
  });

  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> staff;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> assignments;
  final List<Map<String, Object?>> summaries;
  final String activeYearName;
  final ValueChanged<String> onNavigateToSection;
  final VoidCallback onOpenAddStudent;
  final VoidCallback onOpenAddStaff;

  @override
  Widget build(BuildContext context) {
    final nowFormatted = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Calculate real dynamic attention items
    final todaySessionSectionIds = summaries
        .where((s) => s['attendanceDate'] == todayIso)
        .map((s) => s['sectionId'] as String?)
        .whereType<String>()
        .toSet();

    final unrecordedSections = sections
        .where((sec) => !todaySessionSectionIds.contains(sec['id']))
        .toList();

    final assignedSectionIds = assignments
        .map((a) => a['sectionId'] as String?)
        .whereType<String>()
        .toSet();

    final unassignedSections = sections
        .where((sec) => !assignedSectionIds.contains(sec['id']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Overview',
          description: 'Your school at a glance • $nowFormatted',
          primaryAction: FilledButton.icon(
            onPressed: onOpenAddStudent,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add student'),
          ),
          secondaryActions: [
            OutlinedButton(
              onPressed: onOpenAddStaff,
              child: const Text('Add staff'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Typographic statistics strip
        StatStrip(
          items: [
            StatItemData(
              label: 'Total Students',
              value: '${students.length}',
              helper: 'Enrolled learners',
            ),
            StatItemData(
              label: 'Teaching Staff',
              value: '${staff.length}',
              helper: 'Active faculty',
            ),
            StatItemData(
              label: 'Classes & Cohorts',
              value: '${classes.length}',
              helper: '${sections.length} active sections',
            ),
            StatItemData(
              label: 'Total Recorded Sessions',
              value: '${summaries.length}',
              helper: '${todaySessionSectionIds.length} logged today',
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Operational Attention Section (calculated dynamically)
        _buildOperationalAttention(unrecordedSections, unassignedSections),
        const SizedBox(height: 28),

        // Recent Attendance Table
        AppTable<Map<String, Object?>>(
          title: 'Recent Attendance Sessions',
          subtitle: 'Latest attendance activity across cohorts',
          items: summaries.take(6).toList(),
          emptyMessage: 'No attendance sessions logged yet.',
          actions: [
            TextButton(
              onPressed: () => onNavigateToSection('attendance'),
              child: const Text('View register →', style: TextStyle(fontSize: 13, color: AppColors.primaryText)),
            ),
          ],
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
                row['periodNumber'] != null ? 'P${row['periodNumber']}' : 'Daily',
                style: AppTypography.compactTable,
              ),
            ),
            AppTableColumn(
              header: 'Staff',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['staffName'] ?? 'Faculty'}', style: AppTypography.compactTable),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Quick Workflows
        _buildQuickAccess(),
      ],
    );
  }

  String _cohortLabel(Map<String, Object?> section) {
    final classId = section['classId'] as String?;
    final sectionName = (section['name'] as String?)?.trim();
    final matchingClass = classes.cast<Map<String, Object?>?>().firstWhere(
      (c) => c?['id'] == classId,
      orElse: () => null,
    );
    final className = (matchingClass?['name'] as String?)?.trim();
    if (className != null && className.isNotEmpty && sectionName != null && sectionName.isNotEmpty) {
      return '$className - $sectionName';
    } else if (className != null && className.isNotEmpty) {
      return className;
    } else if (sectionName != null && sectionName.isNotEmpty) {
      return 'Section $sectionName';
    }
    return 'Unassigned Cohort';
  }

  Widget _buildOperationalAttention(
    List<Map<String, Object?>> unrecordedSections,
    List<Map<String, Object?>> unassignedSections,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Operational Attention', style: AppTypography.subsectionHeading),
            const SizedBox(width: 8),
            if (unrecordedSections.isNotEmpty || unassignedSections.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.1),
                  borderRadius: AppRadii.rSm,
                  border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${unrecordedSections.length + unassignedSections.length} PENDING',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusWarning,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            children: [
              if (unrecordedSections.isNotEmpty) ...[
                _attentionTile(
                  icon: Icons.schedule_outlined,
                  title: 'Daily Attendance Pending (${unrecordedSections.length} sections)',
                  subtitle: '${unrecordedSections.map(_cohortLabel).take(4).join(', ')}${unrecordedSections.length > 4 ? '...' : ''} have not logged attendance today.',
                  actionLabel: 'Check register →',
                  onTap: () => onNavigateToSection('attendance'),
                  isAlert: true,
                ),
                const Divider(height: 1, color: AppColors.primaryBorder),
              ],
              if (unassignedSections.isNotEmpty) ...[
                _attentionTile(
                  icon: Icons.assignment_ind_outlined,
                  title: 'Unassigned Sections (${unassignedSections.length} cohorts)',
                  subtitle: '${unassignedSections.map(_cohortLabel).take(4).join(', ')}${unassignedSections.length > 4 ? '...' : ''} without an active assigned teacher mapping.',
                  actionLabel: 'Assign faculty →',
                  onTap: () => onNavigateToSection('assignments'),
                  isAlert: true,
                ),
                const Divider(height: 1, color: AppColors.primaryBorder),
              ],
              if (unrecordedSections.isEmpty && unassignedSections.isEmpty) ...[
                _attentionTile(
                  icon: Icons.verified_outlined,
                  title: 'All Active Systems Current',
                  subtitle: 'All cohort teacher assignments mapped and attendance logging is active.',
                  actionLabel: 'Review reports →',
                  onTap: () => onNavigateToSection('reports'),
                  isAlert: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _attentionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    required bool isAlert,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isAlert ? AppColors.statusWarning : AppColors.secondaryText,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodySecondary),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access Workflows', style: AppTypography.subsectionHeading),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _quickTile('Manage Students', Icons.people_outline, () => onNavigateToSection('students')),
            _quickTile('Manage Staff', Icons.badge_outlined, () => onNavigateToSection('staff')),
            _quickTile('Configure Classes & Curricula', Icons.layers_outlined, () => onNavigateToSection('classes')),
            _quickTile('Teacher Allocations', Icons.assignment_ind_outlined, () => onNavigateToSection('assignments')),
            _quickTile('Compliance Reports & CSV', Icons.analytics_outlined, () => onNavigateToSection('reports')),
          ],
        ),
      ],
    );
  }

  Widget _quickTile(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.mainBackground,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: AppRadii.rMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.bodyMedium),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 12, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}

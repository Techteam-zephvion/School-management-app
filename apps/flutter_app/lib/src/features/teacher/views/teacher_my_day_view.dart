import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class TeacherMyDayView extends StatelessWidget {
  const TeacherMyDayView({
    required this.assignments,
    required this.recentSessions,
    required this.teacherEmail,
    required this.onSelectAssignmentAndTakeAttendance,
    required this.onNavigateToRegister,
    super.key,
  });

  final List<Map<String, Object?>> assignments;
  final List<Map<String, Object?>> recentSessions;
  final String teacherEmail;
  final void Function(Map<String, Object?> assignment) onSelectAssignmentAndTakeAttendance;
  final VoidCallback onNavigateToRegister;

  @override
  Widget build(BuildContext context) {
    final nowFormatted = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Calculate completed vs pending sections today
    final todaySessionSectionIds = recentSessions
        .where((s) => s['attendanceDate'] == todayIso)
        .map((s) => s['sectionId'] as String?)
        .whereType<String>()
        .toSet();

    final pendingAssignments = assignments
        .where((a) => !todaySessionSectionIds.contains(a['sectionId']))
        .toList();

    final completedAssignments = assignments
        .where((a) => todaySessionSectionIds.contains(a['sectionId']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'My Day',
          description: '$nowFormatted • Daily teaching briefing for $teacherEmail',
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rSm,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Text(
              'TEACHER',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          primaryAction: FilledButton.icon(
            onPressed: assignments.isEmpty
                ? null
                : () {
                    final nextPending = pendingAssignments.isNotEmpty ? pendingAssignments.first : assignments.first;
                    onSelectAssignmentAndTakeAttendance(nextPending);
                  },
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: Text(pendingAssignments.isNotEmpty ? 'Start attendance' : 'Open register'),
          ),
        ),
        const SizedBox(height: 20),

        // Quick Stats Strip
        StatStrip(
          items: [
            StatItemData(
              label: 'Assigned Classes',
              value: '${assignments.length}',
              helper: 'Teaching sections',
            ),
            StatItemData(
              label: 'Submitted Today',
              value: '${completedAssignments.length}',
              helper: 'Sessions completed',
            ),
            StatItemData(
              label: 'Pending Attendance',
              value: '${pendingAssignments.length}',
              helper: pendingAssignments.isNotEmpty ? 'Action required today' : 'All classes submitted',
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Actionable Attendance Attention Queue
        _buildActionableAttention(pendingAssignments),
        const SizedBox(height: 28),

        // Today's Assigned Cohorts & Schedule Overview
        _buildTodaySchedule(todaySessionSectionIds),
        const SizedBox(height: 28),

        // Recent Attendance Sessions Table
        AppTable<Map<String, Object?>>(
          title: 'Recent Attendance Logs',
          subtitle: 'Sessions submitted across your assigned classes',
          items: recentSessions.take(5).toList(),
          emptyMessage: 'No attendance sessions logged recently.',
          actions: [
            TextButton(
              onPressed: onNavigateToRegister,
              child: const Text('All records →', style: TextStyle(fontSize: 13, color: AppColors.primaryText)),
            ),
          ],
          columns: [
            AppTableColumn(
              header: 'Date',
              width: 110,
              cellBuilder: (context, s) => Text('${s['attendanceDate'] ?? '—'}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Class & Section',
              flex: 2,
              cellBuilder: (context, s) => Text(
                '${s['className'] ?? ''} - ${s['sectionName'] ?? ''}',
                style: AppTypography.compactTableMedium,
              ),
            ),
            AppTableColumn(
              header: 'Type',
              width: 90,
              cellBuilder: (context, s) => StatusBadge.fromStatusString('${s['kind'] ?? 'daily'}'),
            ),
            AppTableColumn(
              header: 'Period',
              width: 80,
              cellBuilder: (context, s) => Text(
                s['periodNumber'] != null ? 'P${s['periodNumber']}' : 'Daily',
                style: AppTypography.compactTable,
              ),
            ),
            AppTableColumn(
              header: 'Status',
              width: 100,
              alignment: Alignment.centerRight,
              cellBuilder: (context, s) => const StatusBadge(
                label: 'SAVED',
                tone: BadgeTone.success,
                icon: Icons.check,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionableAttention(List<Map<String, Object?>> pendingAssignments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Attendance Requiring Attention', style: AppTypography.subsectionHeading),
            const SizedBox(width: 8),
            if (pendingAssignments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.1),
                  borderRadius: AppRadii.rSm,
                  border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${pendingAssignments.length} PENDING',
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
          child: pendingAssignments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20, color: AppColors.statusSuccess),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('All Assigned Classes Submitted', style: AppTypography.bodyMedium),
                            SizedBox(height: 2),
                            Text('You have logged attendance for all your assigned class sections today.', style: AppTypography.bodySecondary),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onNavigateToRegister,
                        child: const Text('Open register →', style: TextStyle(color: AppColors.primaryText)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingAssignments.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                  itemBuilder: (context, index) {
                    final item = pendingAssignments[index];
                    final className = '${item['className']} - ${item['sectionName']}';
                    final subject = item['subjectName'] != null ? '${item['subjectName']}' : 'General attendance';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 18, color: AppColors.statusWarning),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(className, style: AppTypography.bodyMedium),
                                const SizedBox(height: 2),
                                Text(
                                  '$subject • Attendance has not yet been submitted for today.',
                                  style: AppTypography.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => onSelectAssignmentAndTakeAttendance(item),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.secondaryBackground,
                              foregroundColor: AppColors.primaryText,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Record now →'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTodaySchedule(Set<String> todaySessionSectionIds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Today\'s Assigned Classes', style: AppTypography.subsectionHeading),
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          const EmptyStateView(
            title: 'No classes assigned',
            description: 'You have not been assigned to any class sections yet. Contact your administrator.',
            icon: Icons.assignment_outlined,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              border: Border.all(color: AppColors.primaryBorder),
              borderRadius: AppRadii.rLg,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignments.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                final isDone = todaySessionSectionIds.contains(assignment['sectionId']);
                final className = '${assignment['className']} - ${assignment['sectionName']}';
                final subject = assignment['subjectName'] != null ? '${assignment['subjectName']}' : 'General';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: AppRadii.rSm,
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(className, style: AppTypography.bodyMedium),
                            const SizedBox(height: 2),
                            Text(subject, style: AppTypography.metadata),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: isDone ? 'COMPLETED' : 'PENDING',
                        tone: isDone ? BadgeTone.success : BadgeTone.warning,
                        icon: isDone ? Icons.check : Icons.schedule,
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton(
                        onPressed: () => onSelectAssignmentAndTakeAttendance(assignment),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: Text(isDone ? 'Review' : 'Take attendance'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

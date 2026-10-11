import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/page_header.dart';
import '../dialogs/class_roster_dialog.dart';

class TeacherClassesView extends StatelessWidget {
  const TeacherClassesView({
    required this.assignments,
    required this.onTakeAttendance,
    super.key,
  });

  final List<Map<String, Object?>> assignments;
  final void Function(Map<String, Object?> assignment) onTakeAttendance;

  void _openRoster(BuildContext context, Map<String, Object?> assignment) {
    showDialog(
      context: context,
      builder: (context) => ClassRosterDialog(
        assignment: assignment,
        onTakeAttendance: () => onTakeAttendance(assignment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'My Classes',
          description: 'Class sections and student rosters allocated to your teaching schedule.',
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rSm,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(
              '${assignments.length} SECTIONS',
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (assignments.isEmpty)
          const EmptyStateView(
            title: 'No classes assigned',
            description: 'You are currently not mapped to any class sections. Please contact your administrator.',
            icon: Icons.layers_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final cardWidth = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: assignments.map((assignment) {
                  final className = '${assignment['className']}';
                  final sectionName = '${assignment['sectionName']}';
                  final subject = assignment['subjectName'] != null ? '${assignment['subjectName']}' : 'General Curriculum';

                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.mainBackground,
                        border: Border.all(color: AppColors.primaryBorder),
                        borderRadius: AppRadii.rLg,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$className - $sectionName',
                                    style: AppTypography.sectionHeading,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subject,
                                    style: AppTypography.bodySecondary,
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryBackground,
                                  borderRadius: AppRadii.rSm,
                                  border: Border.all(color: AppColors.primaryBorder),
                                ),
                                child: const Text(
                                  'ASSIGNED',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1, color: AppColors.primaryBorder),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openRoster(context, assignment),
                                icon: const Icon(Icons.people_outline, size: 15),
                                label: const Text('View roster'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => onTakeAttendance(assignment),
                                icon: const Icon(Icons.fact_check_outlined, size: 15),
                                label: const Text('Take attendance'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

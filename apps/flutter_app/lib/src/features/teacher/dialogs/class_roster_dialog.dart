import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';

class ClassRosterDialog extends ConsumerStatefulWidget {
  const ClassRosterDialog({
    required this.assignment,
    required this.onTakeAttendance,
    super.key,
  });

  final Map<String, Object?> assignment;
  final VoidCallback onTakeAttendance;

  @override
  ConsumerState<ClassRosterDialog> createState() => _ClassRosterDialogState();
}

class _ClassRosterDialogState extends ConsumerState<ClassRosterDialog> {
  List<StudentRow> _roster = [];
  bool _loading = true;
  String? _error;

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
      final query = Uri(queryParameters: {
        'sectionId': widget.assignment['sectionId'] as String,
        'academicYearId': widget.assignment['academicYearId'] as String,
      }).query;
      final rosterJson = await ref.read(apiClientProvider).getList(
            '/api/v1/teacher/roster?$query',
            session: session,
          );
      setState(() {
        _roster = rosterJson.map(StudentRow.fromJson).toList();
      });
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
    final className = '${widget.assignment['className']} - ${widget.assignment['sectionName']}';
    final subject = widget.assignment['subjectName'] != null ? '${widget.assignment['subjectName']}' : 'General';

    return AppDialog(
      title: className,
      subtitle: '$subject • ${_roster.length} enrolled students',
      maxWidth: 540,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onTakeAttendance();
          },
          icon: const Icon(Icons.fact_check_outlined, size: 16),
          label: const Text('Take attendance'),
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
              : _roster.isEmpty
                  ? const EmptyStateView(
                      title: 'No students enrolled',
                      description: 'There are no students currently enrolled in this class section.',
                      icon: Icons.people_outline,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryBorder),
                        borderRadius: AppRadii.rMd,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _roster.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                        itemBuilder: (context, index) {
                          final student = _roster[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryBackground,
                                    borderRadius: AppRadii.rSm,
                                    border: Border.all(color: AppColors.primaryBorder),
                                  ),
                                  child: Text(
                                    student.rollNumber ?? '${index + 1}',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.fullName, style: AppTypography.compactTableMedium),
                                      Text(student.admissionNumber, style: AppTypography.metadata),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

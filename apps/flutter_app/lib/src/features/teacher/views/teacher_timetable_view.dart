import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/page_header.dart';

const _teacherTimetableDays = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

class TeacherTimetableView extends StatelessWidget {
  const TeacherTimetableView({
    required this.entries,
    required this.onTakeAttendance,
    super.key,
  });

  final List<Map<String, Object?>> entries;
  final void Function(Map<String, Object?> entry) onTakeAttendance;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final sorted = [...entries]..sort(_compareEntries);
    final todaysLessons = sorted.where((entry) => entry['dayOfWeek'] == today).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'My Week',
          description: 'Read-only weekly timetable set by the administrator.',
          primaryAction: todaysLessons.isEmpty
              ? null
              : FilledButton.icon(
                  onPressed: () => onTakeAttendance(todaysLessons.first),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Take next attendance'),
                ),
        ),
        const SizedBox(height: 20),
        _buildWeekGrid(sorted, today),
        const SizedBox(height: 24),
        AppTable<Map<String, Object?>>(
          title: 'Scheduled lessons',
          subtitle: 'Teacher timetable entries from the current academic year',
          items: sorted,
          emptyMessage: 'No timetable entries assigned yet.',
          columns: [
            AppTableColumn(
              header: 'Day',
              width: 96,
              cellBuilder: (context, row) => Text(_teacherTimetableDays[row['dayOfWeek']] ?? '—', style: AppTypography.compactTableMedium),
            ),
            AppTableColumn(
              header: 'Time',
              width: 120,
              cellBuilder: (context, row) => Text('${_time(row['startTime'])}–${_time(row['endTime'])}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Class',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['className']} ${row['sectionName']}', style: AppTypography.compactTableMedium),
            ),
            AppTableColumn(
              header: 'Subject',
              flex: 2,
              cellBuilder: (context, row) => Text('${row['subjectName']}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: '',
              width: 120,
              alignment: Alignment.centerRight,
              cellBuilder: (context, row) => OutlinedButton(
                onPressed: () => onTakeAttendance(row),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Attendance'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekGrid(List<Map<String, Object?>> sorted, int today) {
    if (sorted.isEmpty) {
      return const EmptyStateView(
        title: 'No timetable assigned',
        description: 'Your administrator has not published weekly lessons for your account yet.',
        icon: Icons.calendar_month_outlined,
      );
    }

    final hasWeekendLessons = sorted.any((entry) => (entry['dayOfWeek'] as int? ?? 0) >= 6);
    final displayedDays = _teacherTimetableDays.entries.where((d) => d.key <= 5 || hasWeekendLessons).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final colCount = hasWeekendLessons ? 7 : 5;
        final cardWidth = isWide
            ? (constraints.maxWidth - (12 * (colCount - 1))) / colCount
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: displayedDays.map((day) {
            final lessons = sorted.where((entry) => entry['dayOfWeek'] == day.key).toList();
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: day.key == today ? AppColors.secondaryBackground : AppColors.mainBackground,
                border: Border.all(color: day.key == today ? AppColors.primaryText : AppColors.primaryBorder),
                borderRadius: AppRadii.rLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(day.value, style: AppTypography.subsectionHeading)),
                      if (day.key == today) const Icon(Icons.today_outlined, size: 14, color: AppColors.secondaryText),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (lessons.isEmpty)
                    const Text('No lessons', style: AppTypography.metadata)
                  else
                    ...lessons.map((lesson) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_time(lesson['startTime'])}–${_time(lesson['endTime'])}', style: AppTypography.metadata),
                              const SizedBox(height: 2),
                              Text('${lesson['className']} ${lesson['sectionName']}', style: AppTypography.bodyMedium),
                              Text('${lesson['subjectName']}', style: AppTypography.bodySecondary),
                              const SizedBox(height: 6),
                              if (day.key == today)
                                TextButton.icon(
                                  onPressed: () => onTakeAttendance(lesson),
                                  icon: const Icon(Icons.fact_check_outlined, size: 14),
                                  label: const Text('Take attendance'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        )),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

int _compareEntries(Map<String, Object?> a, Map<String, Object?> b) {
  final day = (a['dayOfWeek'] as int).compareTo(b['dayOfWeek'] as int);
  if (day != 0) return day;
  return '${a['startTime']}'.compareTo('${b['startTime']}');
}

String _time(Object? value) {
  final text = '$value';
  return text.length >= 5 ? text.substring(0, 5) : text;
}

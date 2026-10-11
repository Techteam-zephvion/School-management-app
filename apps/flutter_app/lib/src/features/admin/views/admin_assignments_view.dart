import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';

class AdminAssignmentsView extends ConsumerStatefulWidget {
  const AdminAssignmentsView({
    required this.assignments,
    required this.staff,
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> assignments;
  final List<Map<String, Object?>> staff;
  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final Future<void> Function() reload;

  @override
  ConsumerState<AdminAssignmentsView> createState() => _AdminAssignmentsViewState();
}

class _AdminAssignmentsViewState extends ConsumerState<AdminAssignmentsView> {
  String? _staffId;
  String? _yearId;
  String? _classId;
  String? _sectionId;
  String? _subjectId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    if (widget.staff.isNotEmpty) _staffId = widget.staff.first['id'] as String?;
    if (widget.years.isNotEmpty) _yearId = widget.years.first['id'] as String?;
    if (widget.classes.isNotEmpty) _classId = widget.classes.first['id'] as String?;
    _updateSectionDefault();
  }

  void _updateSectionDefault() {
    final available = _availableSections();
    if (available.isNotEmpty) {
      _sectionId = available.first['id'] as String?;
    } else {
      _sectionId = null;
    }
  }

  List<Map<String, Object?>> _availableSections() {
    if (_classId == null) return widget.sections;
    return widget.sections.where((s) => s['classId'] == _classId).toList();
  }

  Future<void> _submit() async {
    if (_staffId == null || _yearId == null || _classId == null || _sectionId == null) {
      setState(() => _error = 'Please select Teacher, Academic Year, Class, and Section.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = {
        'staffId': _staffId,
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        'subjectId': _subjectId,
        'canTakeDailyAttendance': true,
      };
      await ref.read(apiClientProvider).postJson('/api/v1/admin/teacher-assignments', body, session: session);
      await widget.reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSections = _availableSections();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Teacher Assignments',
          description: 'Allocate teachers to specific class sections and curriculum subjects.',
        ),
        const SizedBox(height: 20),

        // Create assignment card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create Teacher Assignment', style: AppTypography.subsectionHeading),
              const SizedBox(height: 16),
              if (_error != null)
                FeedbackBanner(
                  message: _error!,
                  tone: FeedbackTone.error,
                  onDismiss: () => setState(() => _error = null),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _staffId,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: widget.staff
                          .map((s) => DropdownMenuItem(value: s['id'] as String?, child: Text('${s['fullName']}')))
                          .toList(),
                      onChanged: (val) => setState(() => _staffId = val),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _yearId,
                      decoration: const InputDecoration(labelText: 'Academic Year'),
                      items: widget.years
                          .map((y) => DropdownMenuItem(value: y['id'] as String?, child: Text('${y['name']}')))
                          .toList(),
                      onChanged: (val) => setState(() => _yearId = val),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _classId,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: widget.classes
                          .map((c) => DropdownMenuItem(value: c['id'] as String?, child: Text('${c['name']}')))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _classId = val;
                          _updateSectionDefault();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('sec_$_classId'),
                      initialValue: _sectionId,
                      decoration: const InputDecoration(labelText: 'Section'),
                      items: availableSections
                          .map((s) => DropdownMenuItem(value: s['id'] as String?, child: Text('${s['name']}')))
                          .toList(),
                      onChanged: (val) => setState(() => _sectionId = val),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _subjectId,
                      decoration: const InputDecoration(labelText: 'Subject (optional)'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All / General')),
                        ...widget.subjects.map(
                          (sub) => DropdownMenuItem(value: sub['id'] as String?, child: Text('${sub['name']}')),
                        ),
                      ],
                      onChanged: (val) => setState(() => _subjectId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add, size: 16),
                  label: const Text('Assign teacher to section'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Active assignments table
        AppTable<Map<String, Object?>>(
          title: 'Active Assignments',
          subtitle: 'Mappings between faculty, cohorts, and subjects',
          items: widget.assignments,
          count: widget.assignments.length,
          emptyMessage: 'No teacher assignments configured yet.',
          filterPredicate: (a, query) {
            final teacher = '${a['staffName'] ?? ''}'.toLowerCase();
            final cls = '${a['className'] ?? ''}'.toLowerCase();
            final sec = '${a['sectionName'] ?? ''}'.toLowerCase();
            final sub = '${a['subjectName'] ?? ''}'.toLowerCase();
            return teacher.contains(query) || cls.contains(query) || sec.contains(query) || sub.contains(query);
          },
          searchHint: 'Filter by teacher or class...',
          columns: [
            AppTableColumn(
              header: 'Teacher',
              flex: 2,
              cellBuilder: (context, a) => Text('${a['staffName'] ?? '—'}', style: AppTypography.compactTableMedium),
            ),
            AppTableColumn(
              header: 'Class',
              flex: 2,
              cellBuilder: (context, a) => Text('${a['className'] ?? '—'}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Section',
              flex: 2,
              cellBuilder: (context, a) => Text('${a['sectionName'] ?? '—'}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Subject',
              flex: 2,
              cellBuilder: (context, a) => Text(
                '${a['subjectName'] ?? 'All / General'}',
                style: AppTypography.compactTable,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

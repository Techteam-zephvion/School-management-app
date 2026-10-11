import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';

class AdminClassesView extends StatelessWidget {
  const AdminClassesView({
    required this.years,
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final List<Map<String, Object?>> subjects;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Classes & Subjects',
          description: 'Academic hierarchy, cohorts, classrooms, and subject curricula.',
        ),
        const SizedBox(height: 20),

        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            final cardWidth = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _QuickCreateCard(
                    title: 'Academic Year',
                    subtitle: '${years.length} active configurations',
                    fields: const [
                      _FieldSpec('name', 'Year name', hint: '2026-2027'),
                      _FieldSpec('startDate', 'Start date', hint: '2026-06-01'),
                      _FieldSpec('endDate', 'End date', hint: '2027-04-30'),
                    ],
                    path: '/api/v1/admin/academic-years',
                    reload: reload,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _QuickCreateCard(
                    title: 'Class',
                    subtitle: '${classes.length} registered grades',
                    fields: const [
                      _FieldSpec('name', 'Class name', hint: 'Grade 10'),
                      _FieldSpec('code', 'Code', hint: 'G10'),
                      _FieldSpec('stage', 'Stage', hint: 'Secondary'),
                      _FieldSpec('sequenceNumber', 'Sequence', hint: '10', number: true),
                    ],
                    path: '/api/v1/admin/classes',
                    reload: reload,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _QuickCreateCard(
                    title: 'Section',
                    subtitle: '${sections.length} active cohorts',
                    fields: [
                      _FieldSpec.select('classId', 'Class', classes),
                      const _FieldSpec('name', 'Section name', hint: 'Section A'),
                      const _FieldSpec('roomNumber', 'Room number', hint: 'Room 204'),
                      const _FieldSpec('capacity', 'Capacity', hint: '40', number: true),
                    ],
                    path: '/api/v1/admin/sections',
                    reload: reload,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _QuickCreateCard(
                    title: 'Subject',
                    subtitle: '${subjects.length} curricula modules',
                    fields: const [
                      _FieldSpec('name', 'Subject name', hint: 'Mathematics'),
                      _FieldSpec('code', 'Subject code', hint: 'MATH-10'),
                    ],
                    path: '/api/v1/admin/subjects',
                    reload: reload,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.key, this.label, {this.hint, this.number = false})
      : options = null,
        nullable = false,
        labelKey = 'name';

  const _FieldSpec.select(this.key, this.label, this.options)
      : hint = null,
        number = false,
        labelKey = 'name',
        nullable = false;

  final String key;
  final String label;
  final String? hint;
  final bool number;
  final List<Map<String, Object?>>? options;
  final String labelKey;
  final bool nullable;
}

class _QuickCreateCard extends ConsumerStatefulWidget {
  const _QuickCreateCard({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.path,
    required this.reload,
  });

  final String title;
  final String subtitle;
  final List<_FieldSpec> fields;
  final String path;
  final Map<String, Object?> defaults = const {};
  final Future<void> Function() reload;

  @override
  ConsumerState<_QuickCreateCard> createState() => _QuickCreateCardState();
}

class _QuickCreateCardState extends ConsumerState<_QuickCreateCard> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectValues = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.options == null) {
        _controllers[field.key] = TextEditingController();
      } else {
        _selectValues[field.key] = field.options!.isNotEmpty ? field.options!.first['id'] as String? : null;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = <String, Object?>{...widget.defaults};
      for (final field in widget.fields) {
        if (field.options == null) {
          final value = _controllers[field.key]!.text.trim();
          if (value.isNotEmpty) {
            body[field.key] = field.number ? int.parse(value) : value;
          }
        } else {
          final value = _selectValues[field.key];
          if (value != null && value.isNotEmpty) {
            body[field.key] = value;
          }
        }
      }
      await ref.read(apiClientProvider).postJson(widget.path, body, session: session);
      for (final controller in _controllers.values) {
        controller.clear();
      }
      await widget.reload();
    } on ApiException catch (exception) {
      setState(() => _error = exception.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: AppTypography.subsectionHeading),
                Text(widget.subtitle, style: AppTypography.metadata),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              FeedbackBanner(
                message: _error!,
                tone: FeedbackTone.error,
                onDismiss: () => setState(() => _error = null),
              ),
            ...widget.fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.options == null
                    ? TextFormField(
                        controller: _controllers[field.key],
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                        ),
                      )
                    : DropdownButtonFormField<String?>(
                        initialValue: _selectValues[field.key],
                        decoration: InputDecoration(labelText: field.label),
                        items: [
                          if (field.nullable)
                            const DropdownMenuItem<String?>(value: null, child: Text('None')),
                          ...?field.options?.map(
                            (option) => DropdownMenuItem<String?>(
                              value: option['id'] as String?,
                              child: Text('${option[field.labelKey]}'),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _selectValues[field.key] = value),
                      ),
              );
            }),
            const SizedBox(height: 4),
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
                label: Text('Create ${widget.title.toLowerCase()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

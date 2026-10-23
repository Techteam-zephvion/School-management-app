import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/feedback_banner.dart';

class AddStudentDialog extends ConsumerStatefulWidget {
  const AddStudentDialog({
    required this.years,
    required this.classes,
    required this.sections,
    required this.reload,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;
  final Future<void> Function() reload;

  @override
  ConsumerState<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _admissionNo = TextEditingController();
  final _fullName = TextEditingController();
  final _rollNo = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianEmail = TextEditingController();
  final _guardianPhone = TextEditingController();

  String? _yearId;
  String? _classId;
  String? _sectionId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.years.isNotEmpty) _yearId = widget.years.first['id'] as String?;
    if (widget.classes.isNotEmpty) _classId = widget.classes.first['id'] as String?;
    _updateDefaultSection();
  }

  void _updateDefaultSection() {
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

  @override
  void dispose() {
    _admissionNo.dispose();
    _fullName.dispose();
    _rollNo.dispose();
    _guardianName.dispose();
    _guardianEmail.dispose();
    _guardianPhone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_yearId == null || _classId == null || _sectionId == null) {
      setState(() => _error = 'Please select Academic Year, Class, and Section.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final adm = _admissionNo.text.trim();
      final body = <String, Object?>{
        if (adm.isNotEmpty) 'admissionNumber': adm,
        'fullName': _fullName.text.trim(),
        'academicYearId': _yearId,
        'classId': _classId,
        'sectionId': _sectionId,
        if (_rollNo.text.trim().isNotEmpty) 'rollNumber': _rollNo.text.trim(),
        if (_guardianName.text.trim().isNotEmpty) 'guardianName': _guardianName.text.trim(),
        if (_guardianEmail.text.trim().isNotEmpty) 'guardianEmail': _guardianEmail.text.trim(),
        if (_guardianPhone.text.trim().isNotEmpty) 'guardianPhone': _guardianPhone.text.trim(),
      };
      await ref.read(apiClientProvider).postJson('/api/v1/admin/students', body, session: session);
      await widget.reload();
      if (mounted) Navigator.of(context).pop();
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

    return AppDialog(
      title: 'Add New Student',
      subtitle: 'Enroll a student into an active cohort and link parent account.',
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enroll student'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeedbackBanner(
                    message: _error!,
                    tone: FeedbackTone.error,
                    onDismiss: () => setState(() => _error = null),
                  ),
                ),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name *',
                  hintText: 'e.g. Aarav Sharma',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _admissionNo,
                decoration: const InputDecoration(
                  labelText: 'Admission Number (Optional)',
                  hintText: 'Leave empty to auto-generate sequentially',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _yearId,
                decoration: const InputDecoration(labelText: 'Academic Year *'),
                items: widget.years
                    .map((y) => DropdownMenuItem(
                          value: y['id'] as String,
                          child: Text('${y['name']}'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _yearId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: widget.classes
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text('${c['name']}'),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _classId = val;
                    _updateDefaultSection();
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('sec_$_classId'),
                initialValue: _sectionId,
                decoration: const InputDecoration(labelText: 'Section *'),
                items: availableSections
                    .map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text('${s['name']}'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _sectionId = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rollNo,
                decoration: const InputDecoration(
                  labelText: 'Roll Number (optional)',
                  hintText: 'e.g. 14',
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Parent / Guardian Linking',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianName,
                decoration: const InputDecoration(
                  labelText: 'Guardian / Parent Name (optional)',
                  hintText: 'e.g. Rajesh Sharma',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Guardian Email (Auto-provisions parent portal login)',
                  hintText: 'e.g. parent@example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Guardian Phone Number',
                  hintText: 'e.g. +91 9876543210',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

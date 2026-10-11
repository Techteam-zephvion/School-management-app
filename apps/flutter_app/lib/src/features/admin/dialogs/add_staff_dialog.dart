import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/feedback_banner.dart';

class AddStaffDialog extends ConsumerStatefulWidget {
  const AddStaffDialog({
    required this.reload,
    super.key,
  });

  final Future<void> Function() reload;

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final body = {
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      };
      await ref.read(apiClientProvider).postJson('/api/v1/admin/staff', body, session: session);
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
    return AppDialog(
      title: 'Add Staff Member',
      subtitle: 'Register a teacher or administrator to the school directory.',
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
              : const Text('Save staff'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              FeedbackBanner(
                message: _error!,
                tone: FeedbackTone.error,
                onDismiss: () => setState(() => _error = null),
              ),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Dr. Robert Vance',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address (optional)',
                hintText: 'e.g. robert.vance@schoolic.edu',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                hintText: 'e.g. +1 555-0199',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

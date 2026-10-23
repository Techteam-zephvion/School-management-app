import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/fluid_ui.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/schoolic_logo.dart';

class PublicAdmissionsView extends ConsumerStatefulWidget {
  const PublicAdmissionsView({required this.schoolCode, super.key});

  final String schoolCode;

  @override
  ConsumerState<PublicAdmissionsView> createState() => _PublicAdmissionsViewState();
}

class _PublicAdmissionsViewState extends ConsumerState<PublicAdmissionsView> {
  final _formKey = GlobalKey<FormState>();
  final _applicantNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _notesController = TextEditingController();

  String _gender = 'other';
  String? _selectedClassId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, Object?>? _schoolProfile;
  Map<String, Object?>? _submittedInquiry;

  @override
  void initState() {
    super.initState();
    _loadSchool();
  }

  @override
  void dispose() {
    _applicantNameController.dispose();
    _dobController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSchool() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final profile = await api.getJson('/api/v1/public/schools/${widget.schoolCode}');
      if (!mounted) return;
      setState(() {
        _schoolProfile = profile;
        final classes = (profile['classes'] as List?)?.whereType<Map>().toList() ?? [];
        if (classes.isNotEmpty) {
          _selectedClassId = classes.first['id'] as String?;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _schoolProfile = {
            'name': 'Schoolic Partner Institution',
            'code': widget.schoolCode,
            'classes': const [],
          };
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'schoolCode': widget.schoolCode,
        'applicantName': _applicantNameController.text.trim(),
        'dateOfBirth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
        'gender': _gender,
        'parentName': _parentNameController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'parentEmail': _parentEmailController.text.trim().isEmpty ? null : _parentEmailController.text.trim(),
        if (_selectedClassId != null) 'classId': _selectedClassId,
        if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      };

      final result = await api.postJson('/api/v1/public/admissions/apply', body);
      if (!mounted) return;
      setState(() {
        _submittedInquiry = result;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Unable to submit application: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = (_schoolProfile?['name'] as String?) ?? 'School Admission Portal';
    final classes = (_schoolProfile?['classes'] as List?)
            ?.whereType<Map>()
            .map((c) => c.cast<String, Object?>())
            .toList() ??
        const [];

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        elevation: 0,
        title: Row(
          children: [
            const SchoolicLogo(size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                schoolName,
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _submittedInquiry != null
                      ? _buildConfirmationCard()
                      : _buildApplicationForm(classes),
                ),
              ),
            ),
    );
  }

  Widget _buildApplicationForm(List<Map<String, Object?>> classes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluidInteractiveCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: AppRadii.rMd,
                    ),
                    child: const Icon(Icons.school_outlined, size: 24, color: AppColors.primaryText),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Online Admission Application',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submit your enrollment inquiry for Academic Year 2026–2027.',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                FeedbackBanner(
                  message: _error!,
                  tone: FeedbackTone.error,
                  onDismiss: () => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Student Details',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _applicantNameController,
                      decoration: const InputDecoration(
                        labelText: 'Applicant Full Name *',
                        hintText: 'Enter student legal name',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) {
                          return 'Please enter applicant name (at least 2 characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dobController,
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth (YYYY-MM-DD)',
                              hintText: '2015-05-20',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (val) => setState(() => _gender = val ?? 'other'),
                          ),
                        ),
                      ],
                    ),
                    if (classes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
                        decoration: const InputDecoration(labelText: 'Applying For Grade / Class *'),
                        items: classes
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['id'] as String?,
                                child: Text('${c['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedClassId = val),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Parent / Guardian Contact',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _parentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Parent / Guardian Name *',
                        hintText: 'Enter parent full name',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter parent/guardian name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _parentPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Phone *',
                              hintText: '+91 98765 43210',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().length < 8) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _parentEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'parent@example.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional Remarks / Previous School',
                        hintText: 'Mention previous curriculum, special needs, or questions...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FluidIslandButton(
                      label: _submitting ? 'Submitting Application...' : 'Submit Admission Inquiry',
                      trailingIcon: Icons.arrow_forward,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submitApplication,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard() {
    final inqNum = (_submittedInquiry?['applicationNumber'] as String?) ??
        (_submittedInquiry?['id'] as String?) ??
        'ADM-CONFIRMED';

    return FluidInteractiveCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 54, color: AppColors.statusSuccess),
          const SizedBox(height: 16),
          const Text(
            'Application Submitted Successfully!',
            style: TextStyle(
              fontFamily: 'Switzer',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your admissions inquiry has been recorded by the school admissions office.',
            style: TextStyle(
              fontFamily: 'Switzer',
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Column(
              children: [
                const Text(
                  'APPLICATION REFERENCE NUMBER',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  inqNum,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'The school administration will review your details and contact you via phone or email for document verification and campus visit scheduling.',
            style: TextStyle(
              fontFamily: 'Switzer',
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _submittedInquiry = null;
                _applicantNameController.clear();
                _dobController.clear();
                _parentNameController.clear();
                _parentPhoneController.clear();
                _parentEmailController.clear();
                _notesController.clear();
              });
            },
            child: const Text('Submit Another Application'),
          ),
        ],
      ),
    );
  }
}

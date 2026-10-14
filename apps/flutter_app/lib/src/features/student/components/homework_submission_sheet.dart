import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/feedback_banner.dart';

class HomeworkSubmissionSheet extends ConsumerStatefulWidget {
  const HomeworkSubmissionSheet({
    required this.assignmentId,
    required this.assignmentTitle,
    required this.subjectName,
    required this.dueDate,
    required this.instructions,
    this.studentId,
    this.initialContent,
    this.initialAttachmentUrl,
    this.onSubmitted,
    super.key,
  });

  final String assignmentId;
  final String assignmentTitle;
  final String subjectName;
  final String dueDate;
  final String instructions;
  final String? studentId;
  final String? initialContent;
  final String? initialAttachmentUrl;
  final VoidCallback? onSubmitted;

  static Future<void> show(
    BuildContext context, {
    required String assignmentId,
    required String assignmentTitle,
    required String subjectName,
    required String dueDate,
    required String instructions,
    String? studentId,
    String? initialContent,
    String? initialAttachmentUrl,
    VoidCallback? onSubmitted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HomeworkSubmissionSheet(
        assignmentId: assignmentId,
        assignmentTitle: assignmentTitle,
        subjectName: subjectName,
        dueDate: dueDate,
        instructions: instructions,
        studentId: studentId,
        initialContent: initialContent,
        initialAttachmentUrl: initialAttachmentUrl,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  ConsumerState<HomeworkSubmissionSheet> createState() =>
      _HomeworkSubmissionSheetState();
}

class _HomeworkSubmissionSheetState
    extends ConsumerState<HomeworkSubmissionSheet> {
  late final TextEditingController _contentController;
  late final TextEditingController _attachmentController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _attachmentController =
        TextEditingController(text: widget.initialAttachmentUrl ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter your submission text or response.');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      setState(() => _error = 'Please sign in to submit homework.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final attachment = _attachmentController.text.trim();
      await api.postJson(
        '/api/v1/portal/homework/${widget.assignmentId}/submit',
        {
          if (widget.studentId != null) 'studentId': widget.studentId,
          'content': text,
          if (attachment.isNotEmpty) 'attachmentUrl': attachment,
        },
        session: session,
      );

      if (!mounted) return;
      widget.onSubmitted?.call();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Homework submitted successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException
            ? e.message
            : 'Failed to submit homework. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Subject & Due Date
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: AppRadii.rSm,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    widget.subjectName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Due: ${widget.dueDate}',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              widget.assignmentTitle,
              style: AppTypography.sectionHeading,
            ),
            const SizedBox(height: 10),

            // Instructions Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INSTRUCTIONS',
                    style: TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instructions,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              FeedbackBanner(
                message: _error!,
                tone: FeedbackTone.error,
              ),
              const SizedBox(height: 12),
            ],

            // Submission content input
            TextField(
              controller: _contentController,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your Solution / Answer',
                hintText:
                    'Write your answers, calculations, or report summary here...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Project link / attachment URL (optional)
            TextField(
              controller: _attachmentController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Project or Document Link (Optional)',
                hintText: 'https://drive.google.com/... or GitHub link',
                prefixIcon: Icon(Icons.link, size: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _submitting ? 'Submitting...' : 'Submit Homework',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';

class AiHomeworkFeedbackDialog extends ConsumerStatefulWidget {
  const AiHomeworkFeedbackDialog({
    this.initialAssignmentTitle = '',
    this.initialSubject = '',
    this.initialScore = 15,
    this.initialMaxScore = 20,
    this.onApplyFeedback,
    super.key,
  });

  final String initialAssignmentTitle;
  final String initialSubject;
  final num initialScore;
  final num initialMaxScore;
  final ValueChanged<String>? onApplyFeedback;

  static Future<void> show(
    BuildContext context, {
    String initialAssignmentTitle = '',
    String initialSubject = '',
    num initialScore = 15,
    num initialMaxScore = 20,
    ValueChanged<String>? onApplyFeedback,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AiHomeworkFeedbackDialog(
        initialAssignmentTitle: initialAssignmentTitle,
        initialSubject: initialSubject,
        initialScore: initialScore,
        initialMaxScore: initialMaxScore,
        onApplyFeedback: onApplyFeedback,
      ),
    );
  }

  @override
  ConsumerState<AiHomeworkFeedbackDialog> createState() => _AiHomeworkFeedbackDialogState();
}

class _AiHomeworkFeedbackDialogState extends ConsumerState<AiHomeworkFeedbackDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _scoreController;
  late final TextEditingController _maxScoreController;
  late final TextEditingController _strengthsController;
  late final TextEditingController _improvementsController;

  bool _loading = false;
  String? _error;
  String? _feedbackText;
  String? _rubricGrade;
  String? _percentage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialAssignmentTitle);
    _subjectController = TextEditingController(text: widget.initialSubject);
    _scoreController = TextEditingController(text: '${widget.initialScore}');
    _maxScoreController = TextEditingController(text: '${widget.initialMaxScore}');
    _strengthsController = TextEditingController();
    _improvementsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _scoreController.dispose();
    _maxScoreController.dispose();
    _strengthsController.dispose();
    _improvementsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final score = num.tryParse(_scoreController.text.trim());
    final maxScore = num.tryParse(_maxScoreController.text.trim());

    if (title.isEmpty || subject.isEmpty || score == null || maxScore == null) {
      setState(() => _error = 'Please fill assignment title, subject, score and max score');
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ref.read(apiClientProvider).draftHomeworkFeedback(
            session: session,
            assignmentTitle: title,
            subject: subject,
            studentScore: score,
            maxScore: maxScore,
            strengths: _strengthsController.text.trim().isNotEmpty
                ? _strengthsController.text.trim()
                : null,
            areasForImprovement: _improvementsController.text.trim().isNotEmpty
                ? _improvementsController.text.trim()
                : null,
          );
      setState(() {
        _feedbackText = res['feedbackText'] as String?;
        _rubricGrade = res['rubricGrade'] as String?;
        _percentage = res['scorePercentage'] as String?;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied feedback to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _apply(String text) {
    widget.onApplyFeedback?.call(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'AI Homework Feedback Generator',
      subtitle: 'Formulate rubric-guided constructive feedback and praise for student submissions',
      maxWidth: 560,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.grading_rounded, size: 16),
          label: Text(_loading ? 'Generating...' : 'Generate Feedback'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.1),
                borderRadius: AppRadii.rSm,
                border: Border.all(color: AppColors.statusError.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.statusError)),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Title',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Student Marks',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _maxScoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum Marks',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _strengthsController,
            decoration: const InputDecoration(
              labelText: 'Observed Strengths (Optional)',
              hintText: 'e.g. Clean diagrams, correct formulas, neat handwriting',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _improvementsController,
            decoration: const InputDecoration(
              labelText: 'Areas for Growth / Errors (Optional)',
              hintText: 'e.g. Review transposition of terms, add unit of measurement',
              isDense: true,
            ),
          ),
          const SizedBox(height: 18),

          if (_feedbackText != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Text(
                          _rubricGrade ?? 'RUBRIC GRADE',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Score: $_percentage',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Copy',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copy(_feedbackText!),
                        icon: const Icon(Icons.copy_rounded, color: AppColors.secondaryText),
                      ),
                      if (widget.onApplyFeedback != null)
                        FilledButton.tonalIcon(
                          onPressed: () => _apply(_feedbackText!),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Apply'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _feedbackText!,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

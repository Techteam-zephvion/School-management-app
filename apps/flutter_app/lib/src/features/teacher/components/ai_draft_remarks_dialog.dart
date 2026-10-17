import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';

class AiDraftRemarksDialog extends ConsumerStatefulWidget {
  const AiDraftRemarksDialog({
    this.initialStudentName = '',
    this.initialPercentage = '85%',
    this.initialAttendance = '92%',
    this.onApplyRemark,
    super.key,
  });

  final String initialStudentName;
  final String initialPercentage;
  final String initialAttendance;
  final ValueChanged<String>? onApplyRemark;

  static Future<void> show(
    BuildContext context, {
    String initialStudentName = '',
    String initialPercentage = '85%',
    String initialAttendance = '92%',
    ValueChanged<String>? onApplyRemark,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AiDraftRemarksDialog(
        initialStudentName: initialStudentName,
        initialPercentage: initialPercentage,
        initialAttendance: initialAttendance,
        onApplyRemark: onApplyRemark,
      ),
    );
  }

  @override
  ConsumerState<AiDraftRemarksDialog> createState() => _AiDraftRemarksDialogState();
}

class _AiDraftRemarksDialogState extends ConsumerState<AiDraftRemarksDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pctController;
  late final TextEditingController _attController;
  String _selectedTone = 'encouraging';

  bool _loading = false;
  String? _error;
  String? _draftRemarks;
  List<String> _alternativeOptions = const [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialStudentName);
    _pctController = TextEditingController(text: widget.initialPercentage);
    _attController = TextEditingController(text: widget.initialAttendance);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pctController.dispose();
    _attController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final name = _nameController.text.trim();
    final pct = _pctController.text.trim();
    if (name.isEmpty || pct.isEmpty) return;

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ref.read(apiClientProvider).draftReportCardRemarks(
            session: session,
            studentName: name,
            overallPercentage: pct,
            attendanceRate: _attController.text.trim().isNotEmpty
                ? _attController.text.trim()
                : null,
            tone: _selectedTone,
          );
      setState(() {
        _draftRemarks = res['draftRemarks'] as String?;
        _alternativeOptions = ((res['alternativeOptions'] as List?) ?? const [])
            .map((e) => '$e')
            .toList();
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
        content: Text('Copied remarks to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _apply(String text) {
    widget.onApplyRemark?.call(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'AI Report Card Remarks Assistant',
      subtitle: 'Draft personalized, pedagogical remarks tailored to individual student performance',
      maxWidth: 580,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text(_loading ? 'Drafting...' : 'Generate Remarks'),
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

          // Form fields
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student Full Name',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _pctController,
                  decoration: const InputDecoration(
                    labelText: 'Overall Score (%)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _attController,
                  decoration: const InputDecoration(
                    labelText: 'Attendance (%)',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tone Selector Segmented Control
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pedagogical Tone:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'encouraging',
                    label: Text('Encouraging'),
                    icon: Icon(Icons.sentiment_very_satisfied_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'constructive',
                    label: Text('Constructive'),
                    icon: Icon(Icons.trending_up_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'formal',
                    label: Text('Formal'),
                    icon: Icon(Icons.gavel_rounded, size: 16),
                  ),
                ],
                selected: {_selectedTone},
                onSelectionChanged: (val) {
                  setState(() => _selectedTone = val.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Output Display
          if (_draftRemarks != null) ...[
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
                      const Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      const Text(
                        'Primary Generated Remark',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Copy to clipboard',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copy(_draftRemarks!),
                        icon: const Icon(Icons.copy_rounded, color: AppColors.secondaryText),
                      ),
                      if (widget.onApplyRemark != null)
                        FilledButton.tonalIcon(
                          onPressed: () => _apply(_draftRemarks!),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Apply'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _draftRemarks!,
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
            const SizedBox(height: 14),

            if (_alternativeOptions.isNotEmpty) ...[
              const Text(
                'Alternative Draft Options:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              ..._alternativeOptions.map((alt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: AppRadii.rSm,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alt,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Copy',
                        iconSize: 15,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copy(alt),
                        icon: const Icon(Icons.copy_rounded, color: AppColors.secondaryText),
                      ),
                      if (widget.onApplyRemark != null)
                        IconButton(
                          tooltip: 'Apply this option',
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _apply(alt),
                          icon: const Icon(Icons.check_circle_outline, color: AppColors.accent),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}

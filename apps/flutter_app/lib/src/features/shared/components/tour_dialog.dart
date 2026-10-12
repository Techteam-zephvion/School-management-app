import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme.dart';
import 'schoolic_logo.dart';

class TourStep {
  const TourStep({
    required this.tag,
    required this.title,
    required this.description,
    required this.icon,
    required this.highlights,
  });

  final String tag;
  final String title;
  final String description;
  final IconData icon;
  final List<String> highlights;
}

/// Interactive guided product tour for Schoolic.
class TourDialog extends StatefulWidget {
  const TourDialog({
    super.key,
    this.isFirstVisit = false,
  });

  final bool isFirstVisit;

  static const String _storageKey = 'schoolic_tour_seen_v1';

  /// Checks if the tour should be automatically presented to a first-time visitor.
  static Future<bool> shouldShowAutoTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_storageKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Marks the product tour as completed in local storage.
  static Future<void> markTourSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, true);
    } catch (_) {}
  }

  /// Displays the TourDialog modal.
  static Future<void> show(
    BuildContext context, {
    bool isFirstVisit = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TourDialog(isFirstVisit: isFirstVisit),
    );
  }

  @override
  State<TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<TourDialog> {
  int _currentStep = 0;

  static const List<TourStep> _steps = [
    TourStep(
      tag: 'WELCOME',
      title: 'Institutional School Management',
      description:
          'Schoolic is an institutional workspace engineered for high speed, clarity, and zero administrative clutter. Designed specifically for school leadership and educators.',
      icon: Icons.school_outlined,
      highlights: [
        'Direct synchronization with real-time academic records',
        'Distinct, purpose-built workspaces for Teachers and Administrators',
        'Responsive layout across mobile, tablet, and desktop displays',
      ],
    ),
    TourStep(
      tag: 'ATTENDANCE',
      title: 'Fast Attendance Recording',
      description:
          'Eliminate administrative backlog with one-click attendance logging, roster filters, and instant status updates.',
      icon: Icons.fact_check_outlined,
      highlights: [
        'Quick "Mark all present" bulk operation',
        'Real-time verification flags pending sections',
        'Exportable attendance records and student notes',
      ],
    ),
    TourStep(
      tag: 'ADMINISTRATION',
      title: 'Academic Rosters & Timetables',
      description:
          'Administrators manage school-wide student directories, class rosters, teacher assignments, and academic schedules from a unified command view.',
      icon: Icons.admin_panel_settings_outlined,
      highlights: [
        'Comprehensive student directory with class and section filters',
        'Weekly master timetable breakdown by class and teacher',
        'Institutional metrics tracking overall campus attendance',
      ],
    ),
    TourStep(
      tag: 'SHORTCUTS',
      title: 'Built for Keyboard Power Users',
      description:
          'Navigate and perform routine actions without taking your hands off the keyboard. Press "?" or "Ctrl + /" anytime to open the shortcut cheatsheet.',
      icon: Icons.keyboard_outlined,
      highlights: [
        '[Enter ↵] Quickly submit forms and confirm actions',
        '[1 - 5] Jump directly between primary dashboard tabs',
        '[Esc] Instantly dismiss dialogs and slide drawers',
      ],
    ),
    TourStep(
      tag: 'READY',
      title: 'You are all set!',
      description:
          'You are ready to explore Schoolic. You can reopen this tutorial at any time by clicking "Tutorial" in the navigation sidebar.',
      icon: Icons.check_circle_outline,
      highlights: [
        'Access tutorial anytime from the sidebar',
        'Review keyboard shortcuts from the menu or by pressing "?"',
        'Enjoy a focused, distraction-free school management experience',
      ],
    ),
  ];

  void _finish() {
    TourDialog.markTourSeen();
    Navigator.of(context).pop();
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 520;
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Dialog(
      backgroundColor: AppColors.mainBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rLg,
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 24,
        vertical: isNarrow ? 16 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: media.size.height - (isNarrow ? 32 : 64),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const SchoolicLogo(size: 18),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: AppRadii.rSm,
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Text(
                      'STEP ${_currentStep + 1} OF ${_steps.length}',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    tooltip: 'Close tutorial',
                    onPressed: _finish,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Step Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + Tag Row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: AppRadii.rMd,
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Icon(
                            step.icon,
                            size: 22,
                            color: AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.tag,
                                style: const TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.mutedText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                step.title,
                                style: const TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Highlights
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: AppRadii.rMd,
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: step.highlights.map((highlight) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4, right: 8),
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    highlight,
                                    style: const TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 12,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Footer Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  // Progress Dots
                  Row(
                    children: List.generate(_steps.length, (idx) {
                      final active = idx == _currentStep;
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryText
                              : AppColors.primaryBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: _prev,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(isLast ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

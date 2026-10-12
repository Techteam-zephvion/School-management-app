import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'schoolic_logo.dart';

class ShortcutEntry {
  const ShortcutEntry({
    required this.description,
    required this.keys,
  });

  final String description;
  final List<String> keys;
}

class ShortcutCategory {
  const ShortcutCategory({
    required this.title,
    required this.shortcuts,
  });

  final String title;
  final List<ShortcutEntry> shortcuts;
}

/// Schoolic Keyboard Shortcuts cheatsheet modal.
class ShortcutsDialog extends StatelessWidget {
  const ShortcutsDialog({super.key});

  static const List<ShortcutCategory> _categories = [
    ShortcutCategory(
      title: 'GENERAL & HELP',
      shortcuts: [
        ShortcutEntry(
          description: 'Open keyboard shortcuts',
          keys: ['?', 'or', 'Ctrl', '/'],
        ),
        ShortcutEntry(
          description: 'Open interactive tutorial',
          keys: ['Ctrl', 'Shift', 'T'],
        ),
        ShortcutEntry(
          description: 'Close active modal or drawer',
          keys: ['Esc'],
        ),
        ShortcutEntry(
          description: 'Refresh current dashboard data',
          keys: ['Ctrl', 'R'],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'FORM INPUTS & ACTIONS',
      shortcuts: [
        ShortcutEntry(
          description: 'Submit form or sign in',
          keys: ['Enter ↵'],
        ),
        ShortcutEntry(
          description: 'Navigate to next input field',
          keys: ['Tab'],
        ),
        ShortcutEntry(
          description: 'Navigate to previous input field',
          keys: ['Shift', 'Tab'],
        ),
        ShortcutEntry(
          description: 'Toggle password visibility',
          keys: ['Alt', 'P'],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'WORKSPACE NAVIGATION',
      shortcuts: [
        ShortcutEntry(
          description: 'Jump to Tab 1 (My Day / Overview)',
          keys: ['1'],
        ),
        ShortcutEntry(
          description: 'Jump to Tab 2 (My Week / Timetable)',
          keys: ['2'],
        ),
        ShortcutEntry(
          description: 'Jump to Tab 3 (My Classes / Students)',
          keys: ['3'],
        ),
        ShortcutEntry(
          description: 'Jump to Tab 4 (Attendance Register)',
          keys: ['4'],
        ),
        ShortcutEntry(
          description: 'Sign out and lock session',
          keys: ['Ctrl', 'Shift', 'Q'],
        ),
      ],
    ),
  ];

  /// Displays the ShortcutsDialog modal.
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 520;

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
          maxWidth: 520,
          maxHeight: media.size.height - (isNarrow ? 32 : 64),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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
                    child: const Text(
                      'KEYBOARD SHORTCUTS',
                      style: TextStyle(
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
                    tooltip: 'Close shortcuts',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.mainBackground,
                              border: Border.all(color: AppColors.primaryBorder),
                              borderRadius: AppRadii.rMd,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: category.shortcuts.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: AppColors.primaryBorder,
                              ),
                              itemBuilder: (context, idx) {
                                final item = category.shortcuts[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontFamily: 'Switzer',
                                            fontSize: 13,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: item.keys.map((k) {
                                          if (k == 'or') {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: Text(
                                                'or',
                                                style: TextStyle(
                                                  fontFamily: 'Switzer',
                                                  fontSize: 11,
                                                  color: AppColors.mutedText,
                                                ),
                                              ),
                                            );
                                          }
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              left: 3,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors
                                                  .secondaryBackground,
                                              borderRadius: AppRadii.rSm,
                                              border: Border.all(
                                                color:
                                                    AppColors.primaryBorder,
                                              ),
                                            ),
                                            child: Text(
                                              k,
                                              style: const TextStyle(
                                                fontFamily: 'Switzer',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryText,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tip: Press "?" anytime to toggle shortcuts.',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Close'),
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

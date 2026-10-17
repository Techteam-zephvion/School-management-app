import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

class CommandItem {
  const CommandItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.shortcut,
    this.onSelect,
  });

  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final String? shortcut;
  final VoidCallback? onSelect;
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    this.customItems,
    this.onActionSelected,
    super.key,
  });

  final List<CommandItem>? customItems;
  final ValueChanged<String>? onActionSelected;

  static Future<void> show(
    BuildContext context, {
    List<CommandItem>? customItems,
    ValueChanged<String>? onActionSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => CommandPaletteDialog(
        customItems: customItems,
        onActionSelected: onActionSelected,
      ),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommandItem> _buildDefaultCommands() {
    return [
      // AI & Applied Intelligence
      CommandItem(
        title: 'Natural Language Analytics Query',
        subtitle: 'Ask institutional questions in plain English (fee defaulters, attendance, toppers)',
        category: 'Applied AI',
        icon: Icons.psychology_rounded,
        shortcut: 'NL',
        onSelect: () => widget.onActionSelected?.call('action:nl_query'),
      ),
      CommandItem(
        title: 'Student At-Risk Early Warning System',
        subtitle: 'Review multi-factor risk flags (attendance, marks, fee stress) and interventions',
        category: 'Applied AI',
        icon: Icons.warning_amber_rounded,
        shortcut: 'Risk',
        onSelect: () => widget.onActionSelected?.call('action:at_risk'),
      ),
      CommandItem(
        title: 'AI Report Card Remarks Generator',
        subtitle: 'Draft personalized teacher remarks with encouraging, constructive, or formal tone',
        category: 'Applied AI',
        icon: Icons.auto_awesome_rounded,
        shortcut: 'Remarks',
        onSelect: () => widget.onActionSelected?.call('action:draft_remarks'),
      ),
      CommandItem(
        title: 'AI Homework Feedback Generator',
        subtitle: 'Draft formative rubric feedback with praise and areas for growth',
        category: 'Applied AI',
        icon: Icons.grading_rounded,
        shortcut: 'Grading',
        onSelect: () => widget.onActionSelected?.call('action:homework_feedback'),
      ),

      // Navigation
      CommandItem(
        title: 'Admin Overview & Metrics',
        subtitle: 'Institutional KPI summary, active alerts, and collection status',
        category: 'Navigation',
        icon: Icons.dashboard_outlined,
        shortcut: 'G O',
        onSelect: () => widget.onActionSelected?.call('nav:overview'),
      ),
      CommandItem(
        title: 'Students & Admissions Pipeline',
        subtitle: 'Manage admissions, applicant verification, and student profiles',
        category: 'Navigation',
        icon: Icons.people_outline,
        shortcut: 'G S',
        onSelect: () => widget.onActionSelected?.call('nav:students'),
      ),
      CommandItem(
        title: 'Attendance Register & Sync',
        subtitle: 'Daily period attendance, roster logs, and offline synchronization',
        category: 'Navigation',
        icon: Icons.fact_check_outlined,
        shortcut: 'G A',
        onSelect: () => widget.onActionSelected?.call('nav:attendance'),
      ),
      CommandItem(
        title: 'Board Examinations & Report Cards',
        subtitle: 'CBSE/ICSE grading schemes, evaluation components, and official PDF generation',
        category: 'Navigation',
        icon: Icons.school_outlined,
        shortcut: 'G E',
        onSelect: () => widget.onActionSelected?.call('nav:exams'),
      ),
      CommandItem(
        title: 'Fee Management & Concessions',
        subtitle: 'Student fee allocations, payments, concessions, and refunds ledger',
        category: 'Navigation',
        icon: Icons.account_balance_wallet_outlined,
        shortcut: 'G F',
        onSelect: () => widget.onActionSelected?.call('nav:fees'),
      ),
      CommandItem(
        title: 'School Operations & Fleet',
        subtitle: 'Leave requests, substitute suggestions, transport fleet, certificates, and PTM',
        category: 'Navigation',
        icon: Icons.directions_bus_outlined,
        shortcut: 'G P',
        onSelect: () => widget.onActionSelected?.call('nav:operations'),
      ),
      CommandItem(
        title: 'DPDP Compliance & Audit Trail',
        subtitle: 'Parental consents, immutable audit logs, and data erasure requests',
        category: 'Navigation',
        icon: Icons.shield_outlined,
        shortcut: 'G D',
        onSelect: () => widget.onActionSelected?.call('nav:compliance'),
      ),

      // Quick Actions
      CommandItem(
        title: 'Record Daily Attendance',
        subtitle: 'Open attendance register for today',
        category: 'Actions',
        icon: Icons.edit_calendar_outlined,
        onSelect: () => widget.onActionSelected?.call('action:take_attendance'),
      ),
      CommandItem(
        title: 'Create Campus Announcement',
        subtitle: 'Broadcast announcement to parents, students, or staff',
        category: 'Actions',
        icon: Icons.campaign_outlined,
        onSelect: () => widget.onActionSelected?.call('action:new_announcement'),
      ),
      CommandItem(
        title: 'Keyboard Shortcuts Help',
        subtitle: 'View complete list of power user hotkeys',
        category: 'Help',
        icon: Icons.keyboard_outlined,
        shortcut: 'Ctrl + /',
        onSelect: () => widget.onActionSelected?.call('action:shortcuts'),
      ),
    ];
  }

  List<CommandItem> _filteredCommands() {
    final all = widget.customItems ?? _buildDefaultCommands();
    if (_query.isEmpty) return all;

    return all.where((cmd) {
      final inTitle = cmd.title.toLowerCase().contains(_query);
      final inSub = cmd.subtitle.toLowerCase().contains(_query);
      final inCat = cmd.category.toLowerCase().contains(_query);
      return inTitle || inSub || inCat;
    }).toList();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final items = _filteredCommands();
    if (items.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeCommand(items[_selectedIndex]);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _executeCommand(CommandItem item) {
    Navigator.of(context).pop();
    item.onSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final items = _filteredCommands();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: media.size.width < 640 ? 12 : 32,
          vertical: 32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 520,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: AppRadii.rLg,
              border: Border.all(color: AppColors.primaryBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppColors.secondaryText,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryText,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a command, search records, or jump to view...',
                            hintStyle: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: AppRadii.rSm,
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Text(
                          'ESC',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.primaryBorder),

                // Command Items List
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: AppColors.secondaryText,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No matching commands or actions found for "$_query"',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySecondary.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = index == _selectedIndex;

                            return InkWell(
                              onTap: () => _executeCommand(item),
                              hoverColor: AppColors.accent.withValues(alpha: 0.05),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: AppRadii.rMd,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accent.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.accent.withValues(alpha: 0.15)
                                            : AppColors.secondaryBackground,
                                        borderRadius: AppRadii.rSm,
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 17,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    fontFamily: AppTypography.fontFamily,
                                                    fontSize: 13.5,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                    color: isSelected
                                                        ? AppColors.accent
                                                        : AppColors.primaryText,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.secondaryBackground,
                                                  borderRadius: AppRadii.rSm,
                                                  border: Border.all(
                                                    color: AppColors.primaryBorder,
                                                  ),
                                                ),
                                                child: Text(
                                                  item.category.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontFamily: AppTypography.fontFamily,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.3,
                                                    color: AppColors.secondaryText,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            style: const TextStyle(
                                              fontFamily: AppTypography.fontFamily,
                                              fontSize: 11.5,
                                              color: AppColors.secondaryText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.shortcut != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryBackground,
                                          borderRadius: AppRadii.rSm,
                                          border: Border.all(
                                            color: AppColors.primaryBorder,
                                          ),
                                        ),
                                        child: Text(
                                          item.shortcut!,
                                          style: const TextStyle(
                                            fontFamily: AppTypography.fontFamily,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Help Footer
                const Divider(height: 1, color: AppColors.primaryBorder),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Navigate: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                          _shortcutKey('↑'),
                          const SizedBox(width: 4),
                          _shortcutKey('↓'),
                          const SizedBox(width: 12),
                          const Text(
                            'Select: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                          _shortcutKey('↵'),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Hotkey: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                          _shortcutKey('⌘K / Ctrl+K'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcutKey(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: AppRadii.rSm,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}

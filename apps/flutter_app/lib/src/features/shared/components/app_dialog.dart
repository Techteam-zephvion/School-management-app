import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.maxWidth = 460,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.mainBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rLg,
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.subsectionHeading),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: AppTypography.metadata),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Content body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),

            // Actions footer
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.primaryBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

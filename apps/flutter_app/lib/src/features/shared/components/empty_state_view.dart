import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Icon(icon, size: 22, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.subsectionHeading, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              description,
              style: AppTypography.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

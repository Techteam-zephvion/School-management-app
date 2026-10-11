import 'package:flutter/material.dart';

import '../../../core/theme.dart';

enum FeedbackTone {
  info,
  success,
  warning,
  error,
}

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    required this.message,
    this.tone = FeedbackTone.info,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    super.key,
  });

  final String message;
  final FeedbackTone tone;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor, iconData) = _resolveColors();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 16, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDismiss,
              child: Icon(Icons.close, size: 14, color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, Color, IconData) _resolveColors() {
    switch (tone) {
      case FeedbackTone.success:
        return (
          AppColors.statusSuccess,
          AppColors.statusSuccess.withValues(alpha: 0.06),
          AppColors.statusSuccess.withValues(alpha: 0.25),
          Icons.check_circle_outline,
        );
      case FeedbackTone.error:
        return (
          AppColors.statusError,
          AppColors.statusError.withValues(alpha: 0.06),
          AppColors.statusError.withValues(alpha: 0.25),
          Icons.error_outline,
        );
      case FeedbackTone.warning:
        return (
          AppColors.statusWarning,
          AppColors.statusWarning.withValues(alpha: 0.06),
          AppColors.statusWarning.withValues(alpha: 0.25),
          Icons.warning_amber_outlined,
        );
      case FeedbackTone.info:
        return (
          AppColors.primaryText,
          AppColors.secondaryBackground,
          AppColors.primaryBorder,
          Icons.info_outline,
        );
    }
  }
}

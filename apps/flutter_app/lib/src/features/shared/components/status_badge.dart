import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../core/theme.dart';

enum BadgeTone {
  neutral,
  success,
  warning,
  error,
  info,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.filled = false,
    super.key,
  });

  factory StatusBadge.attendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const StatusBadge(
          label: 'Present',
          tone: BadgeTone.success,
          icon: Icons.check,
        );
      case AttendanceStatus.absent:
        return const StatusBadge(
          label: 'Absent',
          tone: BadgeTone.error,
          icon: Icons.close,
        );
      case AttendanceStatus.late:
        return const StatusBadge(
          label: 'Late',
          tone: BadgeTone.warning,
          icon: Icons.schedule,
        );
      case AttendanceStatus.excused:
        return const StatusBadge(
          label: 'Excused',
          tone: BadgeTone.info,
          icon: Icons.event_available,
        );
    }
  }

  factory StatusBadge.fromStatusString(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
        return const StatusBadge(label: 'PRESENT', tone: BadgeTone.success);
      case 'absent':
        return const StatusBadge(label: 'ABSENT', tone: BadgeTone.error);
      case 'late':
        return const StatusBadge(label: 'LATE', tone: BadgeTone.warning);
      case 'excused':
        return const StatusBadge(label: 'EXCUSED', tone: BadgeTone.info);
      case 'completed':
        return const StatusBadge(label: 'COMPLETED', tone: BadgeTone.success);
      case 'pending':
        return const StatusBadge(label: 'PENDING', tone: BadgeTone.warning);
      default:
        return StatusBadge(label: status?.toUpperCase() ?? '—', tone: BadgeTone.neutral);
    }
  }

  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = _colors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.rSm,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _colors() {
    switch (tone) {
      case BadgeTone.success:
        return (
          AppColors.statusSuccess,
          AppColors.statusSuccess.withValues(alpha: 0.08),
          AppColors.statusSuccess.withValues(alpha: 0.25),
        );
      case BadgeTone.error:
        return (
          AppColors.statusError,
          AppColors.statusError.withValues(alpha: 0.08),
          AppColors.statusError.withValues(alpha: 0.25),
        );
      case BadgeTone.warning:
        return (
          AppColors.statusWarning,
          AppColors.statusWarning.withValues(alpha: 0.08),
          AppColors.statusWarning.withValues(alpha: 0.25),
        );
      case BadgeTone.info:
        return (
          AppColors.statusInfo,
          AppColors.statusInfo.withValues(alpha: 0.08),
          AppColors.statusInfo.withValues(alpha: 0.25),
        );
      case BadgeTone.neutral:
        return (
          AppColors.secondaryText,
          AppColors.secondaryBackground,
          AppColors.primaryBorder,
        );
    }
  }
}

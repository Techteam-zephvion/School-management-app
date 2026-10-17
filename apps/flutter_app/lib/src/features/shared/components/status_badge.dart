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

  factory StatusBadge.riskLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'critical':
        return const StatusBadge(
          label: 'CRITICAL RISK',
          tone: BadgeTone.error,
          icon: Icons.warning_amber_rounded,
        );
      case 'high':
        return const StatusBadge(
          label: 'HIGH RISK',
          tone: BadgeTone.error,
          icon: Icons.priority_high_rounded,
        );
      case 'moderate':
        return const StatusBadge(
          label: 'MODERATE RISK',
          tone: BadgeTone.warning,
          icon: Icons.trending_down_rounded,
        );
      case 'low':
      default:
        return const StatusBadge(
          label: 'LOW RISK',
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }

  factory StatusBadge.payrollStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return const StatusBadge(
          label: 'PAID',
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'approved':
      case 'processed':
        return const StatusBadge(
          label: 'APPROVED',
          tone: BadgeTone.info,
          icon: Icons.verified_outlined,
        );
      case 'voided':
        return const StatusBadge(
          label: 'VOID',
          tone: BadgeTone.error,
          icon: Icons.block_rounded,
        );
      case 'draft':
      default:
        return const StatusBadge(
          label: 'DRAFT',
          tone: BadgeTone.neutral,
          icon: Icons.edit_note_rounded,
        );
    }
  }

  factory StatusBadge.inventoryCondition(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'new':
        return const StatusBadge(label: 'NEW', tone: BadgeTone.success);
      case 'good':
        return const StatusBadge(label: 'GOOD', tone: BadgeTone.success);
      case 'fair':
        return const StatusBadge(label: 'FAIR', tone: BadgeTone.info);
      case 'maintenance_required':
      case 'under_repair':
        return const StatusBadge(label: 'MAINTENANCE', tone: BadgeTone.warning);
      case 'damaged':
        return const StatusBadge(label: 'DAMAGED', tone: BadgeTone.error);
      case 'disposed':
        return const StatusBadge(label: 'DISPOSED', tone: BadgeTone.neutral);
      default:
        return StatusBadge(label: condition?.toUpperCase() ?? 'GOOD', tone: BadgeTone.neutral);
    }
  }

  factory StatusBadge.deviceStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return const StatusBadge(
          label: 'ONLINE',
          tone: BadgeTone.success,
          icon: Icons.wifi_rounded,
        );
      case 'maintenance':
        return const StatusBadge(
          label: 'MAINTENANCE',
          tone: BadgeTone.warning,
          icon: Icons.build_circle_outlined,
        );
      case 'decommissioned':
        return const StatusBadge(
          label: 'DECOMMISSIONED',
          tone: BadgeTone.neutral,
          icon: Icons.do_not_disturb_on_outlined,
        );
      case 'offline':
      default:
        return const StatusBadge(
          label: 'OFFLINE',
          tone: BadgeTone.error,
          icon: Icons.wifi_off_rounded,
        );
    }
  }

  factory StatusBadge.transferStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return const StatusBadge(
          label: 'COMPLETED',
          tone: BadgeTone.success,
          icon: Icons.check_circle_rounded,
        );
      case 'approved':
        return const StatusBadge(
          label: 'APPROVED',
          tone: BadgeTone.info,
          icon: Icons.thumb_up_alt_outlined,
        );
      case 'rejected':
        return const StatusBadge(
          label: 'REJECTED',
          tone: BadgeTone.error,
          icon: Icons.cancel_outlined,
        );
      case 'cancelled':
        return const StatusBadge(
          label: 'CANCELLED',
          tone: BadgeTone.neutral,
          icon: Icons.block_rounded,
        );
      case 'pending':
      default:
        return const StatusBadge(
          label: 'PENDING',
          tone: BadgeTone.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }

  factory StatusBadge.bloomLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'remember':
        return const StatusBadge(label: 'REMEMBER', tone: BadgeTone.neutral);
      case 'understand':
        return const StatusBadge(label: 'UNDERSTAND', tone: BadgeTone.info);
      case 'apply':
        return const StatusBadge(label: 'APPLY', tone: BadgeTone.success);
      case 'analyze':
        return const StatusBadge(label: 'ANALYZE', tone: BadgeTone.warning);
      case 'evaluate':
        return const StatusBadge(label: 'EVALUATE', tone: BadgeTone.warning);
      case 'create':
        return const StatusBadge(label: 'CREATE', tone: BadgeTone.error);
      default:
        return StatusBadge(label: level?.toUpperCase() ?? 'COGNITIVE', tone: BadgeTone.neutral);
    }
  }

  factory StatusBadge.transcriptStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'dispatched':
        return const StatusBadge(
          label: 'DISPATCHED',
          tone: BadgeTone.success,
          icon: Icons.local_shipping_outlined,
        );
      case 'ready':
        return const StatusBadge(
          label: 'READY',
          tone: BadgeTone.info,
          icon: Icons.mark_email_read_outlined,
        );
      case 'processing':
        return const StatusBadge(
          label: 'PROCESSING',
          tone: BadgeTone.info,
          icon: Icons.sync_rounded,
        );
      case 'rejected':
        return const StatusBadge(
          label: 'REJECTED',
          tone: BadgeTone.error,
          icon: Icons.highlight_off_rounded,
        );
      case 'submitted':
      default:
        return const StatusBadge(
          label: 'SUBMITTED',
          tone: BadgeTone.warning,
          icon: Icons.hourglass_bottom_rounded,
        );
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

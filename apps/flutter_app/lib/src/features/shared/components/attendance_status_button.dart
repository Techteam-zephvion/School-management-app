import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../core/theme.dart';

class AttendanceStatusGroup extends StatelessWidget {
  const AttendanceStatusGroup({
    required this.selectedStatus,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final AttendanceStatus selectedStatus;
  final ValueChanged<AttendanceStatus> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(AttendanceStatus.present, 'Present', 'P', Icons.check, AppColors.statusSuccess),
          _buildItem(AttendanceStatus.absent, 'Absent', 'A', Icons.close, AppColors.statusError),
          _buildItem(AttendanceStatus.late, 'Late', 'L', Icons.schedule, AppColors.statusWarning),
          _buildItem(AttendanceStatus.excused, 'Excused', 'E', Icons.event_available, AppColors.statusInfo),
        ],
      ),
    );
  }

  Widget _buildItem(
    AttendanceStatus status,
    String label,
    String shortLabel,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = selectedStatus == status;

    return InkWell(
      onTap: () => onChanged(status),
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.curve,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mainBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: activeColor.withValues(alpha: 0.4), width: 1) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : AppColors.mutedText,
            ),
            const SizedBox(width: 5),
            Text(
              compact ? shortLabel : label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

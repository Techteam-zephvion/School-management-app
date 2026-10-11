import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class StatItemData {
  const StatItemData({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;
}

class StatStrip extends StatelessWidget {
  const StatStrip({
    required this.items,
    super.key,
  });

  final List<StatItemData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        if (isMobile) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              border: Border.all(color: AppColors.primaryBorder),
              borderRadius: AppRadii.rLg,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
              itemBuilder: (context, index) => _buildSegment(items[index]),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const VerticalDivider(width: 1, color: AppColors.primaryBorder),
                  Expanded(child: _buildSegment(items[i])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegment(StatItemData item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label.toUpperCase(), style: AppTypography.label),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: AppColors.primaryText,
            ),
          ),
          if (item.helper != null) ...[
            const SizedBox(height: 4),
            Text(item.helper!, style: AppTypography.metadata),
          ],
        ],
      ),
    );
  }
}

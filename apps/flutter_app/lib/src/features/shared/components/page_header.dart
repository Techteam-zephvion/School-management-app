import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.description,
    this.badge,
    this.primaryAction,
    this.secondaryActions,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? badge;
  final Widget? primaryAction;
  final List<Widget>? secondaryActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        final titleAndBadge = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: AppTypography.pageTitle),
            if (badge != null) ...[
              const SizedBox(width: 10),
              badge!,
            ],
          ],
        );

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleAndBadge,
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!, style: AppTypography.bodySecondary),
            ],
          ],
        );

        final actionsBlock = (primaryAction != null || (secondaryActions?.isNotEmpty ?? false))
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  ...?secondaryActions,
                  ?primaryAction,
                ],
              )
            : null;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              if (actionsBlock != null) ...[
                const SizedBox(height: 16),
                actionsBlock,
              ],
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: textBlock),
            if (actionsBlock != null) ...[
              const SizedBox(width: 16),
              actionsBlock,
            ],
          ],
        );
      },
    );
  }
}

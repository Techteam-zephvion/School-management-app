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
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                style: isNarrow
                    ? AppTypography.pageTitle.copyWith(fontSize: 23)
                    : AppTypography.pageTitle,
                softWrap: true,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 10),
              Flexible(flex: 0, child: badge!),
            ],
          ],
        );

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleAndBadge,
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: AppTypography.bodySecondary,
                softWrap: true,
              ),
            ],
          ],
        );

        final actionsBlock =
            (primaryAction != null || (secondaryActions?.isNotEmpty ?? false))
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [...?secondaryActions, ?primaryAction],
              )
            : null;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textBlock,
              if (actionsBlock != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: actionsBlock),
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

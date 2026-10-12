import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class AppTableColumn<T> {
  const AppTableColumn({
    required this.header,
    required this.cellBuilder,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  final String header;
  final Widget Function(BuildContext context, T item) cellBuilder;
  final int flex;
  final double? width;
  final Alignment alignment;
}

class AppTable<T> extends StatefulWidget {
  const AppTable({
    required this.title,
    required this.columns,
    required this.items,
    this.subtitle,
    this.count,
    this.actions,
    this.onRowTap,
    this.emptyMessage = 'No records available.',
    this.searchHint,
    this.filterPredicate,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? count;
  final List<AppTableColumn<T>> columns;
  final List<T> items;
  final List<Widget>? actions;
  final void Function(T item)? onRowTap;
  final String emptyMessage;
  final String? searchHint;
  final bool Function(T item, String query)? filterPredicate;

  @override
  State<AppTable<T>> createState() => _AppTableState<T>();
}

class _AppTableState<T> extends State<AppTable<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.filterPredicate != null && _query.isNotEmpty
        ? widget.items.where((item) => widget.filterPredicate!(item, _query)).toList()
        : widget.items;

    final displayCount = widget.count ?? widget.items.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: AppRadii.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 560;

                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: AppTypography.subsectionHeading),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: AppRadii.rSm,
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Text(
                            '$displayCount',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.subtitle!, style: AppTypography.metadata),
                    ],
                  ],
                );

                final searchWidget = widget.filterPredicate != null
                    ? SizedBox(
                        width: isNarrow ? double.infinity : 200,
                        height: 32,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: widget.searchHint ?? 'Filter records...',
                            hintStyle: AppTypography.metadata,
                            prefixIcon: const Icon(Icons.search, size: 15, color: AppColors.mutedText),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14, color: AppColors.mutedText),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            filled: true,
                            fillColor: AppColors.secondaryBackground,
                            border: OutlineInputBorder(
                              borderRadius: AppRadii.rMd,
                              borderSide: const BorderSide(color: AppColors.primaryBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppRadii.rMd,
                              borderSide: const BorderSide(color: AppColors.primaryBorder),
                            ),
                          ),
                        ),
                      )
                    : null;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleBlock,
                      if (searchWidget != null || widget.actions != null) const SizedBox(height: 12),
                      ?searchWidget,
                      if (widget.actions != null) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: widget.actions!),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    if (searchWidget != null) ...[
                      searchWidget,
                      const SizedBox(width: 12),
                    ],
                    if (widget.actions != null) ...widget.actions!,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.primaryBorder),

          // Responsive Table Columns & Rows with Horizontal Scroll when needed
          LayoutBuilder(
            builder: (context, tableConstraints) {
              double totalMinWidth = 0;
              for (final col in widget.columns) {
                totalMinWidth += col.width ?? (col.flex * 120.0);
              }
              final useScroll = tableConstraints.maxWidth < totalMinWidth;
              final contentWidth = useScroll ? totalMinWidth : tableConstraints.maxWidth;

              final tableContent = SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    // Column headers
                    Container(
                      color: AppColors.secondaryBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: widget.columns.map((col) {
                          final headerText = Text(
                            col.header.toUpperCase(),
                            style: AppTypography.label,
                          );

                          if (col.width != null) {
                            return SizedBox(
                              width: col.width,
                              child: Align(alignment: col.alignment, child: headerText),
                            );
                          }
                          return Expanded(
                            flex: col.flex,
                            child: Align(alignment: col.alignment, child: headerText),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.primaryBorder),

                    // Table Rows
                    if (filteredItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          _query.isNotEmpty ? 'No records match "$_query"' : widget.emptyMessage,
                          style: AppTypography.bodySecondary,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.primaryBorder),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return InkWell(
                            onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
                            hoverColor: AppColors.secondaryBackground,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                children: widget.columns.map((col) {
                                  final cell = col.cellBuilder(context, item);
                                  if (col.width != null) {
                                    return SizedBox(
                                      width: col.width,
                                      child: Align(alignment: col.alignment, child: cell),
                                    );
                                  }
                                  return Expanded(
                                    flex: col.flex,
                                    child: Align(alignment: col.alignment, child: cell),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );

              return useScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: tableContent,
                    )
                  : tableContent;
            },
          ),
        ],
      ),
    );
  }
}

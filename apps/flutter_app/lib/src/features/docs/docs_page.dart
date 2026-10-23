import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/empty_state_view.dart';
import '../shared/components/schoolic_logo.dart';
import 'docs_data.dart';
import 'docs_screenshot_viewer.dart';

class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({
    this.isEmbedded = false,
    this.onBack,
    this.initialFeatureId,
    super.key,
  });

  final bool isEmbedded;
  final VoidCallback? onBack;
  final String? initialFeatureId;

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage> {
  final _searchController = TextEditingController();
  DocCategory? _selectedCategory;
  DocRole? _selectedRole;
  late DocFeature _activeFeature;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFeatureId != null
        ? DocsCatalog.findById(widget.initialFeatureId!)
        : null;
    _activeFeature = initial ?? DocsCatalog.features.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }





  @override
  Widget build(BuildContext context) {
    final filteredFeatures = DocsCatalog.filter(
      query: _searchController.text,
      category: _selectedCategory,
      role: _selectedRole,
    );

    // If active feature is filtered out, select first matching
    if (!filteredFeatures.contains(_activeFeature) &&
        filteredFeatures.isNotEmpty) {
      _activeFeature = filteredFeatures.first;
    }

    final isWide = MediaQuery.of(context).size.width >= 860;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: _buildTopBar(context),
      body: Column(
        children: [
          // Filter & Search Controls Header
          _buildFilterBar(filteredFeatures.length),
          const Divider(height: 1, color: AppColors.primaryBorder),

          // Main Split Area
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Sidebar Feature Index
                      SizedBox(
                        width: 320,
                        child: _buildFeaturesList(filteredFeatures),
                      ),
                      const VerticalDivider(
                          width: 1, color: AppColors.primaryBorder),

                      // Right Content Pane
                      Expanded(
                        child: _buildFeatureContent(_activeFeature),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Top category selector on small screens
                      SizedBox(
                        height: 52,
                        child: _buildCategoryChips(),
                      ),
                      const Divider(height: 1, color: AppColors.primaryBorder),
                      Expanded(
                        child: _buildFeatureContent(_activeFeature),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.mainBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.primaryBorder),
      ),
      leading: widget.isEmbedded
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
              onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Row(
        children: [
          const SchoolicLogo(size: 24),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.secondaryBorder),
            ),
            child: const Text(
              'DOCUMENTATION & HOW-TO GUIDE',
              style: TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                final auth = ref.read(authControllerProvider);
                if (auth.session != null) {
                  if (auth.session!.isAdmin) {
                    context.go('/admin');
                  } else if (auth.session!.isTeacher) {
                    context.go('/teacher');
                  } else {
                    context.go('/portal');
                  }
                } else {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                ref.read(authControllerProvider).session != null
                    ? 'Return to Dashboard'
                    : 'Sign In to Schoolic',
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                side: const BorderSide(color: AppColors.secondaryBorder),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar(int resultCount) {
    return Container(
      color: AppColors.mainBackground,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Search input
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Search features, processes, or how-to steps (e.g. Attendance, Cashfree, Leaves)...',
                      hintStyle: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: AppColors.secondaryText),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      filled: true,
                      fillColor: AppColors.secondaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.primaryBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.primaryBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.primaryText),
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Results count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  '$resultCount features',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Role filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Role Filter:',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoleChip(null, 'All Roles'),
                _buildRoleChip(DocRole.admin, 'Administrator'),
                _buildRoleChip(DocRole.teacher, 'Teacher'),
                _buildRoleChip(DocRole.student, 'Student'),
                _buildRoleChip(DocRole.parent, 'Parent'),
                _buildRoleChip(DocRole.accountant, 'Accountant'),
                _buildRoleChip(DocRole.principal, 'Principal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(DocRole? role, String label) {
    final isSelected = _selectedRole == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontFamily: 'Switzer',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.primaryText,
        ),
        backgroundColor: AppColors.secondaryBackground,
        selectedColor: AppColors.primaryText,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryText
                : AppColors.primaryBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onSelected: (_) => setState(() => _selectedRole = role),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildCategoryChip(null, 'All Categories', Icons.grid_view),
        ...DocCategory.values.map(
          (cat) => _buildCategoryChip(cat, cat.label, cat.icon),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
      DocCategory? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        avatar: Icon(icon,
            size: 14,
            color: isSelected ? Colors.white : AppColors.secondaryText),
        label: Text(label),
        labelStyle: TextStyle(
          fontFamily: 'Switzer',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.primaryText,
        ),
        backgroundColor: AppColors.secondaryBackground,
        selectedColor: AppColors.primaryText,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? AppColors.primaryText
                : AppColors.primaryBorder,
          ),
        ),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }

  Widget _buildFeaturesList(List<DocFeature> features) {
    if (features.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStateView(
            title: 'No matching features',
            description: 'Try adjusting your search query or role filter.',
            icon: Icons.search_off_outlined,
          ),
        ),
      );
    }

    // Group features by category
    final Map<DocCategory, List<DocFeature>> grouped = {};
    for (final f in features) {
      grouped.putIfAbsent(f.category, () => []).add(f);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: grouped.entries.expand((entry) {
        final category = entry.key;
        final items = entry.value;

        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Icon(category.icon,
                    size: 14, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Text(
                  category.label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.secondaryText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          ...items.map((feature) {
            final isSelected = feature.id == _activeFeature.id;
            return InkWell(
              onTap: () {
                setState(() => _activeFeature = feature);
              },
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryText
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.roles.map((r) => r.label).join(' • '),
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 11,
                        color: isSelected
                            ? const Color(0xFFD4D4D4)
                            : AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ];
      }).toList(),
    );
  }

  Widget _buildFeatureContent(DocFeature feature) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.secondaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feature.category.icon,
                        size: 13, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      feature.category.label,
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              ...feature.roles.map(
                (role) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Text(
                    role.label,
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            feature.title,
            style: const TextStyle(
              fontFamily: 'Switzer',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Executive Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Text(
              feature.summary,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 14,
                height: 1.5,
                color: AppColors.primaryText,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Prerequisites & Key Tips Section
          if (feature.prerequisites.isNotEmpty || feature.keyTips.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feature.prerequisites.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.mainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16, color: AppColors.statusSuccess),
                              SizedBox(width: 8),
                              Text(
                                'Prerequisites',
                                style: TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...feature.prerequisites.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          color: AppColors.secondaryText)),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontFamily: 'Switzer',
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (feature.keyTips.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.mainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 16, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Operational Tips',
                                style: TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...feature.keyTips.map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ',
                                      style: TextStyle(
                                          color: AppColors.secondaryText)),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: const TextStyle(
                                        fontFamily: 'Switzer',
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),

          // Step-by-Step Workflow Section
          const Row(
            children: [
              Icon(Icons.format_list_numbered,
                  size: 20, color: AppColors.primaryText),
              SizedBox(width: 10),
              Text(
                'How To Use It: Step-by-Step Process',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...feature.howToUse.map((step) => _buildStepItem(step)),
        ],
      ),
    );
  }

  Widget _buildStepItem(DocStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryText,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${step.stepNumber}',
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (step.tip != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Tip: ${step.tip!}',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
                if (step.screenshotAssetPath != null) ...[
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      final shot = DocScreenshot(
                        id: '${_activeFeature.id}_step_${step.stepNumber}',
                        featureId: _activeFeature.id,
                        fileName: '${_activeFeature.id}_step${step.stepNumber}.png',
                        caption: 'Step ${step.stepNumber}: ${step.title} — ${step.description}',
                        assetPath: step.screenshotAssetPath,
                      );
                      DocsScreenshotViewer.show(
                        context,
                        screenshot: shot,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: Image.asset(
                              step.screenshotAssetPath!,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryBackground,
                              border: Border(
                                top: BorderSide(color: AppColors.primaryBorder),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.zoom_in,
                                    size: 14, color: AppColors.secondaryText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Step ${step.stepNumber} visual walkthrough screenshot — click to view full size',
                                    style: const TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


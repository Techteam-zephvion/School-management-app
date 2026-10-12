import 'package:flutter/material.dart';
import 'package:schoolic/src/core/theme.dart';

/// Official Schoolic branding logo.
/// Renders full horizontal brand ('Schoolic.') by default,
/// or compact mark ('S.') when [isCompact] is true.
/// Rendered with bundled Switzer-Bold typography.
class SchoolicLogo extends StatelessWidget {
  const SchoolicLogo({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryText,
    this.isCompact = false,
  });

  const SchoolicLogo.compact({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryText,
  }) : isCompact = true;

  /// Visual size in logical pixels (font size of the mark).
  final double size;

  /// Foreground color of the mark (defaults to #111111).
  final Color color;

  /// Whether to render the compact mark ('S.') or full horizontal brand ('Schoolic.').
  /// Defaults to false (horizontal full name 'Schoolic.').
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Schoolic',
      excludeSemantics: true,
      child: Text(
        isCompact ? 'S.' : 'Schoolic.',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.fallbackFonts,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

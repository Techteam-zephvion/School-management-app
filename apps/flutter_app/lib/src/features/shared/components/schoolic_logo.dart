import 'package:flutter/material.dart';
import 'package:schoolic/src/core/theme.dart';

/// Official minimalist Schoolic logo mark ('S.').
/// Rendered with bundled Switzer-Bold typography.
class SchoolicLogo extends StatelessWidget {
  const SchoolicLogo({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryText,
  });

  /// Visual size in logical pixels (font size of the mark).
  final double size;

  /// Foreground color of the mark (defaults to #111111).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Schoolic',
      excludeSemantics: true,
      child: Text(
        'S.',
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

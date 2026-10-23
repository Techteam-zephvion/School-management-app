import 'package:flutter/material.dart';
import 'package:schoolic/src/core/theme.dart';

/// Official Schoolic branding logo.
/// Implements the Official Logo System (Slide 2):
/// - Full horizontal brand ('Schoolic') with Electric Cyan Square Period (#00A3FF)
/// - Compact mark ('S') with Electric Cyan Square Period (#00A3FF)
/// Rendered with bundled Switzer-Bold typography.
class SchoolicLogo extends StatelessWidget {
  const SchoolicLogo({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryText,
    this.dotColor = AppColors.brandCyan,
    this.isCompact = false,
  });

  const SchoolicLogo.compact({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryText,
    this.dotColor = AppColors.brandCyan,
  }) : isCompact = true;

  /// Visual size in logical pixels (font size of the mark).
  final double size;

  /// Foreground color of the mark (defaults to #111111).
  final Color color;

  /// Color of the signature square period (defaults to Official Brand Cyan #00A3FF).
  final Color dotColor;

  /// Whether to render the compact mark ('S.') or full horizontal brand ('Schoolic.').
  /// Defaults to false (horizontal full name 'Schoolic.').
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    // Proportions matching the official design system:
    // Square period has width approx 20% of font size, slightly separated from wordmark
    final dotSize = (size * 0.20).clamp(3.0, 48.0);
    final gap = (size * 0.08).clamp(2.0, 16.0);

    return Semantics(
      label: 'Schoolic',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isCompact ? 'S' : 'Schoolic',
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
          SizedBox(width: gap),
          Padding(
            padding: EdgeInsets.only(bottom: (size * 0.12).clamp(1.0, 16.0)),
            child: Container(
              width: dotSize,
              height: dotSize,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

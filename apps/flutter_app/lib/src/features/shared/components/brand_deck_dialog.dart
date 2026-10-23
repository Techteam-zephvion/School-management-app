import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../core/theme.dart';
import 'schoolic_logo.dart';

class BrandDeckSlide {
  const BrandDeckSlide({
    required this.number,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.assetPath,
  });

  final int number;
  final String tag;
  final String title;
  final String subtitle;
  final String description;
  final String assetPath;
}

/// Official Schoolic Brand Design System & Consolidated Presentation Deck viewer.
class BrandDeckDialog extends StatefulWidget {
  const BrandDeckDialog({super.key});

  static const List<BrandDeckSlide> slides = [
    BrandDeckSlide(
      number: 1,
      tag: 'KEY ART',
      title: 'The Operating System for Modern Schools',
      subtitle: 'Clarity / Intelligence / Trust',
      description:
          'Schoolic introduces an executive aesthetic combining sharp typography, clean monochromatic structures, and electric cyan accents anchored by Lord Espandor.',
      assetPath: 'assets/branding/presentation_slide_1_hero.png',
    ),
    BrandDeckSlide(
      number: 2,
      tag: 'LOGO SYSTEM',
      title: 'Wordmark Lockup & Precision Mark',
      subtitle: 'Primary Mark, Reverse Mark & App Icon',
      description:
          'Geometric Switzer typography with a signature Electric Cyan (#00A3FF) square period. Engineered with mathematical clear space and high-contrast adaptability across light and dark interfaces.',
      assetPath: 'assets/branding/presentation_slide_2_logo_system.png',
    ),
    BrandDeckSlide(
      number: 3,
      tag: 'MASCOT & CHARACTER',
      title: 'Lord Espandor',
      subtitle: 'Suave Institutional Aristocrat',
      description:
          'The raven aristocrat in tailored white formalwear with electric blue trim, black cape, and walking cane. Represents intellect, foresight, and authoritative calm in school leadership.',
      assetPath: 'assets/branding/presentation_slide_3_lord_espandor.png',
    ),
    BrandDeckSlide(
      number: 4,
      tag: 'PATTERNS & TEXTURES',
      title: 'Brand Visual Language',
      subtitle: 'Wavy Layers, Chevrons & Merchandise',
      description:
          'Fluid architectural contours with illuminated cyan filaments, chevron feather alignments, and institutional stationery notebook aesthetics.',
      assetPath: 'assets/branding/presentation_slide_4_patterns.png',
    ),
    BrandDeckSlide(
      number: 5,
      tag: 'USER INTERFACE',
      title: 'Multi-Device Experience',
      subtitle: 'Smarter Schools · Brighter Tomorrows',
      description:
          'Unified design language across Mobile Login, Desktop Administrative Command, and Tablet Educator Dayflow with light blue active indicators and clean data cards.',
      assetPath: 'assets/branding/presentation_slide_5_ui_showcase.png',
    ),
    BrandDeckSlide(
      number: 6,
      tag: 'PHYSICAL COLLATERAL',
      title: 'Institutional Identity in the Physical World',
      subtitle: 'Badges, Folders, Wall Signage & Wayfinding',
      description:
          'Executive staff and student identification cards with embedded barcode and Lord Espandor insignia, architectural marble wall logos, and campus directional displays.',
      assetPath: 'assets/branding/presentation_slide_6_collateral.png',
    ),
    BrandDeckSlide(
      number: 7,
      tag: 'CAMPAIGNS & SOCIAL',
      title: 'Brand Communications & Growth',
      subtitle: 'Posters, Stories & LinkedIn Announcements',
      description:
          'High-impact square social collateral, mobile vertical stories, and institutional awareness posters featuring Lord Espandor in diverse academic environments.',
      assetPath: 'assets/branding/presentation_slide_7_campaigns.png',
    ),
  ];

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const BrandDeckDialog(),
    );
  }

  @override
  State<BrandDeckDialog> createState() => _BrandDeckDialogState();
}

class _BrandDeckDialogState extends State<BrandDeckDialog> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < BrandDeckDialog.slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openPdf() async {
    try {
      final bytes = await rootBundle
          .load('assets/branding/schoolic_brand_presentation.pdf');
      await Printing.sharePdf(
        bytes: bytes.buffer.asUint8List(),
        filename: 'schoolic_brand_presentation.pdf',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 768;

    return Dialog(
      backgroundColor: AppColors.mainBackground,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 32,
        vertical: isCompact ? 16 : 28,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: media.size.height - (isCompact ? 32 : 56),
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
              ),
              child: Row(
                children: [
                  const SchoolicLogo(size: 20),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandCyanSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.brandCyanBorder),
                    ),
                    child: const Text(
                      'BRAND DECK',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.brandCyanDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Open PDF action
                  TextButton.icon(
                    onPressed: _openPdf,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.brandCyanDark),
                    label: Text(
                      isCompact ? 'PDF' : 'Download Consolidated PDF',
                      style: const TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandCyanDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 20,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),

            // Slide content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: BrandDeckDialog.slides.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final s = BrandDeckDialog.slides[index];
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image Presentation Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border.all(color: AppColors.primaryBorder),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: AspectRatio(
                              aspectRatio: 1672 / 941,
                              child: Image.asset(
                                s.assetPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Slide Details
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryText,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.tag,
                                style: const TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.subtitle,
                                    style: const TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brandCyanDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    s.description,
                                    style: const TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 13,
                                      color: AppColors.secondaryText,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.primaryBorder)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentIndex > 0 ? _prev : null,
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  // Indicator dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      BrandDeckDialog.slides.length,
                      (i) => GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Container(
                          width: i == _currentIndex ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _currentIndex ? AppColors.brandCyan : AppColors.secondaryBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _currentIndex < BrandDeckDialog.slides.length - 1
                        ? _next
                        : () => Navigator.of(context).pop(),
                    icon: Icon(
                      _currentIndex < BrandDeckDialog.slides.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      size: 14,
                    ),
                    label: Text(_currentIndex < BrandDeckDialog.slides.length - 1 ? 'Next' : 'Finish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

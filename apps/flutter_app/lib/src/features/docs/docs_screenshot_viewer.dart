import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'docs_data.dart';

/// Interactive modal lightbox displaying a screenshot in high-resolution with zoom, pan, and caption details.
class DocsScreenshotViewer extends StatelessWidget {
  const DocsScreenshotViewer({
    required this.screenshot,
    this.onDelete,
    super.key,
  });

  final DocScreenshot screenshot;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required DocScreenshot screenshot,
    VoidCallback? onDelete,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => DocsScreenshotViewer(
        screenshot: screenshot,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (screenshot.base64Data != null && screenshot.base64Data!.isNotEmpty) {
      try {
        final bytes = base64Decode(screenshot.base64Data!);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
        );
      } catch (_) {
        imageWidget = _buildErrorPlaceholder();
      }
    } else if (screenshot.networkUrl != null &&
        screenshot.networkUrl!.isNotEmpty) {
      imageWidget = Image.network(
        screenshot.networkUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
      );
    } else if (screenshot.assetPath != null &&
        screenshot.assetPath!.isNotEmpty) {
      imageWidget = Image.asset(
        screenshot.assetPath!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
      );
    } else {
      imageWidget = _buildErrorPlaceholder();
    }

    final formattedDate = screenshot.uploadedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(screenshot.uploadedAt!)
        : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.primaryBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 20, color: AppColors.secondaryText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              screenshot.caption?.isNotEmpty == true
                                  ? screenshot.caption!
                                  : screenshot.fileName,
                              style: const TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (formattedDate != null)
                              Text(
                                'Uploaded on $formattedDate',
                                style: const TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: 'Delete Screenshot',
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.redAccent),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onDelete!();
                          },
                        ),
                      IconButton(
                        tooltip: 'Close (Esc)',
                        icon: const Icon(Icons.close,
                            size: 20, color: AppColors.primaryText),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Main Image Zoom Area
                Flexible(
                  child: Container(
                    color: const Color(0xFF0F0F0F),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(child: imageWidget),
                    ),
                  ),
                ),

                // Footer caption note
                if (screenshot.caption != null &&
                    screenshot.caption!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryBackground,
                      border: Border(
                        top: BorderSide(color: AppColors.primaryBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.secondaryText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            screenshot.caption!,
                            style: const TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 13,
                              color: AppColors.primaryText,
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
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 54, color: AppColors.mutedText),
          SizedBox(height: 12),
          Text(
            'Unable to preview screenshot',
            style: TextStyle(
              fontFamily: 'Switzer',
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

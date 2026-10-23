import 'dart:ui';
import 'package:flutter/material.dart';

import 'theme.dart';
import '../features/shared/components/brand_deck_dialog.dart';
import '../features/shared/components/command_palette.dart';

/// Tactile, micro-press responsive container.
/// Scales subtly (0.975x) on pointer-down with Emil-style cubic deceleration
/// and springs back cleanly on pointer-up/cancel.
class FluidPressable extends StatefulWidget {
  const FluidPressable({
    required this.child,
    this.onTap,
    this.scaleDown = 0.975,
    this.duration = AppMotion.press,
    this.curve = AppMotion.fluidOut,
    this.cursor = SystemMouseCursors.click,
    this.enableHover = false,
    this.hoverScale = 1.015,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final Curve curve;
  final MouseCursor cursor;
  final bool enableHover;
  final double hoverScale;

  @override
  State<FluidPressable> createState() => _FluidPressableState();
}

class _FluidPressableState extends State<FluidPressable> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    if (_isPressed) {
      scale = widget.scaleDown;
    } else if (widget.enableHover && _isHovered) {
      scale = widget.hoverScale;
    }

    return MouseRegion(
      cursor: widget.onTap != null ? widget.cursor : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enableHover) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (widget.enableHover) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (widget.onTap != null) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (_isPressed) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (_isPressed) setState(() => _isPressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Double-Bezel (Doppelrand) Architecture.
/// Implements high-end agency nested casing:
/// - Outer Shell: Hairline ring + calibrated padding + outer radius R
/// - Inner Core: Mathematically concentric radius (R - padding) with soft ambient shadow
class FluidDoubleBezel extends StatelessWidget {
  const FluidDoubleBezel({
    required this.child,
    this.outerPadding = const EdgeInsets.all(3.0),
    this.outerRadius = 20.0,
    this.innerRadius,
    this.outerColor = const Color(0x0A000000),
    this.outerBorderColor = const Color(0x14000000),
    this.innerColor = AppColors.mainBackground,
    this.innerShadow = AppShadows.ambientSoft,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry outerPadding;
  final double outerRadius;
  final double? innerRadius;
  final Color outerColor;
  final Color outerBorderColor;
  final Color innerColor;
  final List<BoxShadow> innerShadow;

  @override
  Widget build(BuildContext context) {
    // Concentric radius calculation
    final resolvedInnerRadius = innerRadius ?? (outerRadius - 3.0).clamp(2.0, 40.0);

    return Container(
      padding: outerPadding,
      decoration: BoxDecoration(
        color: outerColor,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: outerBorderColor, width: 1.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: innerColor,
          borderRadius: BorderRadius.circular(resolvedInnerRadius),
          boxShadow: innerShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Agency-Tier "Island" Button with nested trailing icon architecture.
/// Arrow or trailing icon lives inside its own distinct circular badge.
class FluidIslandButton extends StatefulWidget {
  const FluidIslandButton({
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.isLoading = false,
    this.backgroundColor = AppColors.primaryText,
    this.foregroundColor = Colors.white,
    this.iconBadgeColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.radius = 999.0, // Full pill default
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool isLoading;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? iconBadgeColor;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  State<FluidIslandButton> createState() => _FluidIslandButtonState();
}

class _FluidIslandButtonState extends State<FluidIslandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = widget.iconBadgeColor ??
        (widget.backgroundColor == AppColors.primaryText
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FluidPressable(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? AppColors.mutedText.withValues(alpha: 0.4)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: widget.foregroundColor,
                ),
              ),
              if (widget.isLoading) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.foregroundColor,
                  ),
                ),
              ] else if (widget.trailingIcon != null) ...[
                const SizedBox(width: 10),
                AnimatedSlide(
                  offset: _isHovered ? const Offset(0.15, 0) : Offset.zero,
                  duration: AppMotion.quick,
                  curve: AppMotion.fluidOut,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: effectiveBadgeColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.trailingIcon,
                      size: 13,
                      color: widget.foregroundColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent Frosted Glass Chrome Bar.
/// Conforms to Apple Interface guidelines with backdrop blur and hairline rim.
class FluidGlassBar extends StatelessWidget implements PreferredSizeWidget {
  const FluidGlassBar({
    required this.child,
    this.height = 56.0,
    this.blurSigma = 16.0,
    this.backgroundColor,
    this.borderBottom = true,
    super.key,
  });

  final Widget child;
  final double height;
  final double blurSigma;
  final Color? backgroundColor;
  final bool borderBottom;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark
            ? const Color(0xCC111111)
            : const Color(0xF2FFFFFF));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: bg,
            border: borderBottom
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0x1FFFFFFF)
                          : const Color(0x14000000),
                      width: 1.0,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Precision Lord Espandor Insignia Seal.
/// Serves as the authoritative, elegant hallmark of Schoolic intellect and calm.
/// Encased in concentric double-bezel circular geometry with optional executive popover.
class FluidMascotInsignia extends StatelessWidget {
  const FluidMascotInsignia({
    this.size = 28.0,
    this.showStatusDot = true,
    this.onTap,
    this.tooltip = 'Lord Espandor · Institutional Hallmark',
    super.key,
  });

  final double size;
  final bool showStatusDot;
  final VoidCallback? onTap;
  final String tooltip;

  void _showExecutiveBriefing(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppShadows.ambientElevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brandCyan, width: 2),
                      boxShadow: AppShadows.glowCyan,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/branding/lord_espandor_avatar.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lord Espandor',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Institutional Intellect · Foresight · Calm',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Lord Espandor anchors Schoolic academic governance and institutional clarity. Use the links below to inspect the design deck or invoke executive commands.',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        BrandDeckDialog.show(context);
                      },
                      icon: const Icon(Icons.auto_stories_outlined, size: 16),
                      label: const Text(
                        'Design Deck',
                        style: TextStyle(fontFamily: 'Switzer', fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        CommandPaletteDialog.show(context);
                      },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text(
                        'Command Palette',
                        style: TextStyle(fontFamily: 'Switzer', fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryText,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FluidPressable(
        onTap: onTap ?? () => _showExecutiveBriefing(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: AppColors.brandCyan.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandCyan.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/branding/lord_espandor_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              if (showStatusDot)
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.brandCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Card with micro-elevation, hover bloom, and tactile press scaling.
/// Follows Emil Kowalski & Apple fluid design engineering principles.
class FluidInteractiveCard extends StatefulWidget {
  const FluidInteractiveCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius,
    this.backgroundColor = AppColors.mainBackground,
    this.borderColor = AppColors.primaryBorder,
    this.hoverBorderColor = const Color(0x3300A3FF),
    this.elevation = 1.0,
    this.enableHoverTranslate = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color hoverBorderColor;
  final double elevation;
  final bool enableHoverTranslate;

  @override
  State<FluidInteractiveCard> createState() => _FluidInteractiveCardState();
}

class _FluidInteractiveCardState extends State<FluidInteractiveCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadii.rXl;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FluidPressable(
        onTap: widget.onTap,
        scaleDown: widget.onTap != null ? 0.985 : 1.0,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.fluidOut,
          transform: Matrix4.translationValues(
            0,
            (widget.enableHoverTranslate && _isHovered && widget.onTap != null) ? -2.0 : 0.0,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: radius,
            border: Border.all(
              color: _isHovered ? widget.hoverBorderColor : widget.borderColor,
              width: 1.0,
            ),
            boxShadow: _isHovered ? AppShadows.ambientElevated : AppShadows.ambientSoft,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fluid Sliding Segmented Tab Control.
/// Smoothly animates an Apple-style pill indicator behind the active segment.
class FluidSegmentedControl<T> extends StatelessWidget {
  const FluidSegmentedControl({
    required this.selectedValue,
    required this.onValueChanged,
    required this.children,
    this.backgroundColor = AppColors.secondaryBackground,
    this.indicatorColor = AppColors.mainBackground,
    this.padding = const EdgeInsets.all(3.0),
    this.height = 36.0,
    super.key,
  });

  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final Map<T, Widget> children;
  final Color backgroundColor;
  final Color indicatorColor;
  final EdgeInsetsGeometry padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    final keys = children.keys.toList();
    final selectedIndex = keys.indexOf(selectedValue);

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final segmentWidth = keys.isNotEmpty ? totalWidth / keys.length : 0.0;

          return Stack(
            children: [
              if (selectedIndex >= 0)
                AnimatedPositioned(
                  duration: AppMotion.comfortable,
                  curve: AppMotion.springLike,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular((height - 6) / 2),
                      boxShadow: AppShadows.ambientSoft,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: keys.map((key) {
                  final isSelected = key == selectedValue;
                  return Expanded(
                    child: FluidPressable(
                      onTap: () => onValueChanged(key),
                      scaleDown: 0.96,
                      child: Container(
                        alignment: Alignment.center,
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                          ),
                          child: IconTheme(
                            data: IconThemeData(
                              size: 15,
                              color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                            ),
                            child: children[key]!,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}


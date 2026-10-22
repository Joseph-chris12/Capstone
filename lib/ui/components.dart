import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Frosted glass surface floating over the camera or canvas (DESIGN.md,
/// elevation level 1).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.pill,
    this.padding = EdgeInsets.zero,
    this.opacity = 0.9,
    this.blur = 12,
    this.shadows = AppShadows.ambient,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final double blur;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: borderRadius,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// White card with a hair-thin keyline (DESIGN.md "Luminous Cards").
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.borderRadius = AppRadii.card,
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.keyline),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

enum PillVariant { primary, secondary, tertiary }

/// Full-radius button: espresso primary, glass secondary, mocha ghost.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PillVariant.primary,
    this.expand = false,
    this.height = 48,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PillVariant variant;
  final bool expand;
  final double height;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color fg, BoxBorder? border) = switch (variant) {
      PillVariant.primary => (
          enabled ? AppColors.espresso : AppColors.espresso.withValues(alpha: 0.35),
          AppColors.canvas,
          null,
        ),
      PillVariant.secondary => (
          AppColors.recessed,
          AppColors.ink,
          Border.all(color: AppColors.keyline),
        ),
      PillVariant.tertiary => (Colors.transparent, AppColors.mocha, null),
    };
    final style = (textStyle ?? AppText.bodyLg).copyWith(
      color: fg,
      fontWeight: FontWeight.w600,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: 16, color: fg),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: border == null
              ? BorderSide.none
              : const BorderSide(color: AppColors.keyline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: expand ? null : 1,
                heightFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40 px round glass control used on the scan HUD.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassPanel(
        blur: 6,
        shadows: AppShadows.soft,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: 18, color: AppColors.espresso),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill tag (DESIGN.md "Chips & Spatial Tags").
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.espresso : AppColors.recessed,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(label, style: AppText.bodyLg.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded badge, e.g. "Augmented Reality 101".
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.icon, this.dark = false});

  final String label;
  final IconData? icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.canvas : AppColors.badgeInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.espresso.withValues(alpha: 0.85) : AppColors.badge,
        borderRadius: AppRadii.pill,
        border: dark
            ? null
            : Border.all(color: AppColors.mocha.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppText.labelSm.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Eyebrow + heading pair that opens each tutorial section.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: AppText.eyebrow),
        const SizedBox(height: 4),
        Text(title, style: AppText.headline),
      ],
    );
  }
}

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Heights the floating header and tab bar take, so screens can keep their
/// content clear of them.
abstract final class Chrome {
  static const headerHeight = 64.0;

  /// 64 px pill plus its 8 px gap from the bottom edge.
  static const navHeight = 72.0;

  static EdgeInsets contentInsets(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      top: pad.top + headerHeight,
      bottom: pad.bottom + navHeight,
    );
  }
}

/// "ARise" logo + wordmark on the left, Feedback pill on the right.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onFeedback});

  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: AppColors.canvas.withValues(alpha: 0.85),
            border: const Border(
              bottom: BorderSide(color: Color(0xB3E8DFD4)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A210F04),
                blurRadius: 12,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: SizedBox(
            height: Chrome.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/arise_logo.png',
                      width: 32,
                      height: 32,
                      semanticLabel: 'ARise logo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('ARise', style: AppText.brand),
                  const Spacer(),
                  _FeedbackPill(onTap: onFeedback),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const StadiumBorder(side: BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  size: 16,
                  color: AppColors.espresso,
                ),
                const SizedBox(width: 6),
                Text(
                  'Feedback',
                  style: AppText.bodyLg.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavDestination {
  const NavDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Floating glass pill with one espresso pill marking the active tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 8 + bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppRadii.pill,
            boxShadow: AppShadows.nav,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.pill,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: AppRadii.pill,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _NavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.canvas : AppColors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 113,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : Colors.transparent,
          borderRadius: AppRadii.pill,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x40210F04),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, size: 18, color: fg),
                const SizedBox(height: 1),
                Text(
                  destination.label,
                  style: AppText.labelSm.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

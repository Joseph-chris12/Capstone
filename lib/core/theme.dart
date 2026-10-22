import 'package:flutter/material.dart';

/// "Luminous Spatial" design tokens (DESIGN.md): warm parchment canvas,
/// espresso ink, mocha and tan accents.
abstract final class AppColors {
  /// Primary canvas backdrop, warm parchment.
  static const canvas = Color(0xFFFAF6EE);

  /// Elevated floating surfaces and inputs.
  static const surface = Color(0xFFFFFFFF);

  /// Recessed trays, inactive chips and track backgrounds.
  static const recessed = Color(0xFFF7F3EB);
  static const recessedDeep = Color(0xFFF4EFE6);

  /// Deep espresso: primary text, primary controls, monolith cards.
  static const espresso = Color(0xFF210F04);
  static const espressoHover = Color(0xFF2B170B);

  /// Earthy mocha: accents, active states, secondary actions.
  static const mocha = Color(0xFF7D563B);

  /// Warm tan: focus rings, reticle, highlight borders.
  static const tan = Color(0xFFB08D74);

  /// Peach container behind hero icons and the selected rating.
  static const peach = Color(0xFFFECAA8);
  static const peachSoft = Color(0xFFFFDCC6);
  static const badge = Color(0xFFF3E3D3);
  static const badgeInk = Color(0xFF623F25);

  static const ink = Color(0xFF1C1C17);
  static const inkMuted = Color(0xFF4F453F);
  static const inkBody = Color(0xFF5C412F);
  static const hairline = Color(0xFFE8DFD4);
  static const error = Color(0xFFBA1A1A);

  /// Laser-etched keyline around floating panels.
  static const keyline = Color(0x14210F04); // rgba(33,15,4,.08)
  static const keylineStrong = Color(0x1F2B170B); // rgba(43,23,11,.12)
}

abstract final class AppShadows {
  /// Level 1: ambient floating panels.
  static const ambient = [
    BoxShadow(
      color: Color(0x0F210F04),
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x08210F04),
      blurRadius: 8,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
  ];

  /// Small lift used on cards and pills.
  static const soft = [
    BoxShadow(color: Color(0x0A210F04), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Floating bottom navigation bar.
  static const nav = [
    BoxShadow(color: Color(0x1F210F04), blurRadius: 30, offset: Offset(0, 8)),
  ];
}

abstract final class AppRadii {
  static const pill = BorderRadius.all(Radius.circular(9999));
  static const card = BorderRadius.all(Radius.circular(32));
  static const panel = BorderRadius.all(Radius.circular(24));
  static const tile = BorderRadius.all(Radius.circular(16));
}

/// Type scale from DESIGN.md, all in Plus Jakarta Sans.
abstract final class AppText {
  static const family = 'PlusJakartaSans';

  static const displayMobile = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 35 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.56,
    color: AppColors.espresso,
  );
  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    color: AppColors.espresso,
  );
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.18,
    color: AppColors.espresso,
  );
  static const brand = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.espresso,
  );
  static const bodyLg = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.inkBody,
  );
  static const bodySm = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.inkBody,
  );
  static const labelLg = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.28,
    color: AppColors.espresso,
  );
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.36,
    color: AppColors.espresso,
  );

  /// Uppercase eyebrow above section headings.
  static const eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.55,
    color: AppColors.mocha,
  );
  static const labelSm = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.55,
    color: AppColors.mocha,
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.mocha,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.espresso,
    onPrimary: AppColors.canvas,
    secondary: AppColors.mocha,
    onSecondary: Colors.white,
    tertiary: AppColors.tan,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    error: AppColors.error,
    outline: AppColors.keylineStrong,
    outlineVariant: AppColors.hairline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppText.family,
    scaffoldBackgroundColor: AppColors.canvas,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.espresso,
      contentTextStyle: TextStyle(
        fontFamily: AppText.family,
        color: AppColors.canvas,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.panel),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.mocha),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.mocha,
      selectionHandleColor: AppColors.mocha,
    ),
  );
}

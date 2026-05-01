import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

ThemeData buildLightTheme() {
  const scheme = ColorScheme.light(
    primary: LodzColors.primary,
    onPrimary: LodzColors.onPrimary,
    primaryContainer: LodzColors.primaryContainer,
    onPrimaryContainer: LodzColors.onPrimaryContainer,
    secondary: LodzColors.secondary,
    onSecondary: LodzColors.onSecondary,
    secondaryContainer: LodzColors.secondaryContainer,
    onSecondaryContainer: LodzColors.onSecondaryContainer,
    tertiary: LodzColors.tertiary,
    onTertiary: LodzColors.onTertiary,
    error: LodzColors.error,
    onError: LodzColors.onError,
    errorContainer: LodzColors.errorContainer,
    onErrorContainer: LodzColors.onErrorContainer,
    surface: LodzColors.surface,
    onSurface: LodzColors.onSurface,
    surfaceContainerLowest: LodzColors.surfaceContainerLowest,
    surfaceContainerLow: LodzColors.surfaceContainerLow,
    surfaceContainer: LodzColors.surfaceContainer,
    surfaceContainerHigh: LodzColors.surfaceContainerHigh,
    surfaceContainerHighest: LodzColors.surfaceContainerHighest,
    surfaceDim: LodzColors.surfaceDim,
    surfaceBright: LodzColors.surfaceBright,
    onSurfaceVariant: LodzColors.onSurfaceVariant,
    outline: LodzColors.outline,
    outlineVariant: LodzColors.outlineVariant,
    inverseSurface: LodzColors.inverseSurface,
    onInverseSurface: LodzColors.inverseOnSurface,
    inversePrimary: LodzColors.inversePrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _buildTextTheme(scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface.withValues(alpha: 0.9),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}

ThemeData buildDarkTheme() {
  // Dark mode is not in the Stitch spec; mirror the light theme inverted enough
  // to remain legible if the system is in dark mode.
  final scheme = ColorScheme.fromSeed(
    seedColor: LodzColors.transitCyan,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: _buildTextTheme(scheme.onSurface),
  );
}

TextTheme _buildTextTheme(Color onSurface) {
  // Map design typography roles onto Material 3 TextTheme slots. Inter is
  // pulled at runtime via google_fonts; use tabular figures for digit-heavy
  // labels (countdowns, vehicle numbers).
  final inter = GoogleFonts.interTextTheme();

  TextStyle style({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return inter.bodyMedium!
        .copyWith(
          fontSize: size,
          fontWeight: weight,
          height: height / size,
          letterSpacing: letterSpacing * size,
          color: onSurface,
          fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
        );
  }

  return TextTheme(
    // display-lg
    displayLarge: style(
      size: 32,
      weight: FontWeight.w700,
      height: 40,
      letterSpacing: -0.02,
    ),
    // headline-md
    headlineMedium: style(
      size: 24,
      weight: FontWeight.w600,
      height: 32,
      letterSpacing: -0.01,
    ),
    // title-sm
    titleMedium: style(size: 18, weight: FontWeight.w600, height: 24),
    titleSmall: style(size: 18, weight: FontWeight.w600, height: 24),
    // body-md
    bodyLarge: style(size: 16, weight: FontWeight.w400, height: 24),
    bodyMedium: style(size: 16, weight: FontWeight.w400, height: 24),
    // body-sm
    bodySmall: style(size: 14, weight: FontWeight.w400, height: 20),
    // label-bold (for "minutes" / "live" micro-copy)
    labelLarge: style(size: 12, weight: FontWeight.w700, height: 16),
    labelMedium: style(size: 12, weight: FontWeight.w500, height: 16),
    // mono-num — tabular figures for digit-heavy labels
    labelSmall: style(size: 14, weight: FontWeight.w600, height: 20, tabular: true),
  );
}

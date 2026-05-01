import 'package:flutter/material.dart';

/// Material color roles from
/// `stitch_city_transit_tracker/d_urban_transit_system/DESIGN.md`.
class LodzColors {
  LodzColors._();

  // Surfaces / neutrals
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceDim = Color(0xFFDADADA);
  static const Color surfaceBright = Color(0xFFF9F9F9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F3);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E2);
  static const Color surfaceVariant = Color(0xFFE2E2E2);

  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF4C4546);
  static const Color outline = Color(0xFF7E7576);
  static const Color outlineVariant = Color(0xFFCFC4C5);

  static const Color background = Color(0xFFF9F9F9);
  static const Color onBackground = Color(0xFF1A1C1C);

  // Primary / secondary (Material 3 color scheme roles)
  static const Color primary = Color(0xFF000000);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1B1B1B);
  static const Color onPrimaryContainer = Color(0xFF848484);

  static const Color secondary = Color(0xFF00658D);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF2FBCFF);
  static const Color onSecondaryContainer = Color(0xFF004867);

  static const Color tertiary = Color(0xFF000000);
  static const Color onTertiary = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color inverseSurface = Color(0xFF2F3131);
  static const Color inverseOnSurface = Color(0xFFF1F1F1);
  static const Color inversePrimary = Color(0xFFC6C6C6);

  // Brand transit accents (Łódź CMYK)
  static const Color transitTram = Color(0xFFFACC15);
  static const Color transitBus = Color(0xFFD946EF);
  static const Color transitCyan = Color(0xFF06B6D4);

  // Soft cyan-tinted background used for the active bottom-nav pill
  static const Color cyanSurface = Color(0xFFECFEFF);
}

/// 4px-base spacing grid.
class LodzSpacing {
  LodzSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double stackGap = 12;
  static const double md = 16;
  static const double edgeMargin = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii.
class LodzRadius {
  LodzRadius._();
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double sheet = 24;
  static const double full = 9999;
}

/// Ambient elevation shadows (level 1 = cards, level 2 = floating).
class LodzShadows {
  LodzShadows._();
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0D000000), // 5% black
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];
}

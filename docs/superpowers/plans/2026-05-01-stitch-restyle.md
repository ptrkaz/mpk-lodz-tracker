# Łódź Transit — Stitch Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin the existing Flutter MPK Łódź tracker to match the Google Stitch "Łódź Urban Transit System" design (white-paper Modernist palette, Inter typography, cyan/yellow/magenta transit accents, top app bar + floating search overlay + restyled vehicle markers + bottom nav with stub Lines/Favorites tabs).

**Architecture:** Pure UI restyle. No domain or data-layer changes. Introduce a design-token module (`lib/ui/core/design_tokens.dart`) plus an Inter-based `ThemeData`. Replace the current `FilterChipButton` overlay with a `MapSearchBar` widget (search input + tune button) that opens the existing `FilterSheet`. Add a `RootShell` with a `BottomNavigationBar` swapping between `MapScreen` (real) and stub `LinesScreen` / `FavoritesScreen` placeholders. Restyle `VehicleMarkersLayer` to use the new transit colors and add a bearing-arrow symbol layer. Keep all ViewModels, repositories, services, and protobuf code untouched.

**Tech Stack:** Flutter 3.41+ / Dart 3.10, `provider`, `maplibre_gl`, `google_fonts` (new — for Inter), Material 3 `ColorScheme`, existing `flutter_localizations` + ARB.

---

## File Structure

**New files:**
- `lib/ui/core/design_tokens.dart` — color, spacing, radius, shadow, typography constants from `stitch_city_transit_tracker/d_urban_transit_system/DESIGN.md`.
- `lib/ui/features/map/views/map_search_bar.dart` — top-overlay search bar with tune-button trailing.
- `lib/ui/features/shell/views/root_shell.dart` — `Scaffold` + `BottomNavigationBar` switching tabs.
- `lib/ui/features/shell/views/lines_screen.dart` — placeholder "Coming soon" screen for Lines tab.
- `lib/ui/features/shell/views/favorites_screen.dart` — placeholder "Coming soon" screen for Favorites tab.
- `lib/ui/features/map/views/top_app_bar.dart` — restyled translucent top app bar (`Łódź Transit` title + menu/settings icons).
- `test/ui/features/shell/root_shell_test.dart`
- `test/ui/features/map/map_search_bar_test.dart`
- `test/ui/core/app_theme_test.dart`

**Modified files:**
- `pubspec.yaml` — add `google_fonts: ^6.2.1` dependency.
- `lib/ui/core/app_theme.dart` — rebuild light + dark themes from design tokens, Inter typography.
- `lib/ui/core/vehicle_colors.dart` — repaint tram=`#FACC15` (yellow), bus=`#D946EF` (magenta), unknown=`#7E7576` (outline).
- `lib/main.dart` — swap `home: const MapScreen()` → `home: const RootShell()`.
- `lib/ui/features/map/views/map_screen.dart` — drop `FilterChipButton`; add `TopAppBar`, `MapSearchBar`; rewire FAB + last-update hint positioning.
- `lib/ui/features/map/views/locate_fab.dart` — restyle as white circular button with cyan icon, level-2 shadow.
- `lib/ui/features/map/views/last_update_hint.dart` — restyle pill chip on `surfaceContainerLowest` with level-1 shadow.
- `lib/ui/features/map/views/vehicle_markers_layer.dart` — switch number-label color logic (black on tram-yellow, white on bus-magenta) and add a bearing-arrow symbol layer.
- `lib/ui/features/filter/views/filter_sheet.dart` — round top corners 24px, drag handle, restyled tabs/buttons.
- `lib/ui/features/filter/views/line_chip.dart` — pill shape (full radius), tram-yellow / bus-magenta solid background when selected.
- `lib/l10n/app_pl.arb` — add `appTitle`, `searchPlaceholder`, `navMap`, `navLines`, `navFavorites`, `screenComingSoon` strings.

**Deleted files:**
- `lib/ui/features/map/views/filter_chip_button.dart` — replaced by `MapSearchBar`.

---

## Task 1: Add Inter typography dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add google_fonts to dependencies**

In `pubspec.yaml`, under `dependencies:`, after `intl: ^0.20.2`, insert:

```yaml
  google_fonts: ^6.2.1
```

- [ ] **Step 2: Install**

Run: `flutter pub get`
Expected: exits 0; `pubspec.lock` updated with `google_fonts` entry.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_fonts for Inter typography"
```

---

## Task 2: Design tokens module

**Files:**
- Create: `lib/ui/core/design_tokens.dart`
- Test: `test/ui/core/app_theme_test.dart` (only the tokens half — see Task 3 for theme half)

- [ ] **Step 1: Write failing token-existence test**

Create `test/ui/core/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/ui/core/design_tokens.dart';

void main() {
  test('LodzColors exposes brand transit accents', () {
    expect(LodzColors.transitTram, const Color(0xFFFACC15));
    expect(LodzColors.transitBus, const Color(0xFFD946EF));
    expect(LodzColors.transitCyan, const Color(0xFF06B6D4));
  });

  test('LodzSpacing follows the 4px base grid', () {
    expect(LodzSpacing.xs, 4.0);
    expect(LodzSpacing.sm, 8.0);
    expect(LodzSpacing.stackGap, 12.0);
    expect(LodzSpacing.md, 16.0);
    expect(LodzSpacing.edgeMargin, 16.0);
    expect(LodzSpacing.lg, 24.0);
    expect(LodzSpacing.xl, 32.0);
  });

  test('LodzRadius matches the design system steps', () {
    expect(LodzRadius.sm, 4.0);
    expect(LodzRadius.md, 8.0);
    expect(LodzRadius.lg, 12.0);
    expect(LodzRadius.xl, 16.0);
    expect(LodzRadius.sheet, 24.0);
  });
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: `flutter test test/ui/core/app_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:mpk_lodz_tracker/ui/core/design_tokens.dart'`.

- [ ] **Step 3: Create the design tokens module**

Create `lib/ui/core/design_tokens.dart`:

```dart
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
```

- [ ] **Step 4: Run test — verify it passes**

Run: `flutter test test/ui/core/app_theme_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/core/design_tokens.dart test/ui/core/app_theme_test.dart
git commit -m "feat(ui): add Łódź transit design tokens"
```

---

## Task 3: Rebuild app theme on design tokens

**Files:**
- Modify: `lib/ui/core/app_theme.dart`
- Test: `test/ui/core/app_theme_test.dart` (extend)

- [ ] **Step 1: Add failing theme test**

Append to `test/ui/core/app_theme_test.dart` (inside `main()`):

```dart
  test('buildLightTheme uses LodzColors and Inter font', () {
    final theme = buildLightTheme();
    expect(theme.colorScheme.primary, LodzColors.primary);
    expect(theme.colorScheme.surface, LodzColors.surface);
    expect(theme.colorScheme.secondary, LodzColors.secondary);
    expect(theme.useMaterial3, isTrue);
    // Inter is applied via google_fonts; the returned TextTheme has
    // `fontFamily` starting with "Inter".
    final body = theme.textTheme.bodyMedium!;
    expect(body.fontFamily, contains('Inter'));
    expect(body.fontSize, 16);
    expect(body.height, closeTo(24 / 16, 0.001));
  });
```

And add the import at the top of the test file:

```dart
import 'package:mpk_lodz_tracker/ui/core/app_theme.dart';
```

- [ ] **Step 2: Run test — verify it fails**

Run: `flutter test test/ui/core/app_theme_test.dart`
Expected: FAIL — primary still seeded from `#2E86DE`, body uses default Roboto.

- [ ] **Step 3: Rewrite `lib/ui/core/app_theme.dart`**

Replace the file contents with:

```dart
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
```

- [ ] **Step 4: Run test — verify it passes**

Run: `flutter test test/ui/core/app_theme_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Verify analyzer is clean**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/core/app_theme.dart test/ui/core/app_theme_test.dart
git commit -m "feat(ui): rebuild theme on Łódź design tokens with Inter"
```

---

## Task 4: Repaint vehicle colors

**Files:**
- Modify: `lib/ui/core/vehicle_colors.dart`
- Test: `test/ui/features/filter/line_chip_test.dart` (existing test will continue verifying via `kVehicleColors[VehicleType.bus]`).

- [ ] **Step 1: Update `lib/ui/core/vehicle_colors.dart`**

Replace contents with:

```dart
import 'package:flutter/material.dart';

import '../../domain/models/vehicle.dart';
import 'design_tokens.dart';

/// Łódź CMYK transit accents — tram = yellow, bus = magenta. Cyan is reserved
/// for interactive states elsewhere; the unknown bucket uses the neutral
/// outline shade so it never competes with the live transit accents.
const Map<VehicleType, Color> kVehicleColors = {
  VehicleType.tram: LodzColors.transitTram,
  VehicleType.bus: LodzColors.transitBus,
  VehicleType.unknown: LodzColors.outline,
};

Color colorFor(VehicleType type) => kVehicleColors[type]!;

/// Foreground color to render on top of [kVehicleColors] backgrounds. Yellow
/// needs black text for contrast; magenta needs white.
const Map<VehicleType, Color> kVehicleOnColors = {
  VehicleType.tram: Color(0xFF000000),
  VehicleType.bus: Color(0xFFFFFFFF),
  VehicleType.unknown: Color(0xFFFFFFFF),
};

Color onColorFor(VehicleType type) => kVehicleOnColors[type]!;
```

- [ ] **Step 2: Run line-chip test — verify still passing**

Run: `flutter test test/ui/features/filter/line_chip_test.dart`
Expected: PASS — the bus chip's selected color is now `LodzColors.transitBus`, and the test only asserts equality with `kVehicleColors[VehicleType.bus]`, which is whatever the constant is.

- [ ] **Step 3: Run full test suite to surface knock-on failures**

Run: `flutter test`
Expected: PASS (no test pinned the prior `#E74C3C` / `#2E86DE` constants).

- [ ] **Step 4: Commit**

```bash
git add lib/ui/core/vehicle_colors.dart
git commit -m "feat(ui): repaint vehicle colors to Łódź CMYK transit accents"
```

---

## Task 5: Add new l10n strings

**Files:**
- Modify: `lib/l10n/app_pl.arb`

- [ ] **Step 1: Append the new keys to `lib/l10n/app_pl.arb`**

Insert before the closing `}` of `lib/l10n/app_pl.arb`, after the existing `permissionsLocationDenied` entry (add a comma to that entry as needed):

```json
  "appTitle": "Łódź Transit",
  "@appTitle": {},
  "searchPlaceholder": "Szukaj linii…",
  "@searchPlaceholder": {},
  "navMap": "Mapa",
  "@navMap": {},
  "navLines": "Linie",
  "@navLines": {},
  "navFavorites": "Ulubione",
  "@navFavorites": {},
  "screenComingSoon": "Wkrótce",
  "@screenComingSoon": {}
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_pl.dart` are regenerated, exposing `appTitle`, `searchPlaceholder`, `navMap`, `navLines`, `navFavorites`, `screenComingSoon` getters on `AppLocalizations`.

- [ ] **Step 3: Verify analyzer clean**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_pl.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_pl.dart
git commit -m "feat(l10n): add restyle strings (app title, search, nav, coming soon)"
```

---

## Task 6: Restyle `LineChip` as transit pill

**Files:**
- Modify: `lib/ui/features/filter/views/line_chip.dart`
- Test: `test/ui/features/filter/line_chip_test.dart`

- [ ] **Step 1: Extend tests with a foreground-color assertion**

Append to `test/ui/features/filter/line_chip_test.dart` (inside `main()`):

```dart
  testWidgets('selected tram chip uses black foreground text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '10',
          type: VehicleType.tram,
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    final text = tester.widget<Text>(find.text('10'));
    expect(text.style!.color, const Color(0xFF000000));
  });

  testWidgets('selected bus chip uses white foreground text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '57',
          type: VehicleType.bus,
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    final text = tester.widget<Text>(find.text('57'));
    expect(text.style!.color, const Color(0xFFFFFFFF));
  });
```

- [ ] **Step 2: Run tests — verify the new ones fail**

Run: `flutter test test/ui/features/filter/line_chip_test.dart`
Expected: the two new tests FAIL because the current chip uses `Colors.white` for tram-selected and `onSurface` for unselected — the bus-selected one happens to pass.

- [ ] **Step 3: Replace `lib/ui/features/filter/views/line_chip.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/vehicle.dart';
import '../../../core/design_tokens.dart';
import '../../../core/vehicle_colors.dart';

class LineChip extends StatelessWidget {
  const LineChip({
    super.key,
    required this.number,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colorFor(type);
    final onAccent = onColorFor(type);
    final scheme = Theme.of(context).colorScheme;

    final bg = selected ? accent : scheme.surfaceContainerLowest;
    final fg = selected ? onAccent : scheme.onSurface;
    final borderColor = selected ? accent : scheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LodzRadius.full),
      child: Container(
        key: const ValueKey('line-chip-container'),
        margin: const EdgeInsets.only(right: LodzSpacing.sm, bottom: LodzSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.stackGap,
          vertical: LodzSpacing.xs + 2,
        ),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(LodzRadius.full),
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — verify all pass**

Run: `flutter test test/ui/features/filter/line_chip_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/filter/views/line_chip.dart test/ui/features/filter/line_chip_test.dart
git commit -m "feat(ui): restyle line chip as transit pill"
```

---

## Task 7: Restyle `FilterSheet`

**Files:**
- Modify: `lib/ui/features/filter/views/filter_sheet.dart`

This task is purely visual — no test changes. The view-model behaviors (search, tab switch, toggle, clear, apply) are already covered by `test/ui/features/filter/filter_view_model_test.dart`.

- [ ] **Step 1: Replace `lib/ui/features/filter/views/filter_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/design_tokens.dart';
import '../../map/view_models/bootstrap_view_model.dart';
import '../view_models/filter_view_model.dart';
import 'line_chip.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.7,
        child: FilterSheet(),
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: context.read<FilterViewModel>().query,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LodzRadius.sheet),
        ),
        boxShadow: LodzShadows.level2,
      ),
      padding: const EdgeInsets.fromLTRB(
        LodzSpacing.edgeMargin,
        LodzSpacing.stackGap,
        LodzSpacing.edgeMargin,
        LodzSpacing.lg,
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          context.watch<BootstrapViewModel>(),
          context.watch<FilterViewModel>(),
        ]),
        builder: (context, _) {
          final boot = context.read<BootstrapViewModel>();
          final filter = context.read<FilterViewModel>();
          final lines = _filterLines(boot.routes, filter);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle (matches Stitch design)
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: LodzSpacing.lg),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(LodzRadius.full),
                  ),
                ),
              ),
              Text(
                l10n.filterTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: LodzSpacing.stackGap),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.filterSearchPlaceholder,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LodzRadius.full),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LodzRadius.full),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LodzRadius.full),
                    borderSide: BorderSide(
                      color: LodzColors.transitCyan,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: filter.setQuery,
              ),
              const SizedBox(height: LodzSpacing.stackGap),
              Row(
                children: [
                  _TabButton(
                    label: l10n.filterTabTram,
                    active: filter.activeTab == VehicleType.tram,
                    onTap: () => filter.setTab(VehicleType.tram),
                  ),
                  _TabButton(
                    label: l10n.filterTabBus,
                    active: filter.activeTab == VehicleType.bus,
                    onTap: () => filter.setTab(VehicleType.bus),
                  ),
                ],
              ),
              const SizedBox(height: LodzSpacing.stackGap),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    children: [
                      for (final l in lines)
                        LineChip(
                          number: l.number,
                          type: l.type,
                          selected: filter.selectedRouteIds.contains(l.routeId),
                          onTap: () => filter.toggle(l.routeId),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: filter.clear,
                    child: Text(l10n.filterClear),
                  ),
                  const SizedBox(width: LodzSpacing.stackGap),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LodzRadius.md),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.filterApply),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Line> _filterLines(RoutesIndex index, FilterViewModel f) {
    final all = index.values.where((l) => l.type == f.activeTab).toList();
    final filtered = f.query.isEmpty
        ? all
        : all.where((l) => l.number.toLowerCase().contains(f.query)).toList();
    filtered.sort((a, b) => _compareNatural(a.number, b.number));
    return filtered;
  }

  int _compareNatural(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: LodzSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? LodzColors.transitCyan : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/features/filter/views/filter_sheet.dart
git commit -m "feat(ui): restyle filter sheet (drag handle, rounded search, cyan focus)"
```

---

## Task 8: New `MapSearchBar` widget (replaces FilterChipButton)

**Files:**
- Create: `lib/ui/features/map/views/map_search_bar.dart`
- Create: `test/ui/features/map/map_search_bar_test.dart`
- Delete (later, in Task 10): `lib/ui/features/map/views/filter_chip_button.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/ui/features/map/map_search_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/views/map_search_bar.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('MapSearchBar renders search field and tune button', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FilterViewModel()),
          ChangeNotifierProvider(
            create: (_) => BootstrapViewModel(
              repository: RoutesRepository(
                staticService: GtfsStaticService(),
                cacheService: RoutesCacheService(),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MapSearchBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — verify it fails**

Run: `flutter test test/ui/features/map/map_search_bar_test.dart`
Expected: FAIL — `MapSearchBar` does not exist yet.

- [ ] **Step 3: Create `lib/ui/features/map/views/map_search_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../filter/views/filter_sheet.dart';

/// Floating top-overlay search bar that doubles as the entry point to the
/// existing line-filter sheet. The text field is read-only on tap (it opens
/// the sheet, where the real search lives) and the trailing tune button opens
/// the same sheet directly.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.edgeMargin),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LodzRadius.full),
          border: Border.all(color: scheme.surfaceVariant),
          boxShadow: LodzShadows.level1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.md),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: LodzSpacing.stackGap),
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () => FilterSheet.show(context),
                decoration: InputDecoration(
                  hintText: l10n.searchPlaceholder,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: LodzSpacing.sm),
            _TuneButton(onTap: () => FilterSheet.show(context)),
          ],
        ),
      ),
    );
  }
}

class _TuneButton extends StatelessWidget {
  const _TuneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(LodzRadius.full),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.tune, color: scheme.onSurface),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test — verify it passes**

Run: `flutter test test/ui/features/map/map_search_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/map/views/map_search_bar.dart test/ui/features/map/map_search_bar_test.dart
git commit -m "feat(map): add floating MapSearchBar overlay"
```

---

## Task 9: Restyle `LocateFab` and `LastUpdateHint`

**Files:**
- Modify: `lib/ui/features/map/views/locate_fab.dart`
- Modify: `lib/ui/features/map/views/last_update_hint.dart`

Pure visual restyle — existing widget tests don't pin styling and the FAB's geolocation flow is unchanged.

- [ ] **Step 1: Replace `lib/ui/features/map/views/locate_fab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/design_tokens.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({super.key, required this.controllerProvider});

  final MapLibreMapController? Function() controllerProvider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LodzRadius.full),
        onTap: () => _onTap(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surfaceVariant),
            boxShadow: LodzShadows.level2,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.my_location, color: LodzColors.transitCyan),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final ctrl = controllerProvider();
    if (ctrl == null) return;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14),
      duration: const Duration(milliseconds: 600),
    );
  }
}
```

Note: this drops the `Positioned` wrapper. `MapScreen` (Task 10) will wrap it in a `Positioned` itself, so behavior is preserved while letting the widget be reused outside the map stack if needed.

- [ ] **Step 2: Replace `lib/ui/features/map/views/last_update_hint.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../view_models/map_view_model.dart';

class LastUpdateHint extends StatefulWidget {
  const LastUpdateHint({super.key});

  @override
  State<LastUpdateHint> createState() => _LastUpdateHintState();
}

class _LastUpdateHintState extends State<LastUpdateHint> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = context.watch<MapViewModel>().lastUpdate;
    if (last == null) return const SizedBox.shrink();
    final ageSec = DateTime.now().difference(last).inSeconds.clamp(0, 99999);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.stackGap,
          vertical: LodzSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LodzRadius.full),
          boxShadow: LodzShadows.level1,
          border: Border.all(color: scheme.surfaceVariant),
        ),
        child: Text(
          l10n.mapLastUpdate(ageSec),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
```

Same note: this drops the `Positioned` wrapper; `MapScreen` will own positioning.

- [ ] **Step 3: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/features/map/views/locate_fab.dart lib/ui/features/map/views/last_update_hint.dart
git commit -m "feat(map): restyle locate FAB and last-update hint"
```

---

## Task 10: New `TopAppBar` and `MapScreen` layout

**Files:**
- Create: `lib/ui/features/map/views/top_app_bar.dart`
- Modify: `lib/ui/features/map/views/map_screen.dart`
- Delete: `lib/ui/features/map/views/filter_chip_button.dart`

- [ ] **Step 1: Create `lib/ui/features/map/views/top_app_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';

/// Translucent top app bar matching the Stitch design — menu icon on the
/// left, app title, settings icon on the right. Drawn over the map; the
/// white-with-90%-alpha background lets the map ghost through.
class LodzTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LodzTopAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: scheme.surfaceVariant),
        ),
        boxShadow: LodzShadows.level1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.md),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.menu, color: scheme.onSurfaceVariant),
            const SizedBox(width: LodzSpacing.md),
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const Spacer(),
            Icon(Icons.settings, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Replace `lib/ui/features/map/views/map_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../view_models/bootstrap_view_model.dart';
import '../view_models/map_view_model.dart';
import 'last_update_hint.dart';
import 'locate_fab.dart';
import 'map_search_bar.dart';
import 'top_app_bar.dart';
import 'vehicle_markers_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static String get _styleUrl =>
      'https://api.maptiler.com/maps/streets/style.json?key=$_maptilerKey';

  MapLibreMapController? _ctrl;
  VehicleMarkersLayer? _layer;

  @override
  void initState() {
    super.initState();
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    mapVm.attachLifecycle();
    mapVm.start();
    mapVm.addListener(_syncLayer);
    bootVm.addListener(_syncLayer);
    filterVm.addListener(_syncLayer);
  }

  @override
  void dispose() {
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    mapVm.removeListener(_syncLayer);
    bootVm.removeListener(_syncLayer);
    filterVm.removeListener(_syncLayer);
    super.dispose();
  }

  Future<void> _syncLayer() async {
    final layer = _layer;
    if (layer == null) return;
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    final selected = filterVm.selectedRouteIds;
    final visible = selected.isEmpty
        ? mapVm.vehicles
        : mapVm.vehicles.where((v) => selected.contains(v.routeId)).toList();
    await layer.sync(visible, bootVm.routes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map fills the whole stack; everything else floats over it.
        Positioned.fill(
          child: MapLibreMap(
            styleString: _styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(LodzConstants.centerLat, LodzConstants.centerLon),
              zoom: LodzConstants.defaultZoom,
            ),
            onMapCreated: (c) {
              _ctrl = c;
              _layer = VehicleMarkersLayer(c);
            },
            onStyleLoadedCallback: () => _syncLayer(),
          ),
        ),
        // Top app bar (translucent, docked).
        const Positioned(top: 0, left: 0, right: 0, child: LodzTopAppBar()),
        // Floating search bar tucked under the app bar.
        const Positioned(
          top: 88,
          left: 0,
          right: 0,
          child: MapSearchBar(),
        ),
        // Locate FAB — bottom-right.
        Positioned(
          right: LodzSpacing.edgeMargin,
          bottom: LodzSpacing.md,
          child: LocateFab(controllerProvider: () => _ctrl),
        ),
        // Last-update hint — bottom-left.
        const Positioned(
          left: LodzSpacing.edgeMargin,
          bottom: LodzSpacing.md,
          child: LastUpdateHint(),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Delete `lib/ui/features/map/views/filter_chip_button.dart`**

Run: `git rm lib/ui/features/map/views/filter_chip_button.dart`
Expected: file removed from index.

- [ ] **Step 4: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests PASS. (No test referenced `FilterChipButton`.)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/map/views/top_app_bar.dart lib/ui/features/map/views/map_screen.dart
git commit -m "feat(map): translucent app bar + floating search overlay"
```

---

## Task 11: Restyle `VehicleMarkersLayer` (bearing arrow + new colors)

**Files:**
- Modify: `lib/ui/features/map/views/vehicle_markers_layer.dart`

The map layer is verified manually (PlatformView is not driveable in `flutter_test`). Verify visually via `flutter run` after the change.

- [ ] **Step 1: Replace `lib/ui/features/map/views/vehicle_markers_layer.dart`**

```dart
import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class VehicleMarkersLayer {
  static const _sourceId = 'vehicles';
  static const _circleLayerId = 'vehicle-circles';
  static const _circleStrokeLayerId = 'vehicle-circles-stroke';
  static const _labelLayerId = 'vehicle-labels';
  static const _bearingLayerId = 'vehicle-bearing';

  final MapLibreMapController controller;
  bool _initialized = false;

  VehicleMarkersLayer(this.controller);

  Future<void> sync(List<Vehicle> vehicles, RoutesIndex routes) async {
    final fc = _toFeatureCollection(vehicles, routes);
    if (!_initialized) {
      await controller.addGeoJsonSource(_sourceId, fc);

      // Background: white halo for separation from map.
      await controller.addCircleLayer(
        _sourceId,
        _circleStrokeLayerId,
        const CircleLayerProperties(
          circleColor: '#ffffff',
          circleRadius: 17,
        ),
      );

      // Foreground: colored circle keyed off vehicle type.
      await controller.addCircleLayer(
        _sourceId,
        _circleLayerId,
        CircleLayerProperties(
          circleColor: [
            'match',
            ['get', 'type'],
            'tram',
            _hexFor(VehicleType.tram),
            'bus',
            _hexFor(VehicleType.bus),
            _hexFor(VehicleType.unknown),
          ],
          circleRadius: 14,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );

      // Number label inside the circle. Tram (yellow) needs black text;
      // bus/unknown (magenta/gray) need white text.
      await controller.addSymbolLayer(
        _sourceId,
        _labelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'number'],
          textSize: 11,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textFont: ['Open Sans Bold'],
          textColor: [
            'match',
            ['get', 'type'],
            'tram',
            '#000000',
            '#ffffff',
          ],
        ),
      );

      // Bearing arrow — small navigation triangle anchored to the right of
      // the circle, rotated by `bearing`. Hidden when bearing is missing.
      await controller.addSymbolLayer(
        _sourceId,
        _bearingLayerId,
        const SymbolLayerProperties(
          textField: '▲',
          textSize: 12,
          textColor: '#1A1C1C',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.5,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textRotate: ['get', 'bearing'],
          textOffset: [1.3, -1.3],
          textRotationAlignment: 'map',
        ),
        filter: ['has', 'bearing'],
      );

      _initialized = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  static String _hexFor(VehicleType t) {
    final argb = kVehicleColors[t]!.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Map<String, dynamic> _toFeatureCollection(
    List<Vehicle> vehicles,
    RoutesIndex routes,
  ) {
    final features = vehicles.map((v) {
      final line = resolveLine(v.routeId, routes);
      final props = <String, dynamic>{
        'number': line.number,
        'type': line.type.name,
        'routeId': v.routeId,
      };
      if (v.bearing != null) props['bearing'] = v.bearing;
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [v.lon, v.lat],
        },
        'properties': props,
      };
    }).toList();
    final fc = {'type': 'FeatureCollection', 'features': features};
    // sanity: must round-trip JSON cleanly
    jsonEncode(fc);
    return fc;
  }
}
```

- [ ] **Step 2: Run analyzer + tests**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/features/map/views/vehicle_markers_layer.dart
git commit -m "feat(map): repaint vehicle markers + add bearing arrow layer"
```

---

## Task 12: `RootShell` with bottom nav and stub tabs

**Files:**
- Create: `lib/ui/features/shell/views/lines_screen.dart`
- Create: `lib/ui/features/shell/views/favorites_screen.dart`
- Create: `lib/ui/features/shell/views/root_shell.dart`
- Create: `test/ui/features/shell/root_shell_test.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create both stub screens**

Create `lib/ui/features/shell/views/lines_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../map/views/top_app_bar.dart';

class LinesScreen extends StatelessWidget {
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: const LodzTopAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LodzSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_transit,
                size: 64,
                color: LodzColors.outline,
              ),
              const SizedBox(height: LodzSpacing.md),
              Text(
                l10n.navLines,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: LodzSpacing.xs),
              Text(
                l10n.screenComingSoon,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LodzColors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `lib/ui/features/shell/views/favorites_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../map/views/top_app_bar.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: const LodzTopAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LodzSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_border,
                  size: 64, color: LodzColors.outline),
              const SizedBox(height: LodzSpacing.md),
              Text(
                l10n.navFavorites,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: LodzSpacing.xs),
              Text(
                l10n.screenComingSoon,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LodzColors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write failing root-shell test**

Create `test/ui/features/shell/root_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/favorites_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/lines_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/root_shell.dart';
import 'package:provider/provider.dart';

void main() {
  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => MapViewModel(
              repository: VehiclesRepository(service: GtfsRtService()),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BootstrapViewModel(
              repository: RoutesRepository(
                staticService: GtfsStaticService(),
                cacheService: RoutesCacheService(),
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_) => FilterViewModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets('RootShell shows three nav destinations', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));
    await tester.pump();

    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.directions_transit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsWidgets);
  });

  testWidgets('Tapping Lines and Favorites swaps the screen', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.directions_transit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(LinesScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test — verify it fails**

Run: `flutter test test/ui/features/shell/root_shell_test.dart`
Expected: FAIL — `RootShell` does not exist.

- [ ] **Step 4: Create `lib/ui/features/shell/views/root_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../map/views/map_screen.dart';
import 'favorites_screen.dart';
import 'lines_screen.dart';

/// Top-level app shell. Hosts the bottom nav and the three tab screens.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = <Widget>[
    MapScreen(),
    LinesScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _LodzBottomNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        labels: [l10n.navMap, l10n.navLines, l10n.navFavorites],
      ),
    );
  }
}

class _LodzBottomNav extends StatelessWidget {
  const _LodzBottomNav({
    required this.index,
    required this.onSelect,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LodzRadius.xl),
        ),
        border: Border(top: BorderSide(color: scheme.surfaceVariant)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // ~4% black
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                active: index == 0,
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: labels[0],
                onTap: () => onSelect(0),
              ),
              _NavItem(
                active: index == 1,
                icon: Icons.directions_transit_outlined,
                activeIcon: Icons.directions_transit,
                label: labels[1],
                onTap: () => onSelect(1),
              ),
              _NavItem(
                active: index == 2,
                icon: Icons.star_border,
                activeIcon: Icons.star,
                label: labels[2],
                onTap: () => onSelect(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? LodzColors.transitCyan : scheme.outline;
    final bg = active ? LodzColors.cyanSurface : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LodzRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LodzRadius.xl),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.lg,
          vertical: LodzSpacing.xs,
        ),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color),
            const SizedBox(height: LodzSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test — verify it passes**

Run: `flutter test test/ui/features/shell/root_shell_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Wire `RootShell` into `lib/main.dart`**

In `lib/main.dart`, replace these two lines:

```dart
import 'ui/features/map/views/map_screen.dart';
```

→

```dart
import 'ui/features/shell/views/root_shell.dart';
```

and

```dart
        home: const MapScreen(),
```

→

```dart
        home: const RootShell(),
```

- [ ] **Step 7: Run analyzer + full test suite**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/features/shell/views/lines_screen.dart \
        lib/ui/features/shell/views/favorites_screen.dart \
        lib/ui/features/shell/views/root_shell.dart \
        test/ui/features/shell/root_shell_test.dart \
        lib/main.dart
git commit -m "feat(shell): add bottom-nav root shell with Lines/Favorites stubs"
```

---

## Task 13: Manual smoke test on device

**Files:**
- Modify: `docs/manual-test.md` (only if a checklist for the new UI is missing).

- [ ] **Step 1: Run the app**

Run:

```bash
flutter run --dart-define=MAPTILER_KEY=$MAPTILER_KEY
```

Expected: app launches on attached device/emulator with the redesigned UI.

- [ ] **Step 2: Walk the visual checklist**

Verify on screen:

1. Top app bar — translucent white with subtle bottom border, "Łódź Transit" title in heavy Inter, menu icon left, settings icon right.
2. Floating search bar sits ~24 pt below the app bar — pill-shaped, white, light shadow, search icon left, placeholder "Szukaj linii…", round tune button on the right.
3. Tapping the search field OR the tune button opens the redesigned filter sheet (drag handle, rounded search input with cyan focus, line chips below).
4. Tram chips show as yellow pills with black text when selected; bus chips magenta with white text. Unselected chips are white with a thin gray outline.
5. Vehicle markers on the map: tram = yellow circle, bus = magenta circle, white halo, line number centered (black on yellow, white on magenta), small dark arrow on the upper-right edge rotated to the vehicle bearing (only when the feed reports bearing).
6. Locate FAB — bottom-right, white circular button with cyan `my_location` icon and a soft level-2 shadow.
7. Last-update hint — bottom-left, small white pill with subtle level-1 shadow and "aktualizacja: Ns temu" copy.
8. Bottom nav — three tabs (Mapa / Linie / Ulubione). Active tab gets a soft cyan background pill, cyan icon + label; inactive tabs are gray. Tapping Linie shows a "Wkrótce" placeholder; tapping Ulubione likewise.
9. Returning to Mapa restores the live map (verify polling still ticks via the last-update hint counting up).

- [ ] **Step 3: If anything fails, file a follow-up**

Fix inline if it's a quick visual nudge; otherwise jot a task line for a follow-up commit. Do not add scope — keep this plan finished.

- [ ] **Step 4: Final commit (only if doc updates)**

If `docs/manual-test.md` needed an update to cover the new UI:

```bash
git add docs/manual-test.md
git commit -m "docs: refresh manual smoke test for Stitch restyle"
```

Otherwise skip this step.

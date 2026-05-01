import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gf_base;
import 'package:mpk_lodz_tracker/ui/core/app_theme.dart';
import 'package:mpk_lodz_tracker/ui/core/design_tokens.dart';

void main() {
  setUpAll(() {
    // google_fonts requires the binding to be initialized before calling
    // GoogleFonts.*() functions, even in plain unit tests.
    TestWidgetsFlutterBinding.ensureInitialized();
  });
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

  test('buildLightTheme uses LodzColors and Inter font', () async {
    // Prevent google_fonts from hitting the network; supply a stub manifest
    // so it believes no pre-bundled assets exist either. The fontFamily string
    // on the returned TextStyle is set synchronously before any async load is
    // dispatched, so all value assertions below hold regardless of font-byte
    // availability.
    GoogleFonts.config.allowRuntimeFetching = false;
    gf_base.assetManifest = _EmptyAssetManifest();

    // Run inside a zone that silences expected google_fonts load errors
    // (font bytes unavailable in test env). Assertions run synchronously
    // inside the same zone, so failures are still reported as test failures.
    Object? testFailure;
    await runZonedGuarded(
      () async {
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

        // Yield so that the font-load futures (which fire async) can settle
        // inside this zone where errors are swallowed.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      (error, stack) {
        // Only swallow google_fonts font-load errors. Re-surface any
        // unexpected error as a test failure.
        if (error.toString().contains('google_fonts') ||
            error.toString().contains('GoogleFonts') ||
            error.toString().contains('font')) {
          // Expected: font bytes unavailable in test environment.
          return;
        }
        testFailure = error;
      },
    );

    if (testFailure != null) {
      fail('Unexpected error: $testFailure');
    }

    gf_base.clearCache();
    gf_base.assetManifest = null;
    GoogleFonts.config.allowRuntimeFetching = true;
  });
}

/// Stub [AssetManifest] that reports no pre-bundled assets, so google_fonts
/// skips the asset-bundle lookup and moves straight to (disabled) network.
class _EmptyAssetManifest implements AssetManifest {
  @override
  List<String> listAssets() => const [];

  @override
  List<AssetMetadata> getAssetVariants(String key) => const [];
}

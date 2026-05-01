import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mpk_lodz_tracker/ui/core/app_theme.dart';
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

  testWidgets('buildLightTheme uses LodzColors and Inter font', (tester) async {
    // Block google_fonts from making real network calls in tests; the
    // synchronous TextStyle metadata (fontFamily / size / height) is set
    // before any async font-byte fetch, so the assertions below hold.
    GoogleFonts.config.allowRuntimeFetching = false;

    final theme = buildLightTheme();
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const SizedBox(),
    ));

    expect(theme.colorScheme.primary, LodzColors.primary);
    expect(theme.colorScheme.surface, LodzColors.surface);
    expect(theme.colorScheme.secondary, LodzColors.secondary);
    expect(theme.useMaterial3, isTrue);

    final body = theme.textTheme.bodyMedium!;
    expect(body.fontFamily, contains('Inter'));
    expect(body.fontSize, 16);
    expect(body.height, closeTo(24 / 16, 0.001));
  });
}

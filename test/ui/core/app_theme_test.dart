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

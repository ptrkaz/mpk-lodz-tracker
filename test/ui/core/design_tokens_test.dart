import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/ui/core/design_tokens.dart';

void main() {
  test('LodzShadows.sheet uses upward offset', () {
    expect(LodzShadows.sheet, isNotEmpty);
    expect(LodzShadows.sheet.first.offset.dy, lessThan(0));
  });

  test('LodzColors.success is set', () {
    expect(LodzColors.success.value, isNot(0));
  });
}

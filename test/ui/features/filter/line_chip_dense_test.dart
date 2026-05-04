import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/views/line_chip.dart';

void main() {
  testWidgets('dense chip is shorter than default', (tester) async {
    Future<Size> measure(LineChipSize size) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LineChip(
              number: '12',
              type: VehicleType.tram,
              selected: true,
              onTap: () {},
              size: size,
            ),
          ),
        ),
      ));
      return tester.getSize(find.byType(LineChip));
    }

    final big = await measure(LineChipSize.regular);
    final small = await measure(LineChipSize.dense);
    expect(small.height, lessThan(big.height));
  });
}

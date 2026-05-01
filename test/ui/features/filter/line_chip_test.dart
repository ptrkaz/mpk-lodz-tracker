import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/vehicle_colors.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/views/line_chip.dart';

void main() {
  testWidgets('renders number and toggles selected style', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '8',
          type: VehicleType.tram,
          selected: false,
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.byType(LineChip));
    expect(taps, 1);
  });

  testWidgets('selected variant fills with the type color', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '46A',
          type: VehicleType.bus,
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    final container = tester.widget<Container>(find.byKey(const ValueKey('line-chip-container')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, kVehicleColors[VehicleType.bus]);
  });
}

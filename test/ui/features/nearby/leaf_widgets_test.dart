import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/departure_row.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/nearby_list_row.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/permission_cta_view.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/widgets/sheet_handle.dart';

Widget _wrap(Widget w) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: w),
    );

void main() {
  testWidgets('SheetHandle renders a pill', (tester) async {
    await tester.pumpWidget(_wrap(const SheetHandle()));
    expect(find.byType(SheetHandle), findsOneWidget);
  });

  testWidgets('NearbyListRow shows name + distance + walk time', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListRow(
      stop: const Stop(id: '1', name: 'Plac Wolności', lat: 0, lon: 0),
      lineNumbers: const ['12', '86'],
      lineTypes: const [VehicleType.tram, VehicleType.bus],
      distanceM: 120,
      onTap: () {},
    )));
    expect(find.text('Plac Wolności'), findsOneWidget);
    expect(find.textContaining('120 m'), findsOneWidget);
    expect(find.textContaining('~2 min'), findsOneWidget);
  });

  testWidgets('DepartureRow shows ETA in min when <60min', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(DepartureRow(
      departure: Departure(
        lineNumber: '12',
        lineType: VehicleType.tram,
        headsign: 'Stoki',
        etaUnixSec: now.millisecondsSinceEpoch ~/ 1000 + 180,
        delaySec: 60,
      ),
      now: now,
    )));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Stoki'), findsOneWidget);
    expect(find.textContaining('3 min'), findsOneWidget);
    expect(find.textContaining('+1 min'), findsOneWidget);
  });

  testWidgets('PermissionCtaView dispatches correct action by status',
      (tester) async {
    String? action;
    await tester.pumpWidget(_wrap(PermissionCtaView(
      status: LocationStatus.deniedForever,
      onGrant: () => action = 'grant',
      onOpenSettings: () => action = 'settings',
    )));
    await tester.tap(find.byType(FilledButton));
    expect(action, 'settings');
  });
}

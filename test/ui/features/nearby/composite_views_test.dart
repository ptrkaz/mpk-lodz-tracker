import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/nearby_list_view.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/stop_detail_view.dart';

Widget _wrap(Widget w) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: w),
    );

void main() {
  testWidgets('NearbyListView empty shows "Brak przystanków..."', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListView(
      stops: const [],
      linesByStopId: const {},
      distancesByStopId: const {},
      onTapStop: (_) {},
    )));
    expect(find.textContaining('Brak przystanków'), findsOneWidget);
  });

  testWidgets('NearbyListView renders rows', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListView(
      stops: const [Stop(id: '1', name: 'Plac', lat: 0, lon: 0)],
      linesByStopId: const {
        '1': [(number: '12', type: VehicleType.tram)],
      },
      distancesByStopId: const {'1': 100.0},
      onTapStop: (_) {},
    )));
    expect(find.text('Plac'), findsOneWidget);
  });

  testWidgets('StopDetailView empty state', (tester) async {
    await tester.pumpWidget(_wrap(StopDetailView(
      stop: const Stop(id: '1', name: 'Plac', lat: 0, lon: 0),
      departures: const [],
      lastFetched: DateTime.now(),
      now: DateTime.now(),
      onBack: () {},
    )));
    expect(find.textContaining('Brak nadchodzących odjazdów'), findsOneWidget);
  });

  testWidgets('StopDetailView renders departures', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(StopDetailView(
      stop: const Stop(id: '1', name: 'Plac', lat: 0, lon: 0),
      departures: [
        Departure(
          lineNumber: '12',
          lineType: VehicleType.tram,
          headsign: 'Stoki',
          etaUnixSec: now.millisecondsSinceEpoch ~/ 1000 + 180,
          delaySec: 0,
        ),
      ],
      lastFetched: now,
      now: now,
      onBack: () {},
    )));
    expect(find.text('Stoki'), findsOneWidget);
  });
}

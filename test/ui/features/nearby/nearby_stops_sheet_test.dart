import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/departures_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_sheet.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/nearby_list_view.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/permission_cta_view.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _NoOpLocation implements LocationGateway {
  const _NoOpLocation();

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Stream<Position> positionStream({double distanceFilter = 25}) =>
      const Stream.empty();
  @override
  Future<Position?> getLastKnown() async => null;
  @override
  Future<void> openAppSettings() async {}
}

class _NoOpFixStore implements LastFixStore {
  @override
  Future<({double lat, double lon})?> read() async => null;
  @override
  Future<void> write(Position pos) async {}
}

/// A subclass of [NearbyStopsViewModel] that lets us override public state
/// without running the full init() flow.
class _OverrideVm extends NearbyStopsViewModel {
  _OverrideVm({
    LocationStatus? status,
    Stop? selected,
    List<Stop>? nearby,
    Map<String, double>? distances,
  }) : super(
          stopsRepo: StopsRepository.test(const {}),
          location: const _NoOpLocation(), // ignore: unused_element
          lastFixStore: _NoOpFixStore(),
        ) {
    if (status != null) _overrideStatus = status;
    if (selected != null) _overrideSelected = selected;
    if (nearby != null) _overrideNearby = nearby;
    if (distances != null) _overrideDistances = distances;
  }

  LocationStatus? _overrideStatus;
  Stop? _overrideSelected;
  List<Stop>? _overrideNearby;
  Map<String, double>? _overrideDistances;

  @override
  LocationStatus get status => _overrideStatus ?? super.status;
  @override
  Stop? get selected => _overrideSelected ?? super.selected;
  @override
  List<Stop> get nearby => _overrideNearby ?? super.nearby;
  @override
  Map<String, double> get distancesByStopId =>
      _overrideDistances ?? super.distancesByStopId;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, NearbyStopsViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NearbyStopsViewModel>.value(value: vm),
      ChangeNotifierProvider<FilterViewModel>(create: (_) => FilterViewModel()),
      ChangeNotifierProvider<AppLifecycleNotifier>(
          create: (_) => AppLifecycleNotifier()),
      ChangeNotifierProvider<TripUpdatesRepository>(
        create: (_) =>
            TripUpdatesRepository(service: TripUpdatesService()),
      ),
      ProxyProvider<TripUpdatesRepository, DeparturesRepository>(
        update: (_, tu, prev) => DeparturesRepository(
          tripUpdates: tu,
          trips: const {},
          routes: const {},
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      // DraggableScrollableSheet needs a bounded Stack ancestor.
      home: Scaffold(
        body: SizedBox.expand(
          child: Stack(children: [child]),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'status=granted, nothing selected → NearbyListView is shown',
    (tester) async {
      // Use a taller surface so the sheet peek-fraction fits header content.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = _OverrideVm(status: LocationStatus.granted);
      await tester.pumpWidget(_wrap(const NearbyStopsSheet(), vm));
      await tester.pump();
      expect(find.byType(NearbyListView), findsOneWidget);
      vm.dispose();
    },
  );

  testWidgets(
    'status=denied → PermissionCtaView is shown',
    (tester) async {
      final vm = _OverrideVm(status: LocationStatus.denied);
      await tester.pumpWidget(_wrap(const NearbyStopsSheet(), vm));
      await tester.pump();
      expect(find.byType(PermissionCtaView), findsOneWidget);
      vm.dispose();
    },
  );

  testWidgets(
    'status=granted with stops → rows rendered',
    (tester) async {
      final vm = _OverrideVm(
        status: LocationStatus.granted,
        nearby: const [
          Stop(id: '1', name: 'Piotrkowska', lat: 51.76, lon: 19.45),
        ],
        distances: const {'1': 42.0},
      );
      await tester.pumpWidget(_wrap(const NearbyStopsSheet(), vm));
      await tester.pump();
      expect(find.text('Piotrkowska'), findsOneWidget);
      vm.dispose();
    },
  );
}

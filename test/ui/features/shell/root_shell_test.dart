import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/favorites_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/lines_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/root_shell.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Minimal fakes so NearbyStopsViewModel never tries to touch the OS.
// ---------------------------------------------------------------------------

class _NoOpLocation implements LocationGateway {
  const _NoOpLocation();

  @override
  Future<bool> isLocationServiceEnabled() async => false;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
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

void main() {
  Widget wrap(Widget child) {
    final lifecycle = AppLifecycleNotifier(); // unattached — no binding needed
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLifecycleNotifier>.value(value: lifecycle),
        ChangeNotifierProvider(
          create: (_) => MapViewModel(
            repository: VehiclesRepository(service: GtfsRtService()),
            lifecycle: lifecycle,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BootstrapViewModel(
            repository: RoutesRepository(
              staticService: GtfsStaticService(),
              cacheService: GtfsCacheService(),
            ),
            stopsRepository: StopsRepository.test(const <String, Stop>{}),
            tripsLoader: () async => const <String, TripInfo>{},
          ),
        ),
        ChangeNotifierProvider(create: (_) => FilterViewModel()),
        ChangeNotifierProvider<NearbyStopsViewModel>(
          create: (_) => NearbyStopsViewModel(
            stopsRepo: StopsRepository.test(const <String, Stop>{}),
            location: const _NoOpLocation(),
            lastFixStore: _NoOpFixStore(),
          ),
          // Do NOT call init() — it would trigger geolocator on a test runner.
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

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

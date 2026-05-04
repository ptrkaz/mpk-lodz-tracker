import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_cache_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';

// ---------------------------------------------------------------------------
// Minimal fakes — no mocktail needed for pure-Dart fakes.
// ---------------------------------------------------------------------------

final _fixtureRoutes = <String, Line>{
  'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
};
final _fixtureStops = <String, Stop>{
  's1': const Stop(id: 's1', name: 'Piotrkowska', lat: 51.77, lon: 19.45),
};
final _fixtureTrips = <String, TripInfo>{
  't1': const TripInfo(tripId: 't1', routeId: 'r1', headsign: 'Chojny'),
};

final _fixtureBundle = GtfsCachedBundle(
  routes: _fixtureRoutes,
  stops: _fixtureStops,
  trips: _fixtureTrips,
);
final _fixtureStaticBundle = GtfsStaticBundle(
  routes: _fixtureRoutes,
  stops: _fixtureStops,
  trips: _fixtureTrips,
);

class _FakeCache implements GtfsCacheService {
  _FakeCache({this.bundle});
  final GtfsCachedBundle? bundle;

  @override
  Future<GtfsCachedBundle?> readBundle({required Duration maxAge}) async =>
      bundle;

  @override
  Future<void> writeBundle(GtfsCachedBundle bundle) async {}
}

class _FakeStatic implements GtfsStaticService {
  @override
  Future<RoutesIndex> fetchAndParseRoutes() async => _fixtureRoutes;

  @override
  Future<GtfsStaticBundle> fetchAndParseAll() async => _fixtureStaticBundle;
}

RoutesRepository _makeRoutes(GtfsCacheService cache) =>
    RoutesRepository(staticService: _FakeStatic(), cacheService: cache);

StopsRepository _makeStops(GtfsCacheService cache) =>
    StopsRepository(staticService: _FakeStatic(), cacheService: cache);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('loads routes, stops, and trips on bootstrap — cache hit', () async {
    final cache = _FakeCache(bundle: _fixtureBundle);
    final routesRepo = _makeRoutes(cache);
    final stopsRepo = _makeStops(cache);

    final vm = BootstrapViewModel(
      repository: routesRepo,
      stopsRepository: stopsRepo,
      tripsLoader: () async => _fixtureTrips,
    );

    // Wait for _load() to complete.
    await Future<void>.delayed(Duration.zero);

    expect(vm.routes, _fixtureRoutes);
    expect(vm.stops, _fixtureStops);
    expect(vm.trips, _fixtureTrips);
    expect(vm.error, isNull);
    expect(vm.ready, isTrue);
  });

  test('loads routes, stops, and trips on bootstrap — cache miss (network)',
      () async {
    final cache = _FakeCache(); // no bundle → will fetch
    final routesRepo = _makeRoutes(cache);
    final stopsRepo = _makeStops(cache);

    final vm = BootstrapViewModel(
      repository: routesRepo,
      stopsRepository: stopsRepo,
      tripsLoader: () async => _fixtureTrips,
    );

    await Future<void>.delayed(Duration.zero);

    expect(vm.routes, _fixtureRoutes);
    expect(vm.stops, _fixtureStops);
    expect(vm.trips, _fixtureTrips);
    expect(vm.error, isNull);
    expect(vm.ready, isTrue);
  });

  test('soft-degrades when tripsLoader throws', () async {
    final cache = _FakeCache(bundle: _fixtureBundle);
    final routesRepo = _makeRoutes(cache);
    final stopsRepo = _makeStops(cache);

    final vm = BootstrapViewModel(
      repository: routesRepo,
      stopsRepository: stopsRepo,
      tripsLoader: () async => throw Exception('network error'),
    );

    await Future<void>.delayed(Duration.zero);

    // Routes and stops loaded successfully; trips degraded to empty map.
    expect(vm.routes, _fixtureRoutes);
    expect(vm.stops, _fixtureStops);
    expect(vm.trips, const <String, TripInfo>{});
    expect(vm.error, isNull); // no hard error for trips failure
    expect(vm.ready, isTrue);
  });

  test('notifies listeners once after all three are loaded', () async {
    final cache = _FakeCache(bundle: _fixtureBundle);
    final routesRepo = _makeRoutes(cache);
    final stopsRepo = _makeStops(cache);
    int notifyCount = 0;

    final vm = BootstrapViewModel(
      repository: routesRepo,
      stopsRepository: stopsRepo,
      tripsLoader: () async => _fixtureTrips,
    );
    vm.addListener(() => notifyCount++);

    await Future<void>.delayed(Duration.zero);

    expect(notifyCount, 1);
    expect(vm.ready, isTrue);
  });
}

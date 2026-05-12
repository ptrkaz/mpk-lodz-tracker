import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_cache_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/route_shape.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

class _MockStatic extends Mock implements GtfsStaticService {}

class _MockCache extends Mock implements GtfsCacheService {}

void main() {
  late _MockStatic staticService;
  late _MockCache cacheService;
  late RoutesRepository repo;

  final fixtureRoutes = <String, Line>{
    'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
  };
  final fixtureBundle = GtfsCachedBundle(
    routes: fixtureRoutes,
    stops: <String, Stop>{},
    trips: <String, TripInfo>{},
    routeShapes: const {
      'r1': RouteShape(
        routeId: 'r1',
        points: [
          ShapePoint(lat: 51.7, lon: 19.4),
          ShapePoint(lat: 51.8, lon: 19.5),
        ],
      ),
    },
  );
  final fixtureStaticBundle = GtfsStaticBundle(
    routes: fixtureRoutes,
    stops: <String, Stop>{},
    trips: <String, TripInfo>{},
    routeShapes: fixtureBundle.routeShapes,
  );

  setUpAll(() {
    registerFallbackValue(const Duration(days: 7));
    registerFallbackValue(fixtureBundle);
  });

  setUp(() {
    staticService = _MockStatic();
    cacheService = _MockCache();
    repo = RoutesRepository(
      staticService: staticService,
      cacheService: cacheService,
    );
  });

  test('returns cached routes when bundle is present and fresh', () async {
    when(
      () => cacheService.readBundle(maxAge: any(named: 'maxAge')),
    ).thenAnswer((_) async => fixtureBundle);

    final result = await repo.getRoutes();
    expect(result, fixtureRoutes);
    verifyNever(() => staticService.fetchAndParseAll());
  });

  test('falls back to fetching and writes cache when miss', () async {
    when(
      () => cacheService.readBundle(maxAge: any(named: 'maxAge')),
    ).thenAnswer((_) async => null);
    when(
      () => staticService.fetchAndParseAll(),
    ).thenAnswer((_) async => fixtureStaticBundle);
    when(() => cacheService.writeBundle(any())).thenAnswer((_) async {});

    final result = await repo.getRoutes();
    expect(result, fixtureRoutes);
    verify(() => cacheService.writeBundle(any())).called(1);
  });

  test('returns route shapes from cached static bundle', () async {
    when(
      () => cacheService.readBundle(maxAge: any(named: 'maxAge')),
    ).thenAnswer((_) async => fixtureBundle);

    final result = await repo.getRouteShapes();

    expect(result['r1']!.points, hasLength(2));
    verifyNever(() => staticService.fetchAndParseAll());
  });
}

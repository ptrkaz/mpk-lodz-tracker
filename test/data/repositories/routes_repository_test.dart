import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

class _MockStatic extends Mock implements GtfsStaticService {}
class _MockCache extends Mock implements RoutesCacheService {}

void main() {
  late _MockStatic staticService;
  late _MockCache cacheService;
  late RoutesRepository repo;

  final fixtureIndex = <String, Line>{
    'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
  };

  setUpAll(() {
    registerFallbackValue(<String, Line>{});
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    staticService = _MockStatic();
    cacheService = _MockCache();
    repo = RoutesRepository(staticService: staticService, cacheService: cacheService);
  });

  test('returns cached index when present and fresh', () async {
    when(() => cacheService.read(maxAge: any(named: 'maxAge')))
        .thenAnswer((_) async => fixtureIndex);

    final result = await repo.getRoutes();
    expect(result, fixtureIndex);
    verifyNever(() => staticService.fetchAndParseRoutes());
  });

  test('falls back to fetching and writes cache when miss', () async {
    when(() => cacheService.read(maxAge: any(named: 'maxAge')))
        .thenAnswer((_) async => null);
    when(() => staticService.fetchAndParseRoutes())
        .thenAnswer((_) async => fixtureIndex);
    when(() => cacheService.write(any())).thenAnswer((_) async {});

    final result = await repo.getRoutes();
    expect(result, fixtureIndex);
    verify(() => cacheService.write(fixtureIndex)).called(1);
  });
}

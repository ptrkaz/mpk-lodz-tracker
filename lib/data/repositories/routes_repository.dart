import '../../domain/models/line.dart';
import '../../domain/models/route_shape.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_cache_service.dart';
import '../services/gtfs_static_service.dart';

class RoutesRepository {
  RoutesRepository({
    required GtfsStaticService staticService,
    required GtfsCacheService cacheService,
  }) : _static = staticService,
       _cache = cacheService;

  final GtfsStaticService _static;
  final GtfsCacheService _cache;

  Future<GtfsCachedBundle> getStaticBundle() async {
    final cached = await _cache.readBundle(
      maxAge: LodzConstants.routesCacheTtl,
    );
    if (cached != null) return cached;
    final fresh = await _static.fetchAndParseAll();
    final bundle = GtfsCachedBundle(
      routes: fresh.routes,
      stops: fresh.stops,
      trips: fresh.trips,
      routeShapes: fresh.routeShapes,
    );
    await _cache.writeBundle(bundle);
    return bundle;
  }

  Future<RoutesIndex> getRoutes() async {
    return (await getStaticBundle()).routes;
  }

  Future<RouteShapesIndex> getRouteShapes() async {
    return (await getStaticBundle()).routeShapes;
  }
}

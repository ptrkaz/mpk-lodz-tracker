import '../../domain/models/line.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_cache_service.dart';
import '../services/gtfs_static_service.dart';

class RoutesRepository {
  RoutesRepository({
    required GtfsStaticService staticService,
    required GtfsCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  final GtfsStaticService _static;
  final GtfsCacheService _cache;

  Future<RoutesIndex> getRoutes() async {
    final cached =
        await _cache.readBundle(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) return cached.routes;
    final fresh = await _static.fetchAndParseAll();
    await _cache.writeBundle(GtfsCachedBundle(
      routes: fresh.routes,
      stops: fresh.stops,
      trips: fresh.trips,
    ));
    return fresh.routes;
  }
}

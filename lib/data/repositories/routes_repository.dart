import '../../domain/models/line.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_static_service.dart';
import '../services/routes_cache_service.dart';

class RoutesRepository {
  RoutesRepository({
    required GtfsStaticService staticService,
    required RoutesCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  final GtfsStaticService _static;
  final RoutesCacheService _cache;

  Future<RoutesIndex> getRoutes() async {
    final cached = await _cache.read(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) return cached;
    final fresh = await _static.fetchAndParseRoutes();
    await _cache.write(fresh);
    return fresh;
  }
}

import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

import '../../domain/models/stop.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_cache_service.dart';
import '../services/gtfs_static_service.dart';

class StopsRepository {
  StopsRepository({
    required GtfsStaticService staticService,
    required GtfsCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  /// Test-only constructor that injects a pre-loaded index.
  @visibleForTesting
  StopsRepository.test(StopsIndex index)
      : _static = null,
        _cache = null,
        _index = index;

  final GtfsStaticService? _static;
  final GtfsCacheService? _cache;
  StopsIndex? _index;

  Future<StopsIndex> getStops() async {
    if (_index != null) return _index!;
    final cache = _cache!;
    final staticSvc = _static!;
    final cached = await cache.readBundle(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) {
      _index = cached.stops;
      return _index!;
    }
    final fresh = await staticSvc.fetchAndParseAll();
    await cache.writeBundle(GtfsCachedBundle(
      routes: fresh.routes,
      stops: fresh.stops,
      trips: fresh.trips,
    ));
    _index = fresh.stops;
    return _index!;
  }

  List<Stop> nearby(
    Position pos, {
    double radiusM = LodzConstants.nearbyRadiusM,
    int limit = LodzConstants.nearbyLimit,
  }) {
    final idx = _index;
    if (idx == null) return const [];
    final scored = <_Scored>[];
    for (final s in idx.values) {
      final d = _haversine(pos.latitude, pos.longitude, s.lat, s.lon);
      if (d <= radiusM) scored.add(_Scored(s, d));
    }
    scored.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return scored.take(limit).map((e) => e.stop).toList();
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg(lat1)) *
            math.cos(_deg(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static double _deg(double v) => v * math.pi / 180.0;
}

class _Scored {
  _Scored(this.stop, this.distanceM);
  final Stop stop;
  final double distanceM;
}

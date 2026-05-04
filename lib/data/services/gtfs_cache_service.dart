import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/line.dart';
import '../../domain/models/stop.dart';
import '../../domain/models/trip_info.dart';
import '../../domain/models/vehicle.dart';

typedef DirectoryProvider = Future<Directory> Function();

class GtfsCachedBundle {
  const GtfsCachedBundle({
    required this.routes,
    required this.stops,
    required this.trips,
  });
  final RoutesIndex routes;
  final StopsIndex stops;
  final TripsIndex trips;
}

class GtfsCacheService {
  GtfsCacheService({DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final DirectoryProvider _directoryProvider;

  static const _routesName = 'routes.json';
  static const _stopsName = 'stops.json';
  static const _tripsName = 'trips.json';

  Future<File> _file(String name) async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$name');
  }

  Future<GtfsCachedBundle?> readBundle({required Duration maxAge}) async {
    final routesFile = await _file(_routesName);
    final stopsFile = await _file(_stopsName);
    final tripsFile = await _file(_tripsName);
    if (!routesFile.existsSync() ||
        !stopsFile.existsSync() ||
        !tripsFile.existsSync()) {
      return null;
    }
    final times = await Future.wait([
      routesFile.lastModified(),
      stopsFile.lastModified(),
      tripsFile.lastModified(),
    ]);
    final oldest = times.reduce((a, b) => a.isBefore(b) ? a : b);
    if (DateTime.now().difference(oldest) > maxAge) return null;

    return GtfsCachedBundle(
      routes: _decodeRoutes(jsonDecode(await routesFile.readAsString())),
      stops: _decodeStops(jsonDecode(await stopsFile.readAsString())),
      trips: _decodeTrips(jsonDecode(await tripsFile.readAsString())),
    );
  }

  Future<void> writeBundle(GtfsCachedBundle bundle) async {
    await (await _file(_routesName))
        .writeAsString(jsonEncode(_encodeRoutes(bundle.routes)));
    await (await _file(_stopsName))
        .writeAsString(jsonEncode(_encodeStops(bundle.stops)));
    await (await _file(_tripsName))
        .writeAsString(jsonEncode(_encodeTrips(bundle.trips)));
  }

  // routes
  static Map<String, dynamic> _encodeRoutes(RoutesIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {'routeId': v.routeId, 'number': v.number, 'type': v.type.name};
    });
    return out;
  }

  static RoutesIndex _decodeRoutes(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, Line>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = Line(
        routeId: j['routeId'] as String,
        number: j['number'] as String,
        type: VehicleType.values.firstWhere(
          (t) => t.name == (j['type'] as String),
          orElse: () => VehicleType.unknown,
        ),
      );
    });
    return out;
  }

  // stops
  static Map<String, dynamic> _encodeStops(StopsIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {'id': v.id, 'name': v.name, 'lat': v.lat, 'lon': v.lon};
    });
    return out;
  }

  static StopsIndex _decodeStops(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, Stop>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = Stop(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
    });
    return out;
  }

  // trips
  static Map<String, dynamic> _encodeTrips(TripsIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {
        'tripId': v.tripId,
        'routeId': v.routeId,
        'headsign': v.headsign,
      };
    });
    return out;
  }

  static TripsIndex _decodeTrips(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, TripInfo>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = TripInfo(
        tripId: j['tripId'] as String,
        routeId: j['routeId'] as String,
        headsign: j['headsign'] as String,
      );
    });
    return out;
  }
}

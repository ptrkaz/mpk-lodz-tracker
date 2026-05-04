import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart' show CsvDecoder;
import 'package:http/http.dart' as http;
import '../../domain/models/line.dart';
import '../../domain/models/stop.dart';
import '../../domain/models/trip_info.dart';
import '../../domain/models/vehicle.dart';
import '../models/route_api_model.dart';

class GtfsStaticBundle {
  const GtfsStaticBundle({
    required this.routes,
    required this.stops,
    required this.trips,
  });
  final RoutesIndex routes;
  final StopsIndex stops;
  final TripsIndex trips;
}

class GtfsStaticService {
  GtfsStaticService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri staticUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/GTFS.zip',
  );

  final http.Client _client;

  Future<RoutesIndex> fetchAndParseRoutes() async {
    final res = await _client.get(staticUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS static fetch failed: ${res.statusCode}');
    }
    return parseRoutesFromZip(res.bodyBytes);
  }

  Future<GtfsStaticBundle> fetchAndParseAll() async {
    final res = await _client.get(staticUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS static fetch failed: ${res.statusCode}');
    }
    final bytes = res.bodyBytes;
    final routes = await parseRoutesFromZip(bytes);
    final stops = await parseStopsFromZip(bytes);
    final trips = await parseTripsFromZip(bytes);
    return GtfsStaticBundle(routes: routes, stops: stops, trips: trips);
  }

  static Future<RoutesIndex> parseRoutesFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('routes.txt');
    if (entry == null) {
      throw Exception('routes.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content);
    final rows = const CsvDecoder(
      dynamicTyping: false,
    ).convert(csvText);
    if (rows.isEmpty) return <String, Line>{};

    final headers = rows.first.cast<String>();
    final index = <String, Line>{};
    for (var i = 1; i < rows.length; i++) {
      final raw = rows[i];
      final map = <String, String>{};
      for (var c = 0; c < headers.length && c < raw.length; c++) {
        map[headers[c]] = raw[c].toString();
      }
      final api = RouteApiModel.fromCsvRow(map);
      if (api.routeId.isEmpty || api.shortName.isEmpty) continue;
      index[api.routeId] = Line(
        routeId: api.routeId,
        number: api.shortName,
        type: _mapType(api.routeType),
      );
    }
    return index;
  }

  static Future<StopsIndex> parseStopsFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('stops.txt');
    if (entry == null) {
      throw Exception('stops.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content);
    final rows = const CsvDecoder(dynamicTyping: false).convert(csvText);
    if (rows.isEmpty) return <String, Stop>{};

    final headers = rows.first.cast<String>();
    final iId = headers.indexOf('stop_id');
    final iName = headers.indexOf('stop_name');
    final iLat = headers.indexOf('stop_lat');
    final iLon = headers.indexOf('stop_lon');
    if (iId < 0 || iName < 0 || iLat < 0 || iLon < 0) {
      throw Exception('stops.txt missing required columns');
    }

    final out = <String, Stop>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= iLon) continue;
      final id = r[iId].toString();
      final name = r[iName].toString();
      final lat = double.tryParse(r[iLat].toString());
      final lon = double.tryParse(r[iLon].toString());
      if (id.isEmpty || name.isEmpty || lat == null || lon == null) continue;
      out[id] = Stop(id: id, name: name, lat: lat, lon: lon);
    }
    return out;
  }

  static Future<TripsIndex> parseTripsFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('trips.txt');
    if (entry == null) {
      throw Exception('trips.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content);
    final rows = const CsvDecoder(dynamicTyping: false).convert(csvText);
    if (rows.isEmpty) return <String, TripInfo>{};

    final headers = rows.first.cast<String>();
    final iTripId = headers.indexOf('trip_id');
    final iRouteId = headers.indexOf('route_id');
    final iHeadsign = headers.indexOf('trip_headsign');
    if (iTripId < 0 || iRouteId < 0) {
      throw Exception('trips.txt missing required columns');
    }

    final out = <String, TripInfo>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= iTripId) continue;
      final tripId = r[iTripId].toString();
      final routeId = iRouteId < r.length ? r[iRouteId].toString() : '';
      if (tripId.isEmpty || routeId.isEmpty) continue;
      final headsign =
          (iHeadsign >= 0 && iHeadsign < r.length)
              ? r[iHeadsign].toString()
              : '';
      out[tripId] = TripInfo(
        tripId: tripId,
        routeId: routeId,
        headsign: headsign,
      );
    }
    return out;
  }

  static VehicleType _mapType(String code) {
    switch (code) {
      case '0':
        return VehicleType.tram;
      case '3':
        return VehicleType.bus;
      default:
        return VehicleType.unknown;
    }
  }
}

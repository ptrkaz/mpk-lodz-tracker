import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart' show CsvDecoder;
import 'package:http/http.dart' as http;
import '../../domain/models/line.dart';
import '../../domain/models/vehicle.dart';
import '../models/route_api_model.dart';

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

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/vehicle.dart';
import 'generated/gtfs-realtime.pb.dart';

class GtfsRtService {
  GtfsRtService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri vehiclePositionsUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/vehicle_positions.bin',
  );

  final http.Client _client;

  Future<List<Vehicle>> fetchVehiclePositions() async {
    final res = await _client.get(vehiclePositionsUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS-RT fetch failed: ${res.statusCode}');
    }
    return decode(res.bodyBytes);
  }

  static List<Vehicle> decode(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    final feed = FeedMessage.fromBuffer(Uint8List.fromList(bytes));
    final out = <Vehicle>[];
    for (final entity in feed.entity) {
      if (entity.id.isEmpty) continue;
      if (!entity.hasVehicle()) continue;
      final v = entity.vehicle;
      if (!v.hasPosition()) continue;
      final pos = v.position;
      if (!pos.hasLatitude() || !pos.hasLongitude()) continue;
      final routeId = v.hasTrip() ? v.trip.routeId : '';
      if (routeId.isEmpty) continue;
      out.add(Vehicle(
        id: entity.id,
        routeId: routeId,
        lat: pos.latitude,
        lon: pos.longitude,
        timestamp: v.hasTimestamp() ? v.timestamp.toInt() : 0,
        bearing: pos.hasBearing() ? pos.bearing : null,
        speed: pos.hasSpeed() ? pos.speed : null,
      ));
    }
    return out;
  }
}

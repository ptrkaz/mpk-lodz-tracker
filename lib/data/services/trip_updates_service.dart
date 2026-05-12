import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/trip_update.dart';
import 'generated/gtfs-realtime.pb.dart' as pb;

class TripUpdatesService {
  TripUpdatesService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri tripUpdatesUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/trip_updates.bin',
  );

  final http.Client _client;

  Future<List<TripUpdate>> fetchTripUpdates() async {
    final res = await _client.get(tripUpdatesUrl);
    if (res.statusCode != 200) {
      throw Exception('trip_updates fetch failed: ${res.statusCode}');
    }
    return decode(res.bodyBytes);
  }

  static List<TripUpdate> decode(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    final feed = pb.FeedMessage.fromBuffer(Uint8List.fromList(bytes));
    final out = <TripUpdate>[];
    for (final entity in feed.entity) {
      if (!entity.hasTripUpdate()) continue;
      final upd = entity.tripUpdate;
      final tripId = upd.hasTrip() ? upd.trip.tripId : '';
      final routeId = upd.hasTrip() && upd.trip.routeId.isNotEmpty
          ? upd.trip.routeId
          : null;
      if (tripId.isEmpty) continue;
      if (upd.stopTimeUpdate.isEmpty) continue;
      final stops = <StopTimeUpdate>[];
      for (final stu in upd.stopTimeUpdate) {
        if (stu.stopId.isEmpty) continue;
        int? eta;
        int? delay;
        if (stu.hasArrival()) {
          if (stu.arrival.hasTime()) eta = stu.arrival.time.toInt();
          if (stu.arrival.hasDelay()) delay = stu.arrival.delay;
        }
        stops.add(
          StopTimeUpdate(stopId: stu.stopId, etaUnixSec: eta, delaySec: delay),
        );
      }
      if (stops.isEmpty) continue;
      out.add(
        TripUpdate(
          tripId: tripId,
          routeId: routeId,
          delaySec: upd.hasDelay() ? upd.delay : null,
          stopTimeUpdates: stops,
        ),
      );
    }
    return out;
  }
}

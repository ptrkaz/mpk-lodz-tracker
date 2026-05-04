import '../../domain/models/departure.dart';
import '../../domain/models/line.dart';
import '../../domain/models/trip_info.dart';
import '../../domain/models/vehicle.dart';
import 'trip_updates_repository.dart';

class DeparturesRepository {
  DeparturesRepository({
    required TripUpdatesRepository tripUpdates,
    required TripsIndex trips,
    required RoutesIndex routes,
  })  : _tripUpdates = tripUpdates,
        _trips = trips,
        _routes = routes;

  final TripUpdatesRepository _tripUpdates;
  final TripsIndex _trips;
  final RoutesIndex _routes;

  static const int _maxResults = 10;

  List<Departure> forStop(
    String stopId, {
    required DateTime now,
    Set<String>? lineFilter,
  }) {
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final out = <Departure>[];

    for (final upd in _tripUpdates.byTripId.values) {
      final trip = _trips[upd.tripId];
      final routeId = trip?.routeId ?? '';
      if (lineFilter != null && lineFilter.isNotEmpty && !lineFilter.contains(routeId)) {
        continue;
      }
      for (final stu in upd.stopTimeUpdates) {
        if (stu.stopId != stopId) continue;
        if (stu.etaUnixSec == null) continue;
        if (stu.etaUnixSec! < nowSec) continue;
        final line = trip == null ? null : _routes[trip.routeId];
        out.add(Departure(
          lineNumber: line?.number ?? routeId,
          lineType: line?.type ?? VehicleType.unknown,
          headsign: trip?.headsign,
          etaUnixSec: stu.etaUnixSec!,
          delaySec: stu.delaySec ?? upd.delaySec,
        ));
      }
    }

    out.sort((a, b) => a.etaUnixSec.compareTo(b.etaUnixSec));
    if (out.length > _maxResults) {
      return out.sublist(0, _maxResults);
    }
    return out;
  }
}

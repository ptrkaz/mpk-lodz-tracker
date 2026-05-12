class TripUpdate {
  const TripUpdate({
    required this.tripId,
    this.routeId,
    this.delaySec,
    required this.stopTimeUpdates,
  });

  final String tripId;
  final String? routeId;
  final int? delaySec;
  final List<StopTimeUpdate> stopTimeUpdates;
}

class StopTimeUpdate {
  const StopTimeUpdate({required this.stopId, this.etaUnixSec, this.delaySec});

  final String stopId;
  final int? etaUnixSec;
  final int? delaySec;
}

typedef TripUpdatesIndex = Map<String, TripUpdate>;

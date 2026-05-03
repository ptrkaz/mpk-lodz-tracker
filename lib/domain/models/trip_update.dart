class TripUpdate {
  const TripUpdate({
    required this.tripId,
    required this.delaySec,
    required this.stopTimeUpdates,
  });

  final String tripId;
  final int? delaySec;
  final List<StopTimeUpdate> stopTimeUpdates;
}

class StopTimeUpdate {
  const StopTimeUpdate({
    required this.stopId,
    required this.etaUnixSec,
    required this.delaySec,
  });

  final String stopId;
  final int? etaUnixSec;
  final int? delaySec;
}

typedef TripUpdatesIndex = Map<String, TripUpdate>;

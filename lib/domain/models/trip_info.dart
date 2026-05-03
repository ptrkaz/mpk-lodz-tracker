class TripInfo {
  const TripInfo({
    required this.tripId,
    required this.routeId,
    required this.headsign,
  });

  final String tripId;
  final String routeId;
  final String headsign;
}

typedef TripsIndex = Map<String, TripInfo>;

import 'vehicle.dart';

class Line {
  const Line({
    required this.routeId,
    required this.number,
    required this.type,
  });

  final String routeId;
  final String number;
  final VehicleType type;
}

typedef RoutesIndex = Map<String, Line>;

Line resolveLine(String routeId, RoutesIndex index) {
  final found = index[routeId];
  if (found != null) return found;
  return Line(routeId: routeId, number: routeId, type: VehicleType.unknown);
}

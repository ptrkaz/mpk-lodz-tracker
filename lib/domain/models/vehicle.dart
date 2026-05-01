enum VehicleType { tram, bus, unknown }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.routeId,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.bearing,
    this.speed,
  });

  final String id;
  final String routeId;
  final double lat;
  final double lon;
  final int timestamp;
  final double? bearing;
  final double? speed;
}

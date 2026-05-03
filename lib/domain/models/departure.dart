import 'vehicle.dart';

class Departure {
  const Departure({
    required this.lineNumber,
    required this.lineType,
    this.headsign,
    required this.etaUnixSec,
    this.delaySec,
  });

  final String lineNumber;
  final VehicleType lineType;
  final String? headsign;
  final int etaUnixSec;
  final int? delaySec;
}

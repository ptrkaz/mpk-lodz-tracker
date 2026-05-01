import '../../domain/models/vehicle.dart';
import '../services/gtfs_rt_service.dart';

class VehiclesRepository {
  VehiclesRepository({required GtfsRtService service}) : _service = service;
  final GtfsRtService _service;

  Future<List<Vehicle>> fetchLatest() => _service.fetchVehiclePositions();
}

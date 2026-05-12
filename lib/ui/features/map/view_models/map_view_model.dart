import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../data/repositories/vehicles_repository.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/app_lifecycle_notifier.dart';
import '../../../core/lodz_constants.dart';

class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required VehiclesRepository repository,
    required AppLifecycleNotifier lifecycle,
  }) : _repo = repository,
       _lifecycle = lifecycle {
    _lifecycle.addListener(_onLifecycle);
  }

  final VehiclesRepository _repo;
  final AppLifecycleNotifier _lifecycle;
  Timer? _timer;
  bool _disposed = false;

  List<Vehicle> _vehicles = <Vehicle>[];
  DateTime? _lastUpdate;
  String? _selectedLineNumber;
  Set<String> _selectedRouteIds = const {};

  List<Vehicle> get vehicles => _vehicles;
  List<Vehicle> get visibleVehicles => _selectedRouteIds.isEmpty
      ? _vehicles
      : _vehicles.where((v) => _selectedRouteIds.contains(v.routeId)).toList();
  DateTime? get lastUpdate => _lastUpdate;
  String? get selectedLineNumber => _selectedLineNumber;
  Set<String> get selectedRouteIds => Set.unmodifiable(_selectedRouteIds);

  void selectVehicle(String vehicleId, {required RoutesIndex routes}) {
    final tapped = _vehicles.where((v) => v.id == vehicleId).firstOrNull;
    if (tapped == null) return;
    final line = resolveLine(tapped.routeId, routes);
    final routeIds = _vehicles
        .where((v) {
          final candidate = resolveLine(v.routeId, routes);
          return candidate.number == line.number && candidate.type == line.type;
        })
        .map((v) => v.routeId)
        .toSet();
    _selectedLineNumber = line.number;
    _selectedRouteIds = routeIds;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedLineNumber == null && _selectedRouteIds.isEmpty) return;
    _selectedLineNumber = null;
    _selectedRouteIds = const {};
    notifyListeners();
  }

  void _onLifecycle() {
    if (_lifecycle.isResumed) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_timer != null) return;
    refreshOnce();
    _timer = Timer.periodic(LodzConstants.pollInterval, (_) => refreshOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshOnce() async {
    try {
      final next = await _repo.fetchLatest();
      if (_disposed) return;
      _vehicles = next;
      _lastUpdate = DateTime.now();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[MapViewModel] poll failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _lifecycle.removeListener(_onLifecycle);
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../data/repositories/vehicles_repository.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/lodz_constants.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  MapViewModel({required VehiclesRepository repository}) : _repo = repository;

  final VehiclesRepository _repo;
  Timer? _timer;

  List<Vehicle> _vehicles = <Vehicle>[];
  DateTime? _lastUpdate;

  List<Vehicle> get vehicles => _vehicles;
  DateTime? get lastUpdate => _lastUpdate;

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
      _vehicles = next;
      _lastUpdate = DateTime.now();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[MapViewModel] poll failed: $e\n$st');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      stop();
    }
  }

  void attachLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detachLifecycle() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    stop();
    detachLifecycle();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../data/repositories/vehicles_repository.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/app_lifecycle_notifier.dart';
import '../../../core/lodz_constants.dart';

class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required VehiclesRepository repository,
    required AppLifecycleNotifier lifecycle,
  })  : _repo = repository,
        _lifecycle = lifecycle {
    _lifecycle.addListener(_onLifecycle);
  }

  final VehiclesRepository _repo;
  final AppLifecycleNotifier _lifecycle;
  Timer? _timer;
  bool _disposed = false;

  List<Vehicle> _vehicles = <Vehicle>[];
  DateTime? _lastUpdate;

  List<Vehicle> get vehicles => _vehicles;
  DateTime? get lastUpdate => _lastUpdate;

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

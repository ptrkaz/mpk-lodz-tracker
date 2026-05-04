import 'package:flutter/foundation.dart';
import '../../../../data/repositories/routes_repository.dart';
import '../../../../data/repositories/stops_repository.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/stop.dart';
import '../../../../domain/models/trip_info.dart';

class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel({
    required RoutesRepository repository,
    required StopsRepository stopsRepository,
    required Future<TripsIndex> Function() tripsLoader,
  })  : _repo = repository,
        _stopsRepo = stopsRepository,
        _tripsLoader = tripsLoader {
    _load();
  }

  final RoutesRepository _repo;
  final StopsRepository _stopsRepo;
  final Future<TripsIndex> Function() _tripsLoader;

  RoutesIndex _routes = const {};
  StopsIndex _stops = const {};
  TripsIndex _trips = const {};
  bool _ready = false;
  Object? _error;

  RoutesIndex get routes => _routes;
  StopsIndex get stops => _stops;
  TripsIndex get trips => _trips;
  bool get ready => _ready;
  Object? get error => _error;

  Future<void> _load() async {
    try {
      // Routes and stops are both required for the app to function.
      final results = await Future.wait([
        _repo.getRoutes(),
        _stopsRepo.getStops(),
      ]);
      _routes = results[0] as RoutesIndex;
      _stops = results[1] as StopsIndex;
    } catch (e, st) {
      debugPrint('[BootstrapViewModel] routes/stops load failed: $e\n$st');
      _error = e;
      notifyListeners();
      return;
    }

    // Trips are soft-optional: failure degrades to empty map without surfacing
    // an error to the UI.
    try {
      _trips = await _tripsLoader();
    } catch (e, st) {
      debugPrint('[BootstrapViewModel] trips load degraded: $e\n$st');
      _trips = const {};
    }

    _ready = true;
    notifyListeners();
  }
}

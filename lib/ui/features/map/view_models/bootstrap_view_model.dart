import 'package:flutter/foundation.dart';
import '../../../../data/repositories/routes_repository.dart';
import '../../../../data/repositories/stops_repository.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/route_shape.dart';
import '../../../../domain/models/stop.dart';
import '../../../../domain/models/trip_info.dart';

class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel({
    required RoutesRepository repository,
    required StopsRepository stopsRepository,
    required Future<TripsIndex> Function() tripsLoader,
  }) : _repo = repository,
       _tripsLoader = tripsLoader {
    _load();
  }

  final RoutesRepository _repo;
  final Future<TripsIndex> Function() _tripsLoader;

  RoutesIndex _routes = const {};
  StopsIndex _stops = const {};
  TripsIndex _trips = const {};
  RouteShapesIndex _routeShapes = const {};
  bool _ready = false;
  Object? _error;

  RoutesIndex get routes => _routes;
  StopsIndex get stops => _stops;
  TripsIndex get trips => _trips;
  RouteShapesIndex get routeShapes => _routeShapes;
  bool get ready => _ready;
  Object? get error => _error;

  Future<void> _load() async {
    try {
      // Routes and stops are both required for the app to function.
      final bundle = await _repo.getStaticBundle();
      _routes = bundle.routes;
      _stops = bundle.stops;
      _routeShapes = bundle.routeShapes;
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

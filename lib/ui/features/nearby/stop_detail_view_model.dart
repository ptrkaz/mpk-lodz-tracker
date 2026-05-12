import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/departures_repository.dart';
import '../../../data/repositories/trip_updates_repository.dart';
import '../../../domain/models/departure.dart';
import '../../../domain/models/stop.dart';
import '../../core/app_lifecycle_notifier.dart';
import '../../core/lodz_constants.dart';

typedef ActiveLineIds = Set<String> Function();

class StopDetailViewModel extends ChangeNotifier {
  StopDetailViewModel({
    required this.stop,
    required TripUpdatesRepository tripUpdates,
    required DeparturesRepository departures,
    required AppLifecycleNotifier lifecycle,
    required ActiveLineIds filterLines,
  }) : _tripUpdates = tripUpdates,
       _departures = departures,
       _lifecycle = lifecycle,
       _filterLines = filterLines {
    _lifecycle.addListener(_onLifecycle);
    _tripUpdates.addListener(_recompute);
    _start();
  }

  final Stop stop;
  final TripUpdatesRepository _tripUpdates;
  final DeparturesRepository _departures;
  final AppLifecycleNotifier _lifecycle;
  final ActiveLineIds _filterLines;

  Timer? _timer;
  bool _disposed = false;
  bool _loading = false;
  Object? _error;
  DateTime? _lastFetched;
  List<Departure> _departuresList = const [];

  bool get loading => _loading;
  Object? get error => _error;
  DateTime? get lastFetched => _lastFetched;
  List<Departure> get departures => _departuresList;

  Future<void> _start() async {
    _scheduleTimer();
    await _tick();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(LodzConstants.detailPollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_disposed || !_lifecycle.isResumed) return;
    _loading = true;
    notifyListeners();
    await _tripUpdates.refresh();
    if (_disposed) return;
    if (_tripUpdates.lastError == null) {
      _lastFetched = _tripUpdates.lastFetched;
      _error = null;
    } else {
      _error = _tripUpdates.byTripId.isEmpty ? _tripUpdates.lastError : null;
    }
    _loading = false;
    _recompute();
  }

  void _recompute() {
    if (_disposed) return;
    _departuresList = _departures.forStop(
      stop.id,
      now: DateTime.now(),
      lineFilter: _filterLines(),
    );
    notifyListeners();
  }

  void _onLifecycle() {
    if (_disposed) return;
    if (_lifecycle.isResumed) {
      _scheduleTimer();
      _tick();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle.removeListener(_onLifecycle);
    _tripUpdates.removeListener(_recompute);
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

import '../../domain/models/trip_update.dart';
import '../services/trip_updates_service.dart';

class TripUpdatesRepository extends ChangeNotifier {
  TripUpdatesRepository({required TripUpdatesService service})
    : _service = service;

  final TripUpdatesService _service;
  Map<String, TripUpdate> _byTripId = const {};
  Object? _lastError;
  DateTime? _lastFetched;

  Map<String, TripUpdate> get byTripId => _byTripId;
  Object? get lastError => _lastError;
  DateTime? get lastFetched => _lastFetched;

  Future<void> refresh() async {
    try {
      final list = await _service.fetchTripUpdates();
      _byTripId = {for (final u in list) u.tripId: u};
      _lastError = null;
      _lastFetched = DateTime.now();
      notifyListeners();
    } catch (e) {
      _lastError = e;
      // Retain prior snapshot; do not notify (no UI change).
    }
  }
}

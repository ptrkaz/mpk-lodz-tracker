import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/departures_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/stop_detail_view_model.dart';

class _CountingTripUpdates extends TripUpdatesRepository {
  _CountingTripUpdates() : super(service: TripUpdatesService());
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
    notifyListeners();
  }

  @override
  Map<String, TripUpdate> get byTripId => const {
        't1': TripUpdate(tripId: 't1', delaySec: 0, stopTimeUpdates: [
          StopTimeUpdate(stopId: 'S1', etaUnixSec: 9999999999, delaySec: 0),
        ]),
      };
}

void main() {
  test('immediate fetch on create + 5s polling', () {
    fakeAsync((async) {
      final tu = _CountingTripUpdates();
      final lifecycle = AppLifecycleNotifier();
      final vm = StopDetailViewModel(
        stop: const Stop(id: 'S1', name: 'A', lat: 0, lon: 0),
        tripUpdates: tu,
        departures: DeparturesRepository(
          tripUpdates: tu,
          trips: const {'t1': TripInfo(tripId: 't1', routeId: 'r1', headsign: 'X')},
          routes: const {'r1': Line(routeId: 'r1', number: '12', type: VehicleType.tram)},
        ),
        lifecycle: lifecycle,
        filterLines: () => const {},
      );
      async.elapse(const Duration(milliseconds: 1));
      expect(tu.refreshes, 1);
      async.elapse(const Duration(seconds: 5));
      expect(tu.refreshes, 2);
      vm.dispose();
    });
  });

  test('paused on background, resumes on foreground', () {
    fakeAsync((async) {
      final tu = _CountingTripUpdates();
      final lifecycle = AppLifecycleNotifier();
      final vm = StopDetailViewModel(
        stop: const Stop(id: 'S1', name: 'A', lat: 0, lon: 0),
        tripUpdates: tu,
        departures: DeparturesRepository(
          tripUpdates: tu,
          trips: const {},
          routes: const {},
        ),
        lifecycle: lifecycle,
        filterLines: () => const {},
      );
      async.elapse(const Duration(milliseconds: 1)); // first fetch
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      final beforePause = tu.refreshes;
      async.elapse(const Duration(seconds: 30));
      expect(tu.refreshes, beforePause); // no ticks while paused
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.elapse(const Duration(milliseconds: 1));
      expect(tu.refreshes, beforePause + 1);
      vm.dispose();
    });
  });
}

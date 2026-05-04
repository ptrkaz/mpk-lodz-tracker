import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/departures_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

class _StubTripUpdates extends TripUpdatesRepository {
  _StubTripUpdates(Map<String, TripUpdate> seed)
      : super(service: TripUpdatesService()) {
    _seed = seed;
  }
  late final Map<String, TripUpdate> _seed;
  @override
  Map<String, TripUpdate> get byTripId => _seed;
}

void main() {
  final routes = <String, Line>{
    'r12': const Line(routeId: 'r12', number: '12', type: VehicleType.tram),
    'r86': const Line(routeId: 'r86', number: '86', type: VehicleType.bus),
  };
  final trips = <String, TripInfo>{
    't1': const TripInfo(tripId: 't1', routeId: 'r12', headsign: 'Stoki'),
    't2': const TripInfo(tripId: 't2', routeId: 'r86', headsign: 'Manufaktura'),
  };
  final updates = <String, TripUpdate>{
    't1': const TripUpdate(tripId: 't1', delaySec: 60, stopTimeUpdates: [
      StopTimeUpdate(stopId: 'S1', etaUnixSec: 1000, delaySec: 60),
      StopTimeUpdate(stopId: 'S2', etaUnixSec: 1200, delaySec: 60),
    ]),
    't2': const TripUpdate(tripId: 't2', delaySec: 0, stopTimeUpdates: [
      StopTimeUpdate(stopId: 'S1', etaUnixSec: 800, delaySec: 0),
    ]),
  };

  test('returns sorted, future-only departures for a stop', () {
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(updates),
      trips: trips,
      routes: routes,
    );
    final out = repo.forStop(
      'S1',
      now: DateTime.fromMillisecondsSinceEpoch(900 * 1000),
    );
    expect(out.map((d) => d.lineNumber), ['12']);
  });

  test('applies line filter', () {
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(updates),
      trips: trips,
      routes: routes,
    );
    final out = repo.forStop(
      'S1',
      now: DateTime.fromMillisecondsSinceEpoch(0),
      lineFilter: {'r12'},
    );
    expect(out.map((d) => d.lineNumber), ['12']);
  });

  test('caps at 10 results', () {
    final big = <String, TripUpdate>{
      for (var i = 0; i < 20; i++)
        't$i': TripUpdate(
          tripId: 't$i',
          delaySec: 0,
          stopTimeUpdates: [
            StopTimeUpdate(stopId: 'S1', etaUnixSec: 1000 + i, delaySec: 0),
          ],
        ),
    };
    final allTrips = <String, TripInfo>{
      for (var i = 0; i < 20; i++)
        't$i': TripInfo(tripId: 't$i', routeId: 'r12', headsign: 'X'),
    };
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(big),
      trips: allTrips,
      routes: routes,
    );
    final out = repo.forStop('S1', now: DateTime.fromMillisecondsSinceEpoch(0));
    expect(out, hasLength(10));
  });
}

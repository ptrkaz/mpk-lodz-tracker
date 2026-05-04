import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';

class _FakeService extends TripUpdatesService {
  _FakeService();
  List<TripUpdate> next = const [];
  bool fail = false;
  int calls = 0;
  @override
  Future<List<TripUpdate>> fetchTripUpdates() async {
    calls++;
    if (fail) throw Exception('boom');
    return next;
  }
}

void main() {
  test('refresh swaps map and notifies listeners', () async {
    final svc = _FakeService();
    final repo = TripUpdatesRepository(service: svc);
    int notifications = 0;
    repo.addListener(() => notifications++);

    svc.next = const [
      TripUpdate(tripId: 't1', delaySec: 30, stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1, delaySec: 0),
      ]),
    ];
    await repo.refresh();
    expect(repo.byTripId.containsKey('t1'), isTrue);
    expect(notifications, 1);
  });

  test('refresh failure retains previous snapshot, no notification', () async {
    final svc = _FakeService();
    final repo = TripUpdatesRepository(service: svc);
    svc.next = const [
      TripUpdate(tripId: 't1', delaySec: 0, stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1, delaySec: 0),
      ]),
    ];
    await repo.refresh();
    int notifications = 0;
    repo.addListener(() => notifications++);

    svc.fail = true;
    await repo.refresh();
    expect(repo.byTripId.containsKey('t1'), isTrue);
    expect(notifications, 0);
    expect(repo.lastError, isNotNull);
  });
}

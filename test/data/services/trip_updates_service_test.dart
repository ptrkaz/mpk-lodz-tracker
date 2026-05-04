import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/generated/gtfs-realtime.pb.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';

FeedMessage _makeFeed({
  required String tripId,
  int? tripDelay,
  List<({String stopId, int? eta, int? delay})> stops = const [],
}) {
  final feed = FeedMessage()
    ..header = (FeedHeader()
      ..gtfsRealtimeVersion = '2.0'
      ..timestamp = Int64(0));
  final entity = FeedEntity()..id = 'e1';
  final upd = TripUpdate()..trip = (TripDescriptor()..tripId = tripId);
  if (tripDelay != null) upd.delay = tripDelay;
  for (final s in stops) {
    final stu = TripUpdate_StopTimeUpdate()..stopId = s.stopId;
    if (s.eta != null) stu.arrival = (TripUpdate_StopTimeEvent()..time = Int64(s.eta!));
    if (s.delay != null) {
      stu.arrival = (stu.arrival..delay = s.delay!);
    }
    upd.stopTimeUpdate.add(stu);
  }
  entity.tripUpdate = upd;
  feed.entity.add(entity);
  return feed;
}

void main() {
  test('decodes trip with delay and arrival.time', () {
    final feed = _makeFeed(
      tripId: 't1',
      tripDelay: 60,
      stops: [(stopId: 's1', eta: 1700000000, delay: 60)],
    );
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, hasLength(1));
    expect(out.first.tripId, 't1');
    expect(out.first.delaySec, 60);
    expect(out.first.stopTimeUpdates.first.etaUnixSec, 1700000000);
  });

  test('drops trips with empty stop_time_update', () {
    final feed = _makeFeed(tripId: 't1');
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, isEmpty);
  });

  test('handles missing arrival.time gracefully', () {
    final feed = _makeFeed(
      tripId: 't1',
      stops: [(stopId: 's1', eta: null, delay: null)],
    );
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, hasLength(1));
    expect(out.first.stopTimeUpdates.first.etaUnixSec, isNull);
  });
}

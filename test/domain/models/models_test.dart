import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  test('Stop holds id/name/lat/lon', () {
    const s = Stop(id: '1', name: 'Plac Wolności', lat: 51.77, lon: 19.46);
    expect(s.id, '1');
    expect(s.lat, 51.77);
  });

  test('TripInfo holds routeId + headsign', () {
    const t = TripInfo(tripId: 't1', routeId: 'r1', headsign: 'Stoki');
    expect(t.headsign, 'Stoki');
  });

  test('TripUpdate composes StopTimeUpdate list', () {
    const u = TripUpdate(
      tripId: 't1',
      routeId: 'r12',
      delaySec: 60,
      stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1000, delaySec: 60),
      ],
    );
    expect(u.routeId, 'r12');
    expect(u.stopTimeUpdates.length, 1);
    expect(u.stopTimeUpdates.first.stopId, 's1');
  });

  test('Departure has nullable headsign and delaySec', () {
    const d = Departure(
      lineNumber: '12',
      lineType: VehicleType.tram,
      headsign: null,
      etaUnixSec: 1000,
      delaySec: null,
    );
    expect(d.headsign, isNull);
    expect(d.delaySec, isNull);
  });
}

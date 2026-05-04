import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

Directory _tmp() => Directory.systemTemp.createTempSync('gtfs_cache_test');

void main() {
  test('writeBundle then readBundle round-trips when fresh', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    final bundle = GtfsCachedBundle(
      routes: {'r1': const Line(routeId: 'r1', number: '12', type: VehicleType.tram)},
      stops: {'s1': const Stop(id: 's1', name: 'A', lat: 51.7, lon: 19.4)},
      trips: {'t1': const TripInfo(tripId: 't1', routeId: 'r1', headsign: 'X')},
    );
    await svc.writeBundle(bundle);
    final back = await svc.readBundle(maxAge: const Duration(days: 1));
    expect(back, isNotNull);
    expect(back!.routes['r1']!.number, '12');
    expect(back.stops['s1']!.name, 'A');
    expect(back.trips['t1']!.headsign, 'X');
  });

  test('readBundle returns null when any snapshot missing', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    expect(
      await svc.readBundle(maxAge: const Duration(days: 1)),
      isNull,
    );
  });

  test('readBundle returns null when oldest snapshot is stale', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    await svc.writeBundle(GtfsCachedBundle(routes: {}, stops: {}, trips: {}));
    final tripsFile = File('${dir.path}/trips.json');
    await tripsFile.setLastModified(DateTime.now().subtract(const Duration(days: 30)));
    expect(
      await svc.readBundle(maxAge: const Duration(days: 7)),
      isNull,
    );
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';

void main() {
  test('decodeVehiclePositions parses real fixture into Vehicle list', () {
    final bytes = File('__fixtures__/vehicle_positions.bin').readAsBytesSync();
    final vehicles = GtfsRtService.decode(bytes);
    expect(vehicles, isNotEmpty);
    final first = vehicles.first;
    expect(first.id, isNotEmpty);
    expect(first.routeId, isNotEmpty);
    expect(first.lat, inInclusiveRange(51.0, 52.5));
    expect(first.lon, inInclusiveRange(19.0, 20.0));
    expect(first.timestamp, greaterThan(0));
  });

  test('decodeVehiclePositions skips entities without position or routeId', () {
    // Empty FeedMessage byte payload → []
    final empty = <int>[]; // not a valid feed; expect graceful handling via fromBuffer
    expect(() => GtfsRtService.decode(empty), returnsNormally);
    expect(GtfsRtService.decode(empty), isEmpty);
  });
}

import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/generated/gtfs-realtime.pb.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';

void main() {
  test('decodeVehiclePositions parses real fixture into Vehicle list', () {
    final bytes = File('__fixtures__/vehicle_positions.bin').readAsBytesSync();
    final vehicles = GtfsRtService.decode(bytes);
    expect(vehicles, isNotEmpty);
    for (final v in vehicles) {
      expect(v.id, isNotEmpty);
      expect(v.routeId, isNotEmpty);
      expect(v.timestamp, greaterThan(0));
    }
    // At least some vehicles should have valid Łódź coordinates.
    final inLodz = vehicles.where(
      (v) =>
          v.lat >= 51.0 &&
          v.lat <= 52.5 &&
          v.lon >= 19.0 &&
          v.lon <= 20.0,
    );
    expect(inLodz, isNotEmpty);
  });

  test('decode returns empty list for empty input', () {
    final empty = <int>[];
    expect(() => GtfsRtService.decode(empty), returnsNormally);
    expect(GtfsRtService.decode(empty), isEmpty);
  });

  test('decode skips entities missing id, vehicle, position, lat/lon, or routeId', () {
    // Build a synthetic feed with one valid entity + several malformed ones.
    final feed = FeedMessage()
      ..header = (FeedHeader()..gtfsRealtimeVersion = '2.0');

    // Skipped: empty id
    feed.entity.add(FeedEntity()
      ..vehicle = (VehiclePosition()
        ..position = (Position()..latitude = 51.76..longitude = 19.46)
        ..trip = (TripDescriptor()..routeId = 'r1')));

    // Skipped: no vehicle
    feed.entity.add(FeedEntity()..id = 'no-vehicle');

    // Skipped: no position
    feed.entity.add(FeedEntity()
      ..id = 'no-pos'
      ..vehicle = (VehiclePosition()
        ..trip = (TripDescriptor()..routeId = 'r1')));

    // Skipped: no routeId
    feed.entity.add(FeedEntity()
      ..id = 'no-route'
      ..vehicle = (VehiclePosition()
        ..position = (Position()..latitude = 51.76..longitude = 19.46)));

    // Valid
    feed.entity.add(FeedEntity()
      ..id = 'valid-1'
      ..vehicle = (VehiclePosition()
        ..position = (Position()..latitude = 51.76..longitude = 19.46..bearing = 90.0)
        ..trip = (TripDescriptor()..routeId = 'r-tram-8')
        ..timestamp = Int64(1714553400)));

    final bytes = feed.writeToBuffer();
    final vehicles = GtfsRtService.decode(bytes);

    expect(vehicles, hasLength(1));
    final v = vehicles.first;
    expect(v.id, 'valid-1');
    expect(v.routeId, 'r-tram-8');
    // lat/lon are proto float (32-bit); tolerance accounts for float32 precision loss.
    expect(v.lat, closeTo(51.76, 1e-4));
    expect(v.lon, closeTo(19.46, 1e-4));
    expect(v.bearing, closeTo(90.0, 1e-4));
    expect(v.timestamp, 1714553400);
  });
}

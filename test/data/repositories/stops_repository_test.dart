import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';

Position _pos(double lat, double lon) => Position(
  longitude: lon,
  latitude: lat,
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late StopsIndex idx;

  setUp(() {
    idx = {
      'a': const Stop(id: 'a', name: 'A', lat: 51.7600, lon: 19.4500),
      'b': const Stop(
        id: 'b',
        name: 'B',
        lat: 51.7610,
        lon: 19.4500,
      ), // ~111m N
      'c': const Stop(id: 'c', name: 'C', lat: 51.7700, lon: 19.4500), // ~1.1km
      'd': const Stop(id: 'd', name: 'D', lat: 51.7601, lon: 19.4501), // ~14m
    };
  });

  test('nearby sorts by ascending distance', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 500, limit: 10);
    expect(result.map((s) => s.id), ['a', 'd', 'b']);
  });

  test('nearby applies radius filter', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 50, limit: 10);
    expect(result.map((s) => s.id), ['a', 'd']);
  });

  test('nearby caps at limit', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 5000, limit: 2);
    expect(result, hasLength(2));
  });

  test('nearbyWithDistances sorts by ascending distance', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearbyWithDistances(
      _pos(51.7600, 19.4500),
      radiusM: 500,
      limit: 10,
    );
    expect(result.map((e) => e.stop.id), ['a', 'd', 'b']);
    // distances should be non-decreasing
    for (var i = 1; i < result.length; i++) {
      expect(
        result[i].distanceM,
        greaterThanOrEqualTo(result[i - 1].distanceM),
      );
    }
  });

  test('nearbyWithDistances distances are reasonable', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearbyWithDistances(
      _pos(51.7600, 19.4500),
      radiusM: 500,
      limit: 10,
    );
    final byId = {for (final e in result) e.stop.id: e.distanceM};
    // 'a' is at the query point — distance ~0
    expect(byId['a']!, lessThan(1.0));
    // 'd' is ~14m away
    expect(byId['d']!, closeTo(14, 3));
    // 'b' is ~111m away
    expect(byId['b']!, closeTo(111, 10));
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  late Directory tmp;
  late RoutesCacheService cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('routes_cache_test_');
    cache = RoutesCacheService(directoryProvider: () async => tmp);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('returns null when no cache file exists', () async {
    expect(await cache.read(maxAge: const Duration(days: 7)), isNull);
  });

  test('writes and reads back a routes index', () async {
    final idx = <String, Line>{
      'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
    };
    await cache.write(idx);
    final read = await cache.read(maxAge: const Duration(days: 7));
    expect(read, isNotNull);
    expect(read!['r1']!.number, '8');
    expect(read['r1']!.type, VehicleType.tram);
  });

  test('returns null when cache is older than TTL', () async {
    final idx = <String, Line>{
      'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
    };
    await cache.write(idx);
    final file = File('${tmp.path}/routes.json');
    final old = DateTime.now().subtract(const Duration(days: 10));
    await file.setLastModified(old);
    expect(await cache.read(maxAge: const Duration(days: 7)), isNull);
  });
}

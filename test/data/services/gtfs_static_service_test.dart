import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  test('parseRoutesFromZip extracts tram + bus from minimal fixture', () async {
    final bytes = File('__fixtures__/GTFS-mini.zip').readAsBytesSync();
    final index = await GtfsStaticService.parseRoutesFromZip(bytes);

    expect(index.length, 3);
    final tram = index.values.where((l) => l.type == VehicleType.tram).toList();
    final bus = index.values.where((l) => l.type == VehicleType.bus).toList();
    expect(tram.length, 2);
    expect(bus.length, 1);
    expect(tram.first.number, isNotEmpty);
  });

  test('parseRoutesFromZip throws when routes.txt missing', () async {
    expect(
      () => GtfsStaticService.parseRoutesFromZip(<int>[0x50, 0x4B, 0x05, 0x06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      throwsA(isA<Exception>()),
    );
  });
}

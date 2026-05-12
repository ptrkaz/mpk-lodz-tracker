import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

List<int> _zip(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((name, body) {
    final bytes = utf8.encode(body);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

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
      () => GtfsStaticService.parseRoutesFromZip(<int>[
        0x50,
        0x4B,
        0x05,
        0x06,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]),
      throwsA(isA<Exception>()),
    );
  });

  group('parseStopsFromZip', () {
    test('parses well-formed stops.txt', () async {
      final zip = _zip({
        'stops.txt':
            'stop_id,stop_name,stop_lat,stop_lon\n'
            '1,Plac Wolności,51.77,19.46\n'
            '2,Manufaktura,51.78,19.45\n',
      });
      final stops = await GtfsStaticService.parseStopsFromZip(zip);
      expect(stops.length, 2);
      expect(stops['1']!.name, 'Plac Wolności');
      expect(stops['2']!.lat, closeTo(51.78, 0.001));
    });

    test('skips rows with empty id, name, or unparseable coords', () async {
      final zip = _zip({
        'stops.txt':
            'stop_id,stop_name,stop_lat,stop_lon\n'
            ',Bad,51.77,19.46\n'
            '3,,51.77,19.46\n'
            '4,Ok,foo,bar\n'
            '5,Ok,51.77,19.46\n',
      });
      final stops = await GtfsStaticService.parseStopsFromZip(zip);
      expect(stops.keys, ['5']);
    });

    test('throws when stops.txt missing', () async {
      final zip = _zip({'other.txt': 'x'});
      expect(() => GtfsStaticService.parseStopsFromZip(zip), throwsException);
    });
  });

  group('parseTripsFromZip', () {
    test('parses trip_id, route_id, trip_headsign', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign\n'
            'r1,s1,t1,Stoki\n'
            'r2,s1,t2,Manufaktura\n',
      });
      final trips = await GtfsStaticService.parseTripsFromZip(zip);
      expect(trips.length, 2);
      expect(trips['t1']!.routeId, 'r1');
      expect(trips['t1']!.headsign, 'Stoki');
    });

    test('skips rows missing trip_id', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign\n'
            'r1,s1,,Stoki\n'
            'r1,s1,t2,Centrum\n',
      });
      final trips = await GtfsStaticService.parseTripsFromZip(zip);
      expect(trips.keys, ['t2']);
    });
  });

  group('parseRouteShapesFromZip', () {
    test('builds route shapes from trips and ordered shapes rows', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign,shape_id\n'
            'r1,s1,t1,Stoki,shape-a\n'
            'r2,s1,t2,Retkinia,shape-b\n',
        'shapes.txt':
            'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\n'
            'shape-a,51.760,19.450,2\n'
            'shape-a,51.750,19.440,1\n'
            'shape-b,51.770,19.460,1\n'
            'shape-b,51.780,19.470,2\n',
      });

      final shapes = await GtfsStaticService.parseRouteShapesFromZip(zip);

      expect(shapes.keys, containsAll(['r1', 'r2']));
      expect(shapes['r1']!.points.map((p) => p.lat), [51.750, 51.760]);
      expect(shapes['r1']!.points.map((p) => p.lon), [19.440, 19.450]);
    });

    test('skips shapes with fewer than two points', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign,shape_id\n'
            'r1,s1,t1,Stoki,shape-a\n',
        'shapes.txt':
            'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\n'
            'shape-a,51.760,19.450,1\n',
      });

      final shapes = await GtfsStaticService.parseRouteShapesFromZip(zip);

      expect(shapes, isEmpty);
    });
  });
}

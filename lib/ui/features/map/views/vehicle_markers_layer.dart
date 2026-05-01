import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class VehicleMarkersLayer {
  static const _sourceId = 'vehicles';
  static const _circleLayerId = 'vehicle-circles';
  static const _labelLayerId = 'vehicle-labels';

  final MapLibreMapController controller;
  bool _initialized = false;

  VehicleMarkersLayer(this.controller);

  Future<void> sync(List<Vehicle> vehicles, RoutesIndex routes) async {
    final fc = _toFeatureCollection(vehicles, routes);
    if (!_initialized) {
      await controller.addGeoJsonSource(_sourceId, fc);
      await controller.addCircleLayer(
        _sourceId,
        _circleLayerId,
        CircleLayerProperties(
          circleColor: [
            'match',
            ['get', 'type'],
            'tram',
            '#${kVehicleColors[VehicleType.tram]!.toARGB32().toRadixString(16).substring(2)}',
            'bus',
            '#${kVehicleColors[VehicleType.bus]!.toARGB32().toRadixString(16).substring(2)}',
            '#${kVehicleColors[VehicleType.unknown]!.toARGB32().toRadixString(16).substring(2)}',
          ],
          circleRadius: 14,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );
      await controller.addSymbolLayer(
        _sourceId,
        _labelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'number'],
          textSize: 11,
          textAllowOverlap: true,
          textColor: '#ffffff',
          textFont: ['Open Sans Bold'],
        ),
      );
      _initialized = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  Map<String, dynamic> _toFeatureCollection(
    List<Vehicle> vehicles,
    RoutesIndex routes,
  ) {
    final features = vehicles.map((v) {
      final line = resolveLine(v.routeId, routes);
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [v.lon, v.lat],
        },
        'properties': {
          'number': line.number,
          'type': line.type.name,
          'routeId': v.routeId,
        },
      };
    }).toList();
    final fc = {'type': 'FeatureCollection', 'features': features};
    // sanity: must round-trip JSON cleanly
    jsonEncode(fc);
    return fc;
  }
}

import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class VehicleMarkersLayer {
  static const _sourceId = 'vehicles';
  static const _circleLayerId = 'vehicle-circles';
  static const _circleStrokeLayerId = 'vehicle-circles-stroke';
  static const _labelLayerId = 'vehicle-labels';
  static const _bearingLayerId = 'vehicle-bearing';

  final MapLibreMapController controller;
  bool _initialized = false;

  VehicleMarkersLayer(this.controller);

  Future<void> sync(List<Vehicle> vehicles, RoutesIndex routes) async {
    final fc = _toFeatureCollection(vehicles, routes);
    if (!_initialized) {
      await controller.addGeoJsonSource(_sourceId, fc);

      // Background: white halo for separation from map.
      await controller.addCircleLayer(
        _sourceId,
        _circleStrokeLayerId,
        const CircleLayerProperties(
          circleColor: '#ffffff',
          circleRadius: 17,
        ),
      );

      // Foreground: colored circle keyed off vehicle type.
      await controller.addCircleLayer(
        _sourceId,
        _circleLayerId,
        CircleLayerProperties(
          circleColor: [
            'match',
            ['get', 'type'],
            'tram',
            _hexFor(VehicleType.tram),
            'bus',
            _hexFor(VehicleType.bus),
            _hexFor(VehicleType.unknown),
          ],
          circleRadius: 14,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );

      // Number label inside the circle. Tram (yellow) needs black text;
      // bus/unknown (magenta/gray) need white text.
      await controller.addSymbolLayer(
        _sourceId,
        _labelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'number'],
          textSize: 11,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textFont: ['Open Sans Bold'],
          textColor: [
            'match',
            ['get', 'type'],
            'tram',
            '#000000',
            '#ffffff',
          ],
        ),
      );

      // Bearing arrow — small navigation triangle anchored to the right of
      // the circle, rotated by `bearing`. Hidden when bearing is missing.
      await controller.addSymbolLayer(
        _sourceId,
        _bearingLayerId,
        const SymbolLayerProperties(
          textField: '▲',
          textSize: 12,
          textColor: '#1A1C1C',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.5,
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textRotate: ['get', 'bearing'],
          textOffset: [1.3, -1.3],
          textRotationAlignment: 'map',
        ),
        filter: ['has', 'bearing'],
      );

      _initialized = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  static String _hexFor(VehicleType t) {
    final argb = kVehicleColors[t]!.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Map<String, dynamic> _toFeatureCollection(
    List<Vehicle> vehicles,
    RoutesIndex routes,
  ) {
    final features = vehicles.map((v) {
      final line = resolveLine(v.routeId, routes);
      final props = <String, dynamic>{
        'number': line.number,
        'type': line.type.name,
        'routeId': v.routeId,
      };
      if (v.bearing != null) props['bearing'] = v.bearing;
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [v.lon, v.lat],
        },
        'properties': props,
      };
    }).toList();
    final fc = {'type': 'FeatureCollection', 'features': features};
    // sanity: must round-trip JSON cleanly
    jsonEncode(fc);
    return fc;
  }
}

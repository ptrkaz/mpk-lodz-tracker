import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/route_shape.dart';

class RouteShapeLayer {
  RouteShapeLayer(this.controller);

  static const _sourceId = 'selected-route-shapes';
  static const _haloLayerId = 'selected-route-shapes-halo';
  static const _lineLayerId = 'selected-route-shapes-line';

  final MapLibreMapController controller;
  bool _attached = false;

  Future<void> sync({
    required Set<String> selectedRouteIds,
    required RouteShapesIndex routeShapes,
  }) async {
    final fc = toFeatureCollection(
      selectedRouteIds: selectedRouteIds,
      routeShapes: routeShapes,
    );
    if (!_attached) {
      await controller.addSource(
        _sourceId,
        GeojsonSourceProperties(data: fc, lineMetrics: true),
      );
      await controller.addLineLayer(
        _sourceId,
        _haloLayerId,
        const LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 9,
          lineOpacity: 0.9,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: 'vehicle-circles-stroke',
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _sourceId,
        _lineLayerId,
        const LineLayerProperties(
          lineColor: '#06B6D4',
          lineWidth: 5,
          lineOpacity: 0.95,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        belowLayerId: 'vehicle-circles-stroke',
        enableInteraction: false,
      );
      _attached = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  static Map<String, dynamic> toFeatureCollection({
    required Set<String> selectedRouteIds,
    required RouteShapesIndex routeShapes,
  }) {
    final features = <Map<String, dynamic>>[];
    for (final routeId in selectedRouteIds) {
      final shape = routeShapes[routeId];
      if (shape == null || shape.points.length < 2) continue;
      features.add({
        'type': 'Feature',
        'id': routeId,
        'properties': {'routeId': routeId},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in shape.points) [p.lon, p.lat],
          ],
        },
      });
    }
    final fc = {'type': 'FeatureCollection', 'features': features};
    jsonEncode(fc);
    return fc;
  }
}

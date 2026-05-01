import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
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
  static const _clusterLayerId = 'vehicle-cluster';
  static const _clusterStrokeLayerId = 'vehicle-cluster-stroke';
  static const _clusterCountLayerId = 'vehicle-cluster-count';
  static const _arrowImageId = 'vehicle-bearing-arrow';

  // Cluster only when circles physically overlap. Marker visual radius is 17px
  // (stroke); points within ~28px merge into a single cluster bubble.
  static const _clusterRadius = 28.0;

  final MapLibreMapController controller;
  bool _initialized = false;

  VehicleMarkersLayer(this.controller);

  Future<void> sync(List<Vehicle> vehicles, RoutesIndex routes) async {
    final fc = _toFeatureCollection(vehicles, routes);
    if (!_initialized) {
      await controller.addImage(_arrowImageId, await _buildArrowBitmap());
      await controller.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: fc,
          cluster: true,
          clusterRadius: _clusterRadius,
        ),
      );

      // Filter for individual (unclustered) vehicles. Clusters get their own
      // layers below so their labels never collide with route numbers.
      final notCluster = ['!', ['has', 'point_count']];

      // Background: white halo for separation from map.
      await controller.addCircleLayer(
        _sourceId,
        _circleStrokeLayerId,
        const CircleLayerProperties(
          circleColor: '#ffffff',
          circleRadius: 17,
        ),
        filter: notCluster,
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
        filter: notCluster,
      );

      // Number label inside the circle. Tram (yellow) needs black text;
      // bus/unknown (magenta/gray) need white text. Overlap is allowed but
      // only individual (non-clustered) features reach this layer, so labels
      // can't smash together — clustering above already merged them.
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
        filter: notCluster,
      );

      // Bearing arrow — bitmap icon pinned to the leading edge of the circle,
      // rotated by `bearing`. Icon offset is rotated together with iconRotate
      // (rotation-alignment=map), so [0, -22] = 22px ahead of the anchor in
      // direction of travel. Hidden when bearing is missing or feature is a
      // cluster.
      await controller.addSymbolLayer(
        _sourceId,
        _bearingLayerId,
        const SymbolLayerProperties(
          iconImage: _arrowImageId,
          iconSize: 1.6,
          iconRotate: ['get', 'bearing'],
          iconOffset: [0, -18],
          iconRotationAlignment: 'map',
          iconPitchAlignment: 'map',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        filter: ['all', ['has', 'bearing'], notCluster],
      );

      // Cluster bubble — neutral dark surface so it reads as "multiple
      // vehicles" rather than belonging to tram/bus color family.
      const isCluster = ['has', 'point_count'];
      await controller.addCircleLayer(
        _sourceId,
        _clusterStrokeLayerId,
        const CircleLayerProperties(
          circleColor: '#ffffff',
          circleRadius: 19,
        ),
        filter: isCluster,
      );
      await controller.addCircleLayer(
        _sourceId,
        _clusterLayerId,
        const CircleLayerProperties(
          circleColor: '#1A1C1C',
          circleRadius: 16,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
        filter: isCluster,
      );
      await controller.addSymbolLayer(
        _sourceId,
        _clusterCountLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textSize: 12,
          textColor: '#ffffff',
          textFont: ['Open Sans Bold'],
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: isCluster,
      );

      _initialized = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  // Renders a small dark triangle (white outline) pointing up. Drawn once
  // and registered as a MapLibre image; iconRotate handles per-vehicle rotation.
  static Future<Uint8List> _buildArrowBitmap() async {
    const px = 36.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, px, px));
    final path = Path()
      ..moveTo(px / 2, 3)
      ..lineTo(px - 6, px - 6)
      ..lineTo(6, px - 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFF1A1C1C));
    final image = await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
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

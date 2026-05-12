import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/stop.dart';
import '../../../core/design_tokens.dart';

class StopMarkersLayer {
  StopMarkersLayer(this.controller);

  static const _sourceId = 'stops';
  static const _layerId = 'stop-circles';
  static const _selectedLayerId = 'stop-circles-selected';

  static bool isStopLayer(String layerId) =>
      layerId == _layerId || layerId == _selectedLayerId;

  static Stop? stopForFeatureTap({
    required String layerId,
    required String featureId,
    required List<Stop> stops,
  }) {
    if (!isStopLayer(layerId)) return null;
    for (final stop in stops) {
      if (stop.id == featureId) return stop;
    }
    return null;
  }

  final MapLibreMapController controller;
  bool _attached = false;

  Future<void> sync({required List<Stop> stops, String? selectedId}) async {
    final fc = {
      'type': 'FeatureCollection',
      'features': [
        for (final s in stops)
          {
            'type': 'Feature',
            'id': s.id,
            'properties': {'id': s.id, 'selected': s.id == selectedId ? 1 : 0},
            'geometry': {
              'type': 'Point',
              'coordinates': [s.lon, s.lat],
            },
          },
      ],
    };

    if (!_attached) {
      await controller.addSource(_sourceId, GeojsonSourceProperties(data: fc));
      await controller.addCircleLayer(
        _sourceId,
        _layerId,
        CircleLayerProperties(
          circleColor: _cyanHex,
          circleRadius: 6,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        filter: [
          '==',
          ['get', 'selected'],
          0,
        ],
      );
      await controller.addCircleLayer(
        _sourceId,
        _selectedLayerId,
        CircleLayerProperties(
          circleColor: _cyanHex,
          circleRadius: 12,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        filter: [
          '==',
          ['get', 'selected'],
          1,
        ],
      );
      _attached = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  Future<void> detach() async {
    if (!_attached) return;
    await controller.removeLayer(_layerId);
    await controller.removeLayer(_selectedLayerId);
    await controller.removeSource(_sourceId);
    _attached = false;
  }

  static String get _cyanHex {
    final argb = LodzColors.transitCyan.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

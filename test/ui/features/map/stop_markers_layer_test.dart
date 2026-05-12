import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/domain/models/route_shape.dart';
import 'package:mpk_lodz_tracker/ui/features/map/views/route_shape_layer.dart';
import 'package:mpk_lodz_tracker/ui/features/map/views/stop_markers_layer.dart';
import 'package:mpk_lodz_tracker/ui/features/map/views/vehicle_markers_layer.dart';

void main() {
  const stops = [
    Stop(id: 's1', name: 'Piotrkowska', lat: 51.76, lon: 19.45),
    Stop(id: 's2', name: 'Plac Wolnosci', lat: 51.77, lon: 19.46),
  ];

  test('stopForFeatureTap returns tapped stop for stop layers', () {
    final stop = StopMarkersLayer.stopForFeatureTap(
      layerId: 'stop-circles',
      featureId: 's2',
      stops: stops,
    );

    expect(stop?.id, 's2');
  });

  test('stopForFeatureTap ignores non-stop layers and unknown ids', () {
    expect(
      StopMarkersLayer.stopForFeatureTap(
        layerId: 'vehicle-circles',
        featureId: 's1',
        stops: stops,
      ),
      isNull,
    );
    expect(
      StopMarkersLayer.stopForFeatureTap(
        layerId: 'stop-circles-selected',
        featureId: 'missing',
        stops: stops,
      ),
      isNull,
    );
  });

  test(
    'vehicleIdForFeatureTap returns tapped vehicle id for vehicle layers',
    () {
      expect(
        VehicleMarkersLayer.vehicleIdForFeatureTap(
          layerId: 'vehicle-circles',
          featureId: 'v1',
          vehicles: const [
            Vehicle(
              id: 'v1',
              routeId: 'r1',
              lat: 51.7,
              lon: 19.4,
              timestamp: 1,
            ),
          ],
        ),
        'v1',
      );
    },
  );

  test('vehicleIdForFeatureTap ignores cluster layers and unknown ids', () {
    expect(
      VehicleMarkersLayer.vehicleIdForFeatureTap(
        layerId: 'vehicle-cluster',
        featureId: 'v1',
        vehicles: const [],
      ),
      isNull,
    );
    expect(
      VehicleMarkersLayer.vehicleIdForFeatureTap(
        layerId: 'vehicle-circles',
        featureId: 'missing',
        vehicles: const [],
      ),
      isNull,
    );
  });

  test(
    'route shape feature collection contains selected route coordinates',
    () {
      final fc = RouteShapeLayer.toFeatureCollection(
        selectedRouteIds: {'r1'},
        routeShapes: const {
          'r1': RouteShape(
            routeId: 'r1',
            points: [
              ShapePoint(lat: 51.7, lon: 19.4),
              ShapePoint(lat: 51.8, lon: 19.5),
            ],
          ),
        },
      );

      final features = fc['features']! as List<dynamic>;
      expect(features, hasLength(1));
      final geometry = features.single['geometry'] as Map<String, dynamic>;
      expect(geometry['type'], 'LineString');
      expect(geometry['coordinates'], [
        [19.4, 51.7],
        [19.5, 51.8],
      ]);
    },
  );
}

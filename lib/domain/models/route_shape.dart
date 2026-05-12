class ShapePoint {
  const ShapePoint({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

class RouteShape {
  const RouteShape({required this.routeId, required this.points, this.shapeId});

  final String routeId;
  final List<ShapePoint> points;
  final String? shapeId;
}

typedef RouteShapesIndex = Map<String, RouteShape>;

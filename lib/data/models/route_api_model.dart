class RouteApiModel {
  const RouteApiModel({
    required this.routeId,
    required this.shortName,
    required this.routeType,
  });

  factory RouteApiModel.fromCsvRow(Map<String, String> row) => RouteApiModel(
        routeId: row['route_id'] ?? '',
        shortName: row['route_short_name'] ?? '',
        routeType: row['route_type'] ?? '',
      );

  final String routeId;
  final String shortName;
  final String routeType;
}

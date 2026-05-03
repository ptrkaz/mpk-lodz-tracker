class LodzConstants {
  LodzConstants._();

  static const double centerLat = 51.7592;
  static const double centerLon = 19.456;
  static const double defaultZoom = 12;
  static const Duration pollInterval = Duration(seconds: 2);
  static const Duration routesCacheTtl = Duration(days: 7);

  // Nearby stops feature
  static const double nearbyRadiusM = 500;
  static const int nearbyLimit = 20;
  static const double walkingSpeedMps = 1.4;
  static const Duration detailPollInterval = Duration(seconds: 5);
  static const double sheetPeekFraction = 0.12;
  static const double sheetExpandedFraction = 0.7;
}

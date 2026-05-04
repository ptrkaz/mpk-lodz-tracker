import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/stops_repository.dart';
import '../../../domain/models/stop.dart';
import '../../../domain/models/vehicle.dart';
import '../../core/lodz_constants.dart';

enum LocationStatus { unknown, granted, denied, deniedForever, serviceDisabled }

enum SheetSnap { peek, expanded }

abstract class LocationGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<Position> positionStream({double distanceFilter = 25});
  Future<Position?> getLastKnown();
  Future<void> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Stream<Position> positionStream({double distanceFilter = 25}) =>
      Geolocator.getPositionStream(
        locationSettings:
            LocationSettings(distanceFilter: distanceFilter.toInt()),
      );
  @override
  Future<Position?> getLastKnown() => Geolocator.getLastKnownPosition();
  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

abstract class LastFixStore {
  Future<({double lat, double lon})?> read();
  Future<void> write(Position pos);
}

class PrefsLastFixStore implements LastFixStore {
  static const _key = 'nearby.lastFix';

  @override
  Future<({double lat, double lon})?> read() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return null;
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  @override
  Future<void> write(Position pos) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, '${pos.latitude},${pos.longitude}');
  }
}

class NearbyStopsViewModel extends ChangeNotifier {
  NearbyStopsViewModel({
    required StopsRepository stopsRepo,
    required LocationGateway location,
    required LastFixStore lastFixStore,
  })  : _stops = stopsRepo,
        _loc = location,
        _fixStore = lastFixStore;

  final StopsRepository _stops;
  final LocationGateway _loc;
  final LastFixStore _fixStore;

  LocationStatus _status = LocationStatus.unknown;
  Position? _lastFix;
  List<Stop> _nearby = const [];
  Stop? _selected;
  SheetSnap _snap = SheetSnap.peek;
  StreamSubscription<Position>? _sub;
  bool _disposed = false;
  Map<String, double> _distancesByStopId = const {};
  Map<String, List<({String number, VehicleType type})>> _linesByStopId =
      const {};

  LocationStatus get status => _status;
  Position? get lastFix => _lastFix;
  List<Stop> get nearby => _nearby;
  Stop? get selected => _selected;
  SheetSnap get snap => _snap;
  Map<String, double> get distancesByStopId => _distancesByStopId;
  Map<String, List<({String number, VehicleType type})>> get linesByStopId =>
      _linesByStopId;

  Future<void> init() async {
    final stored = await _fixStore.read();
    if (stored != null && _lastFix == null) {
      _lastFix = Position(
        latitude: stored.lat,
        longitude: stored.lon,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _recomputeNearby();
    }

    if (!await _loc.isLocationServiceEnabled()) {
      _setStatus(LocationStatus.serviceDisabled);
      return;
    }
    var perm = await _loc.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await _loc.requestPermission();
    }
    switch (perm) {
      case LocationPermission.denied:
        _setStatus(LocationStatus.denied);
        return;
      case LocationPermission.deniedForever:
        _setStatus(LocationStatus.deniedForever);
        return;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        _setStatus(LocationStatus.granted);
        await _stops.getStops();
        if (_disposed) return;
        _subscribe();
        break;
      case LocationPermission.unableToDetermine:
        _setStatus(LocationStatus.denied);
    }
  }

  Future<void> requestLocationPermission() async {
    if (_status == LocationStatus.serviceDisabled ||
        _status == LocationStatus.deniedForever) {
      await _loc.openAppSettings();
      return;
    }
    await init();
  }

  void selectStop(Stop s) {
    if (_selected?.id == s.id) return;
    _selected = s;
    notifyListeners();
  }

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  void setSnap(SheetSnap s) {
    if (_snap == s) return;
    _snap = s;
    notifyListeners();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _loc.positionStream().listen(
      (pos) {
        if (_disposed) return;
        _lastFix = pos;
        _fixStore.write(pos);
        _recomputeNearby();
      },
      onError: (_) {
        // Keep last fix; do not change status on transient errors.
      },
    );
  }

  void _recomputeNearby() {
    if (_disposed) return;
    final fix = _lastFix;
    if (fix == null) return;
    final results = _stops.nearbyWithDistances(
      fix,
      radiusM: LodzConstants.nearbyRadiusM,
      limit: LodzConstants.nearbyLimit,
    );
    _nearby = results.map((e) => e.stop).toList();
    _distancesByStopId = {for (final e in results) e.stop.id: e.distanceM};
    // Lines join requires stop_times.txt (not loaded in v1); leave empty.
    _linesByStopId = const {};
    notifyListeners();
  }

  void _setStatus(LocationStatus s) {
    if (_disposed) return;
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

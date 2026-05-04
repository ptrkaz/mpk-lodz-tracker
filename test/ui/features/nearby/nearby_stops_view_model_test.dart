import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';

class _FakeLocation implements LocationGateway {
  _FakeLocation({this.permission = LocationPermission.whileInUse});
  LocationPermission permission;
  bool serviceEnabled = true;
  final controller = StreamController<Position>.broadcast();
  Position? lastFix;
  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Stream<Position> positionStream({double distanceFilter = 25}) =>
      controller.stream;
  @override
  Future<Position?> getLastKnown() async => lastFix;
  @override
  Future<void> openAppSettings() async {}
}

class _NoopFixStore implements LastFixStore {
  @override
  Future<({double lat, double lon})?> read() async => null;
  @override
  Future<void> write(Position pos) async {}
}

Position _pos(double lat, double lon) => Position(
      longitude: lon, latitude: lat,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 0, altitude: 0, altitudeAccuracy: 0,
      heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
    );

void main() {
  final stops = <String, Stop>{
    'a': const Stop(id: 'a', name: 'A', lat: 51.760, lon: 19.450),
    'b': const Stop(id: 'b', name: 'B', lat: 51.761, lon: 19.450),
  };

  test('granted permission populates nearby on first fix', () {
    fakeAsync((async) {
      final loc = _FakeLocation();
      final vm = NearbyStopsViewModel(
        stopsRepo: StopsRepository.test(stops),
        location: loc,
        lastFixStore: _NoopFixStore(),
      );
      vm.init();
      async.elapse(const Duration(milliseconds: 1));
      loc.controller.add(_pos(51.760, 19.450));
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.status, LocationStatus.granted);
      expect(vm.nearby.first.id, 'a');
    });
  });

  test('denied permission produces denied status', () {
    fakeAsync((async) {
      final loc = _FakeLocation(permission: LocationPermission.denied);
      final vm = NearbyStopsViewModel(
        stopsRepo: StopsRepository.test(stops),
        location: loc,
        lastFixStore: _NoopFixStore(),
      );
      vm.init();
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.status, LocationStatus.denied);
    });
  });

  test('selectStop / clearSelection', () {
    final vm = NearbyStopsViewModel(
      stopsRepo: StopsRepository.test(stops),
      location: _FakeLocation(),
      lastFixStore: _NoopFixStore(),
    );
    vm.selectStop(const Stop(id: 'a', name: 'A', lat: 0, lon: 0));
    expect(vm.selected!.id, 'a');
    vm.clearSelection();
    expect(vm.selected, isNull);
  });

  test('init after dispose does not crash', () async {
    final vm = NearbyStopsViewModel(
      stopsRepo: StopsRepository.test(stops),
      location: _FakeLocation(),
      lastFixStore: _NoopFixStore(),
    );
    vm.dispose();
    await vm.init(); // must not throw
  });
}

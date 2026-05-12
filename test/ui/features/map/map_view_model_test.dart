import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';
import 'package:mpk_lodz_tracker/ui/core/lodz_constants.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';

class _MockVehiclesRepo extends Mock implements VehiclesRepository {}

void main() {
  late _MockVehiclesRepo repo;
  late AppLifecycleNotifier lifecycle;
  final v1 = const Vehicle(
    id: 'v1',
    routeId: 'r1',
    lat: 51.7,
    lon: 19.4,
    timestamp: 1,
  );

  setUp(() {
    repo = _MockVehiclesRepo();
    // Unattached notifier: no WidgetsBinding needed in unit tests.
    lifecycle = AppLifecycleNotifier();
  });

  MapViewModel makeVm() => MapViewModel(repository: repo, lifecycle: lifecycle);

  test('start() polls immediately and at the configured interval', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => [v1]);
      final vm = makeVm();
      vm.start();

      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      async.elapse(LodzConstants.pollInterval);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      vm.stop();
    });
  });

  test('replace updates vehicles and lastUpdate', () async {
    when(() => repo.fetchLatest()).thenAnswer((_) async => [v1]);
    final vm = makeVm();
    await vm.refreshOnce();
    expect(vm.vehicles, [v1]);
    expect(vm.lastUpdate, isNotNull);
  });

  test(
    'selectVehicle selects every visible vehicle sharing the tapped line number',
    () async {
      const sameLineA = Vehicle(
        id: 'a',
        routeId: 'route-8-a',
        lat: 51.7,
        lon: 19.4,
        timestamp: 1,
      );
      const sameLineB = Vehicle(
        id: 'b',
        routeId: 'route-8-b',
        lat: 51.8,
        lon: 19.5,
        timestamp: 1,
      );
      const other = Vehicle(
        id: 'c',
        routeId: 'route-12',
        lat: 51.9,
        lon: 19.6,
        timestamp: 1,
      );
      const sameNumberBus = Vehicle(
        id: 'd',
        routeId: 'route-bus-8',
        lat: 51.9,
        lon: 19.6,
        timestamp: 1,
      );
      when(
        () => repo.fetchLatest(),
      ).thenAnswer((_) async => [sameLineA, sameLineB, other, sameNumberBus]);
      final vm = makeVm();
      await vm.refreshOnce();

      vm.selectVehicle(
        sameLineA.id,
        routes: {
          'route-8-a': const Line(
            routeId: 'route-8-a',
            number: '8',
            type: VehicleType.tram,
          ),
          'route-8-b': const Line(
            routeId: 'route-8-b',
            number: '8',
            type: VehicleType.tram,
          ),
          'route-12': const Line(
            routeId: 'route-12',
            number: '12',
            type: VehicleType.tram,
          ),
          'route-bus-8': const Line(
            routeId: 'route-bus-8',
            number: '8',
            type: VehicleType.bus,
          ),
        },
      );

      expect(vm.selectedLineNumber, '8');
      expect(vm.selectedRouteIds, {'route-8-a', 'route-8-b'});
      expect(vm.visibleVehicles, [sameLineA, sameLineB]);
    },
  );

  test('stop() halts polling', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => const []);
      final vm = makeVm();
      vm.start();
      async.flushMicrotasks();
      vm.stop();
      async.elapse(LodzConstants.pollInterval * 3);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1); // only the initial tick
    });
  });

  test('start() is idempotent under repeated calls', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => const []);
      final vm = makeVm();
      vm.start();
      vm.start();
      vm.start();
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);
      vm.stop();
    });
  });

  test('lifecycle pause stops polling, resume restarts it', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => const []);
      final vm = makeVm();
      vm.start();
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(LodzConstants.pollInterval * 2);
      async.flushMicrotasks();
      verifyNever(() => repo.fetchLatest());

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      vm.stop();
    });
  });

  test('refreshOnce after dispose does not notify listeners', () async {
    final completer = Completer<List<Vehicle>>();
    when(() => repo.fetchLatest()).thenAnswer((_) => completer.future);
    final vm = makeVm();
    var notifications = 0;
    vm.addListener(() => notifications++);

    final pending = vm.refreshOnce();
    vm.dispose();
    completer.complete([v1]);
    await pending;

    expect(notifications, 0);
  });
}

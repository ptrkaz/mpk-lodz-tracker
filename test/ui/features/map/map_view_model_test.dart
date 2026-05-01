import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/lodz_constants.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';

class _MockVehiclesRepo extends Mock implements VehiclesRepository {}

void main() {
  late _MockVehiclesRepo repo;
  final v1 = const Vehicle(id: 'v1', routeId: 'r1', lat: 51.7, lon: 19.4, timestamp: 1);

  setUp(() {
    repo = _MockVehiclesRepo();
  });

  test('start() polls immediately and at the configured interval', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => [v1]);
      final vm = MapViewModel(repository: repo);
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
    final vm = MapViewModel(repository: repo);
    await vm.refreshOnce();
    expect(vm.vehicles, [v1]);
    expect(vm.lastUpdate, isNotNull);
  });

  test('stop() halts polling', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => const []);
      final vm = MapViewModel(repository: repo);
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
      final vm = MapViewModel(repository: repo);
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
      final vm = MapViewModel(repository: repo);
      vm.start();
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      vm.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(LodzConstants.pollInterval * 2);
      async.flushMicrotasks();
      verifyNever(() => repo.fetchLatest());

      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      vm.stop();
    });
  });

  test('refreshOnce after dispose does not notify listeners', () async {
    final completer = Completer<List<Vehicle>>();
    when(() => repo.fetchLatest()).thenAnswer((_) => completer.future);
    final vm = MapViewModel(repository: repo);
    var notifications = 0;
    vm.addListener(() => notifications++);

    final pending = vm.refreshOnce();
    vm.dispose();
    completer.complete([v1]);
    await pending;

    expect(notifications, 0);
  });
}

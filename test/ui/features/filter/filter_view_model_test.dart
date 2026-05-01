import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';

void main() {
  test('toggle adds and removes route ids', () {
    final vm = FilterViewModel();
    vm.toggle('r1');
    expect(vm.selectedRouteIds, {'r1'});
    vm.toggle('r2');
    expect(vm.selectedRouteIds, {'r1', 'r2'});
    vm.toggle('r1');
    expect(vm.selectedRouteIds, {'r2'});
  });

  test('clear empties selection', () {
    final vm = FilterViewModel();
    vm.toggle('r1');
    vm.clear();
    expect(vm.selectedRouteIds, isEmpty);
  });

  test('setTab updates active tab and notifies', () {
    final vm = FilterViewModel();
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.setTab(VehicleType.bus);
    expect(vm.activeTab, VehicleType.bus);
    expect(notifications, 1);
  });

  test('setQuery trims and lowercases', () {
    final vm = FilterViewModel();
    vm.setQuery('  8A  ');
    expect(vm.query, '8a');
  });
}

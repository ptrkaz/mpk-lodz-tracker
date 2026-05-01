import 'package:flutter/foundation.dart';
import '../../../../domain/models/vehicle.dart';

class FilterViewModel extends ChangeNotifier {
  Set<String> _selected = <String>{};
  VehicleType _tab = VehicleType.tram;
  String _query = '';

  Set<String> get selectedRouteIds => Set.unmodifiable(_selected);
  VehicleType get activeTab => _tab;
  String get query => _query;

  void toggle(String routeId) {
    if (_selected.contains(routeId)) {
      _selected.remove(routeId);
    } else {
      _selected.add(routeId);
    }
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected = <String>{};
    notifyListeners();
  }

  void setTab(VehicleType tab) {
    if (tab == _tab) return;
    if (tab == VehicleType.unknown) return; // tabs only model tram | bus
    _tab = tab;
    notifyListeners();
  }

  void setQuery(String raw) {
    final next = raw.trim().toLowerCase();
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }
}

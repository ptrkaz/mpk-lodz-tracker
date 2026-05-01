import 'package:flutter/foundation.dart';
import '../../../../data/repositories/routes_repository.dart';
import '../../../../domain/models/line.dart';

class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel({required RoutesRepository repository})
      : _repo = repository {
    _load();
  }

  final RoutesRepository _repo;
  RoutesIndex _routes = const {};
  bool _ready = false;

  RoutesIndex get routes => _routes;
  bool get ready => _ready;

  Future<void> _load() async {
    try {
      final idx = await _repo.getRoutes();
      _routes = idx;
      _ready = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[BootstrapViewModel] $e\n$st');
    }
  }
}

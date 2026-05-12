import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/stop.dart';

class FavoriteStopsRepository extends ChangeNotifier {
  FavoriteStopsRepository() : _memoryOnly = false;

  FavoriteStopsRepository.memory({List<Stop> initial = const []})
    : _favorites = List<Stop>.of(initial),
      _memoryOnly = true;

  static const _key = 'favoriteStops.v1';

  final bool _memoryOnly;
  List<Stop> _favorites = const [];
  bool _loaded = false;

  List<Stop> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(String stopId) => _favorites.any((s) => s.id == stopId);

  Future<void> load() async {
    if (_loaded || _memoryOnly) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _loaded = true;
      notifyListeners();
      return;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    _favorites = decoded.map((item) {
      final json = item as Map<String, dynamic>;
      return Stop(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );
    }).toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(Stop stop) async {
    final next = List<Stop>.of(_favorites);
    final index = next.indexWhere((s) => s.id == stop.id);
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.add(stop);
    }
    _favorites = next;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_memoryOnly) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([
        for (final s in _favorites)
          {'id': s.id, 'name': s.name, 'lat': s.lat, 'lon': s.lon},
      ]),
    );
  }
}

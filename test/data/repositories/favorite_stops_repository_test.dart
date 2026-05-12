import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/favorite_stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('toggle persists favorite stops in insertion order', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = FavoriteStopsRepository();
    const first = Stop(id: 's1', name: 'Piotrkowska', lat: 51.76, lon: 19.45);
    const second = Stop(
      id: 's2',
      name: 'Plac Wolnosci',
      lat: 51.77,
      lon: 19.46,
    );

    await repo.toggle(first);
    await repo.toggle(second);

    expect(repo.isFavorite('s1'), isTrue);
    expect(repo.favorites.map((s) => s.id), ['s1', 's2']);

    final reloaded = FavoriteStopsRepository();
    await reloaded.load();
    expect(reloaded.favorites.map((s) => s.name), [
      'Piotrkowska',
      'Plac Wolnosci',
    ]);
  });

  test('toggle removes an existing favorite', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = FavoriteStopsRepository();
    const stop = Stop(id: 's1', name: 'Piotrkowska', lat: 51.76, lon: 19.45);

    await repo.toggle(stop);
    await repo.toggle(stop);

    expect(repo.favorites, isEmpty);
    expect(repo.isFavorite('s1'), isFalse);
  });
}

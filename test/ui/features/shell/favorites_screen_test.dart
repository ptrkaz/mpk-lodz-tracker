import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/favorite_stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/favorites_screen.dart';
import 'package:provider/provider.dart';

Widget _wrap(
  FavoriteStopsRepository repo, {
  ValueChanged<Stop>? onSelectStop,
}) => ChangeNotifierProvider.value(
  value: repo,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pl'),
    home: FavoritesScreen(onSelectStop: onSelectStop),
  ),
);

void main() {
  testWidgets('renders saved favorite stops and dispatches selection', (
    tester,
  ) async {
    final repo = FavoriteStopsRepository.memory(
      initial: const [
        Stop(id: 's1', name: 'Piotrkowska Centrum', lat: 51.76, lon: 19.45),
      ],
    );
    Stop? selected;

    await tester.pumpWidget(
      _wrap(repo, onSelectStop: (stop) => selected = stop),
    );

    expect(find.text('Piotrkowska Centrum'), findsOneWidget);
    await tester.tap(find.text('Piotrkowska Centrum'));
    expect(selected?.id, 's1');
  });
}

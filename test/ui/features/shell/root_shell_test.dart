import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/favorites_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/lines_screen.dart';
import 'package:mpk_lodz_tracker/ui/features/shell/views/root_shell.dart';
import 'package:provider/provider.dart';

void main() {
  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => MapViewModel(
              repository: VehiclesRepository(service: GtfsRtService()),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BootstrapViewModel(
              repository: RoutesRepository(
                staticService: GtfsStaticService(),
                cacheService: RoutesCacheService(),
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_) => FilterViewModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  testWidgets('RootShell shows three nav destinations', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));
    await tester.pump();

    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.directions_transit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsWidgets);
  });

  testWidgets('Tapping Lines and Favorites swaps the screen', (tester) async {
    await tester.pumpWidget(wrap(const RootShell()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.directions_transit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(LinesScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });
}

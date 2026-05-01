import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/bootstrap_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/map/views/map_search_bar.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('MapSearchBar renders search field and tune button', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FilterViewModel()),
          ChangeNotifierProvider(
            create: (_) => BootstrapViewModel(
              repository: RoutesRepository(
                staticService: GtfsStaticService(),
                cacheService: RoutesCacheService(),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MapSearchBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/routes_repository.dart';
import 'data/repositories/vehicles_repository.dart';
import 'data/services/gtfs_rt_service.dart';
import 'data/services/gtfs_static_service.dart';
import 'data/services/routes_cache_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/filter/view_models/filter_view_model.dart';
import 'ui/features/map/view_models/bootstrap_view_model.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/map/views/map_screen.dart';

void main() {
  runApp(const MpkApp());
}

class MpkApp extends StatelessWidget {
  const MpkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final rtService = GtfsRtService();
    final staticService = GtfsStaticService();
    final cacheService = RoutesCacheService();
    final vehiclesRepo = VehiclesRepository(service: rtService);
    final routesRepo = RoutesRepository(
      staticService: staticService,
      cacheService: cacheService,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MapViewModel(repository: vehiclesRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => BootstrapViewModel(repository: routesRepo),
        ),
        ChangeNotifierProvider(create: (_) => FilterViewModel()),
      ],
      child: MaterialApp(
        title: 'MPK Łódź',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MapScreen(),
      ),
    );
  }
}

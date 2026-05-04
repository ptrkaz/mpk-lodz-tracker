import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/departures_repository.dart';
import 'data/repositories/routes_repository.dart';
import 'data/repositories/stops_repository.dart';
import 'data/repositories/trip_updates_repository.dart';
import 'data/repositories/vehicles_repository.dart';
import 'data/services/gtfs_cache_service.dart';
import 'data/services/gtfs_rt_service.dart';
import 'data/services/gtfs_static_service.dart';
import 'data/services/trip_updates_service.dart';
import 'domain/models/line.dart';
import 'domain/models/trip_info.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/app_lifecycle_notifier.dart';
import 'ui/core/app_theme.dart';
import 'ui/core/lodz_constants.dart';
import 'ui/features/filter/view_models/filter_view_model.dart';
import 'ui/features/map/view_models/bootstrap_view_model.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/nearby/nearby_stops_view_model.dart';
import 'ui/features/shell/views/root_shell.dart';

void main() {
  runApp(const MpkApp());
}

class MpkApp extends StatelessWidget {
  const MpkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final rtService = GtfsRtService();
    final staticService = GtfsStaticService();
    final cacheService = GtfsCacheService();
    final vehiclesRepo = VehiclesRepository(service: rtService);
    final routesRepo = RoutesRepository(
      staticService: staticService,
      cacheService: cacheService,
    );
    final stopsRepo = StopsRepository(
      staticService: staticService,
      cacheService: cacheService,
    );
    final tripUpdatesService = TripUpdatesService();
    final tripUpdatesRepo = TripUpdatesRepository(service: tripUpdatesService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => AppLifecycleNotifier()..attach(),
        ),
        ChangeNotifierProxyProvider<AppLifecycleNotifier, MapViewModel>(
          create: (ctx) => MapViewModel(
            repository: vehiclesRepo,
            lifecycle: ctx.read<AppLifecycleNotifier>(),
          ),
          update: (ctx, lifecycle, vm) => vm!,
        ),
        ChangeNotifierProvider(
          create: (_) => BootstrapViewModel(
            repository: routesRepo,
            stopsRepository: stopsRepo,
            tripsLoader: () async {
              final cached = await cacheService.readBundle(
                maxAge: LodzConstants.routesCacheTtl,
              );
              if (cached != null) return cached.trips;
              final fresh = await staticService.fetchAndParseAll();
              await cacheService.writeBundle(GtfsCachedBundle(
                routes: fresh.routes,
                stops: fresh.stops,
                trips: fresh.trips,
              ));
              return fresh.trips;
            },
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => tripUpdatesRepo,
        ),
        // DeparturesRepository is a plain object (not a ChangeNotifier) that
        // reads trips + routes from BootstrapViewModel once it is ready.
        // ProxyProvider rebuilds the repository whenever BootstrapViewModel
        // notifies (i.e. after bootstrap completes).
        ProxyProvider<BootstrapViewModel, DeparturesRepository>(
          update: (ctx, bootstrap, _) => DeparturesRepository(
            tripUpdates: tripUpdatesRepo,
            trips: bootstrap.trips.isEmpty
                ? const <String, TripInfo>{}
                : bootstrap.trips,
            routes: bootstrap.routes.isEmpty
                ? const <String, Line>{}
                : bootstrap.routes,
          ),
        ),
        ChangeNotifierProvider(create: (_) => FilterViewModel()),
        ChangeNotifierProvider<NearbyStopsViewModel>(
          lazy: false,
          create: (ctx) => NearbyStopsViewModel(
            stopsRepo: ctx.read<StopsRepository>(),
            location: GeolocatorGateway(),
            lastFixStore: PrefsLastFixStore(),
          )..init(),
        ),
      ],
      child: MaterialApp(
        title: 'MPK Łódź',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RootShell(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../view_models/bootstrap_view_model.dart';
import '../view_models/map_view_model.dart';
import 'last_update_hint.dart';
import 'locate_fab.dart';
import 'map_search_bar.dart';
import 'top_app_bar.dart';
import 'vehicle_markers_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static String get _styleUrl =>
      'https://api.maptiler.com/maps/streets/style.json?key=$_maptilerKey';

  MapLibreMapController? _ctrl;
  VehicleMarkersLayer? _layer;

  @override
  void initState() {
    super.initState();
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    mapVm.attachLifecycle();
    mapVm.start();
    mapVm.addListener(_syncLayer);
    bootVm.addListener(_syncLayer);
    filterVm.addListener(_syncLayer);
  }

  @override
  void dispose() {
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    mapVm.removeListener(_syncLayer);
    bootVm.removeListener(_syncLayer);
    filterVm.removeListener(_syncLayer);
    super.dispose();
  }

  Future<void> _syncLayer() async {
    final layer = _layer;
    if (layer == null) return;
    final mapVm = context.read<MapViewModel>();
    final bootVm = context.read<BootstrapViewModel>();
    final filterVm = context.read<FilterViewModel>();
    final selected = filterVm.selectedRouteIds;
    final visible = selected.isEmpty
        ? mapVm.vehicles
        : mapVm.vehicles.where((v) => selected.contains(v.routeId)).toList();
    await layer.sync(visible, bootVm.routes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map fills the whole stack; everything else floats over it.
        Positioned.fill(
          child: MapLibreMap(
            styleString: _styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(LodzConstants.centerLat, LodzConstants.centerLon),
              zoom: LodzConstants.defaultZoom,
            ),
            onMapCreated: (c) {
              _ctrl = c;
              _layer = VehicleMarkersLayer(c);
            },
            onStyleLoadedCallback: () => _syncLayer(),
          ),
        ),
        // Top app bar (translucent, docked).
        const Positioned(top: 0, left: 0, right: 0, child: LodzTopAppBar()),
        // Floating search bar tucked under the app bar.
        const Positioned(
          top: 88,
          left: 0,
          right: 0,
          child: MapSearchBar(),
        ),
        // Locate FAB — bottom-right.
        Positioned(
          right: LodzSpacing.edgeMargin,
          bottom: LodzSpacing.md,
          child: LocateFab(controllerProvider: () => _ctrl),
        ),
        // Last-update hint — bottom-left.
        const Positioned(
          left: LodzSpacing.edgeMargin,
          bottom: LodzSpacing.md,
          child: LastUpdateHint(),
        ),
      ],
    );
  }
}

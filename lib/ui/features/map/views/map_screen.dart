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

  // Saved in initState so dispose() can remove listeners without using context.
  late final MapViewModel _mapVm;
  late final BootstrapViewModel _bootVm;
  late final FilterViewModel _filterVm;

  @override
  void initState() {
    super.initState();
    _mapVm = context.read<MapViewModel>();
    _bootVm = context.read<BootstrapViewModel>();
    _filterVm = context.read<FilterViewModel>();
    _mapVm.attachLifecycle();
    _mapVm.start();
    _mapVm.addListener(_syncLayer);
    _bootVm.addListener(_syncLayer);
    _filterVm.addListener(_syncLayer);
  }

  @override
  void dispose() {
    _mapVm.removeListener(_syncLayer);
    _bootVm.removeListener(_syncLayer);
    _filterVm.removeListener(_syncLayer);
    super.dispose();
  }

  Future<void> _syncLayer() async {
    final layer = _layer;
    if (layer == null) return;
    final selected = _filterVm.selectedRouteIds;
    final visible = selected.isEmpty
        ? _mapVm.vehicles
        : _mapVm.vehicles.where((v) => selected.contains(v.routeId)).toList();
    await layer.sync(visible, _bootVm.routes);
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
        // Floating search bar — sits below the status bar via SafeArea.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: LodzSpacing.sm),
              child: MapSearchBar(),
            ),
          ),
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

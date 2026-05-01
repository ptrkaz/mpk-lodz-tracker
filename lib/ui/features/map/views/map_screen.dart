import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../view_models/bootstrap_view_model.dart';
import '../view_models/map_view_model.dart';
import 'filter_chip_button.dart';
import 'last_update_hint.dart';
import 'locate_fab.dart';
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
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
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
          const FilterChipButton(),
          LocateFab(controllerProvider: () => _ctrl),
          const LastUpdateHint(),
        ],
      ),
    );
  }
}

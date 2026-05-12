import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../../nearby/nearby_stops_view_model.dart';
import '../../nearby/nearby_stops_sheet.dart';
import '../view_models/bootstrap_view_model.dart';
import '../view_models/map_view_model.dart';
import 'last_update_hint.dart';
import 'locate_fab.dart';
import 'map_search_bar.dart';
import 'route_shape_layer.dart';
import 'stop_markers_layer.dart';
import 'vehicle_markers_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _maptilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );
  static String get _styleUrl =>
      'https://api.maptiler.com/maps/streets/style.json?key=$_maptilerKey';

  MapLibreMapController? _ctrl;
  VehicleMarkersLayer? _vehicleLayer;
  RouteShapeLayer? _routeShapeLayer;
  StopMarkersLayer? _stopsLayer;

  // Saved in initState so dispose() can remove listeners without using context.
  late final MapViewModel _mapVm;
  late final BootstrapViewModel _bootVm;
  late final FilterViewModel _filterVm;
  late final NearbyStopsViewModel _nearbyVm;

  @override
  void initState() {
    super.initState();
    _mapVm = context.read<MapViewModel>();
    _bootVm = context.read<BootstrapViewModel>();
    _filterVm = context.read<FilterViewModel>();
    _nearbyVm = context.read<NearbyStopsViewModel>();
    _mapVm.start();
    _mapVm.addListener(_syncVehicleLayer);
    _bootVm.addListener(_syncVehicleLayer);
    _filterVm.addListener(_onFilterChanged);
    _nearbyVm.addListener(_syncStopsLayer);
  }

  @override
  void dispose() {
    _mapVm.removeListener(_syncVehicleLayer);
    _bootVm.removeListener(_syncVehicleLayer);
    _filterVm.removeListener(_onFilterChanged);
    _nearbyVm.removeListener(_syncStopsLayer);
    _ctrl?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  Future<void> _syncVehicleLayer() async {
    final layer = _vehicleLayer;
    if (layer == null) return;
    final selected = _filterVm.selectedRouteIds;
    final mapSelected = _mapVm.selectedRouteIds;
    final activeSelected = mapSelected.isNotEmpty ? mapSelected : selected;
    final visible = activeSelected.isEmpty
        ? _mapVm.vehicles
        : _mapVm.vehicles
              .where((v) => activeSelected.contains(v.routeId))
              .toList();
    await layer.sync(visible, _bootVm.routes);
    await _syncRouteShapeLayer();
  }

  void _onFilterChanged() {
    if (_mapVm.selectedRouteIds.isNotEmpty) {
      _mapVm.clearSelection();
    } else {
      _syncVehicleLayer();
    }
  }

  Future<void> _syncRouteShapeLayer() async {
    final layer = _routeShapeLayer;
    if (layer == null) return;
    await layer.sync(
      selectedRouteIds: _mapVm.selectedRouteIds,
      routeShapes: _bootVm.routeShapes,
    );
  }

  Future<void> _syncStopsLayer() async {
    if (mounted) setState(() {});
    final layer = _stopsLayer;
    if (layer == null) return;
    await _syncMapInsets();
    if (_nearbyVm.snap == SheetSnap.expanded) {
      await layer.sync(
        stops: _nearbyVm.nearby,
        selectedId: _nearbyVm.selected?.id,
      );
    } else {
      await layer.detach();
    }
  }

  void _onMapCreated(MapLibreMapController c) {
    _ctrl = c;
    _vehicleLayer = VehicleMarkersLayer(c);
    _routeShapeLayer = RouteShapeLayer(c);
    _stopsLayer = StopMarkersLayer(c);
    c.onFeatureTapped.add(_onFeatureTapped);
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    final stop = StopMarkersLayer.stopForFeatureTap(
      layerId: layerId,
      featureId: id,
      stops: _nearbyVm.nearby,
    );
    if (stop != null) _nearbyVm.selectStop(stop);
    final vehicleId = VehicleMarkersLayer.vehicleIdForFeatureTap(
      layerId: layerId,
      featureId: id,
      vehicles: _mapVm.vehicles,
    );
    if (vehicleId != null) {
      _mapVm.selectVehicle(vehicleId, routes: _bootVm.routes);
    }
  }

  Future<void> _syncMapInsets() async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    await ctrl.updateContentInsets(
      EdgeInsets.only(bottom: _cameraBottomPadding(context)),
      true,
    );
  }

  /// Bottom padding for the map camera when the sheet is expanded, so that
  /// the map content centre appears above the sheet.
  double _cameraBottomPadding(BuildContext context) {
    if (_nearbyVm.snap != SheetSnap.expanded) return 0;
    return MediaQuery.sizeOf(context).height *
        LodzConstants.sheetExpandedFraction;
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
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: () {
              _syncVehicleLayer();
              _syncStopsLayer();
            },
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
        // Nearby stops bottom sheet — Positioned.fill so the
        // DraggableScrollableSheet can anchor itself at the bottom.
        const Positioned.fill(child: NearbyStopsSheet()),
        // Locate FAB — bottom-right, above the visible sheet.
        Positioned(
          right: LodzSpacing.edgeMargin,
          bottom: _cameraBottomPadding(context) + LodzSpacing.md,
          child: LocateFab(controllerProvider: () => _ctrl),
        ),
        // Last-update hint — bottom-left, above the visible sheet.
        Positioned(
          left: LodzSpacing.edgeMargin,
          bottom: _cameraBottomPadding(context) + LodzSpacing.md,
          child: const LastUpdateHint(),
        ),
      ],
    );
  }
}

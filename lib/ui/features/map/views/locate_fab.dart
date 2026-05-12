import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../nearby/nearby_stops_view_model.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({super.key, required this.controllerProvider});

  final MapLibreMapController? Function() controllerProvider;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NearbyStopsViewModel>();

    // Hide the FAB when location access is not possible.
    if (vm.status == LocationStatus.denied ||
        vm.status == LocationStatus.deniedForever ||
        vm.status == LocationStatus.serviceDisabled) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LodzRadius.full),
        onTap: () => _onTap(context, vm),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surfaceContainerHighest),
            boxShadow: LodzShadows.level2,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.my_location, color: LodzColors.transitCyan),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, NearbyStopsViewModel vm) async {
    final fix = vm.lastFix;
    if (fix == null) {
      // No fix yet — request permission / start location services.
      await vm.requestLocationPermission();
      return;
    }

    final ctrl = controllerProvider();
    if (ctrl == null) return;

    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(fix.latitude, fix.longitude), 14),
      duration: const Duration(milliseconds: 600),
    );
  }
}

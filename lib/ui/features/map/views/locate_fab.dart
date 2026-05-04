import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../../core/design_tokens.dart';
import '../../nearby/nearby_stops_view_model.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({
    super.key,
    required this.controllerProvider,
    this.cameraBottomPadding,
  });

  final MapLibreMapController? Function() controllerProvider;

  /// Optional callback returning the bottom edge inset (in logical pixels) to
  /// apply when animating the camera — e.g. to keep the user's position above
  /// the nearby-stops sheet.
  final double Function()? cameraBottomPadding;

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

    final bottomPad = cameraBottomPadding?.call() ?? 0.0;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(fix.latitude, fix.longitude), 14),
      duration: const Duration(milliseconds: 600),
    );

    // Apply camera padding after the animation so that the target point
    // appears above the sheet when it is expanded.
    // NOTE: MapLibre Flutter binding (maplibre_gl ^0.21) does not expose a
    // CameraUpdate.padding constructor; we approximate by shifting the camera
    // upward by half the sheet height when the sheet is expanded.
    if (bottomPad > 0) {
      // Re-animate with the shifted target so the pin sits in the visible area.
      final shiftedTarget = LatLng(
        fix.latitude - _latDegreesForPixels(bottomPad / 2, 14),
        fix.longitude,
      );
      await ctrl.animateCamera(
        CameraUpdate.newLatLng(shiftedTarget),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  /// Rough conversion: how many degrees latitude correspond to [pixels] at the
  /// given [zoom] level (Web Mercator, 256-px tiles).
  static double _latDegreesForPixels(double pixels, double zoom) {
    final metersPerPixel = 156543.03392 / (1 << zoom.toInt());
    final meters = pixels * metersPerPixel;
    return meters / 111320.0;
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/design_tokens.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({super.key, required this.controllerProvider});

  final MapLibreMapController? Function() controllerProvider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LodzRadius.full),
        onTap: () => _onTap(context),
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

  Future<void> _onTap(BuildContext context) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final ctrl = controllerProvider();
    if (ctrl == null) return;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14),
      duration: const Duration(milliseconds: 600),
    );
  }
}

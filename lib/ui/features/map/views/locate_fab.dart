import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({super.key, required this.controllerProvider});

  final MapLibreMapController? Function() controllerProvider;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'locate',
        onPressed: () => _onTap(context),
        child: const Icon(Icons.my_location),
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

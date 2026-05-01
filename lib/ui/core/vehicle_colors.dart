import 'package:flutter/material.dart';

import '../../domain/models/vehicle.dart';
import 'design_tokens.dart';

/// Łódź CMYK transit accents — tram = yellow, bus = magenta. Cyan is reserved
/// for interactive states elsewhere; the unknown bucket uses the neutral
/// outline shade so it never competes with the live transit accents.
const Map<VehicleType, Color> kVehicleColors = {
  VehicleType.tram: LodzColors.transitTram,
  VehicleType.bus: LodzColors.transitBus,
  VehicleType.unknown: LodzColors.outline,
};

Color colorFor(VehicleType type) => kVehicleColors[type]!;

/// Foreground color to render on top of [kVehicleColors] backgrounds. Yellow
/// needs black text for contrast; magenta needs white.
const Map<VehicleType, Color> kVehicleOnColors = {
  VehicleType.tram: Color(0xFF000000),
  VehicleType.bus: Color(0xFFFFFFFF),
  VehicleType.unknown: Color(0xFFFFFFFF),
};

Color onColorFor(VehicleType type) => kVehicleOnColors[type]!;

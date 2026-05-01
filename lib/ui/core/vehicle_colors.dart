import 'package:flutter/material.dart';
import '../../domain/models/vehicle.dart';

const Map<VehicleType, Color> kVehicleColors = {
  VehicleType.tram: Color(0xFFE74C3C),
  VehicleType.bus: Color(0xFF2E86DE),
  VehicleType.unknown: Color(0xFF7F8C8D),
};

Color colorFor(VehicleType type) => kVehicleColors[type]!;

import 'package:flutter/material.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class LineChip extends StatelessWidget {
  const LineChip({
    super.key,
    required this.number,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const ValueKey('line-chip-container'),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          number,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

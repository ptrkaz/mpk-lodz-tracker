import 'package:flutter/material.dart';

import '../../../../domain/models/vehicle.dart';
import '../../../core/design_tokens.dart';
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
    final accent = colorFor(type);
    final onAccent = onColorFor(type);
    final scheme = Theme.of(context).colorScheme;

    final bg = selected ? accent : scheme.surfaceContainerLowest;
    final fg = selected ? onAccent : scheme.onSurface;
    final borderColor = selected ? accent : scheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LodzRadius.full),
      child: Container(
        key: const ValueKey('line-chip-container'),
        margin: const EdgeInsets.only(right: LodzSpacing.sm, bottom: LodzSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.stackGap,
          vertical: LodzSpacing.xs + 2,
        ),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(LodzRadius.full),
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

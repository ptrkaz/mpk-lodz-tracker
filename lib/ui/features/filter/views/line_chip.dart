import 'package:flutter/material.dart';

import '../../../../domain/models/vehicle.dart';
import '../../../core/design_tokens.dart';
import '../../../core/vehicle_colors.dart';

enum LineChipSize { regular, dense }

class LineChip extends StatelessWidget {
  const LineChip({
    super.key,
    required this.number,
    required this.type,
    required this.selected,
    required this.onTap,
    this.size = LineChipSize.regular,
  });

  final String number;
  final VehicleType type;
  final bool selected;
  final VoidCallback? onTap;
  final LineChipSize size;

  double get _vertical => size == LineChipSize.dense ? 2 : 6;
  double get _horizontal => size == LineChipSize.dense ? 8 : 12;
  double get _fontSize => size == LineChipSize.dense ? 11 : 14;
  double get _minHeight => size == LineChipSize.dense ? 24 : 32;

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
        margin: const EdgeInsets.only(
          right: LodzSpacing.sm,
          bottom: LodzSpacing.sm,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: _horizontal,
          vertical: _vertical,
        ),
        constraints: BoxConstraints(minWidth: 44, minHeight: _minHeight),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(LodzRadius.full),
        ),
        child: Text(
          number,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

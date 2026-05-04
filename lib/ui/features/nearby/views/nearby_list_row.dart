import 'package:flutter/material.dart';

import '../../../../domain/models/stop.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/views/line_chip.dart';

class NearbyListRow extends StatelessWidget {
  const NearbyListRow({
    super.key,
    required this.stop,
    required this.lineNumbers,
    required this.lineTypes,
    required this.distanceM,
    required this.onTap,
  });

  final Stop stop;
  final List<String> lineNumbers;
  final List<VehicleType> lineTypes;
  final double distanceM;
  final VoidCallback onTap;

  int get _walkMinutes {
    final secs = distanceM / LodzConstants.walkingSpeedMps;
    final m = (secs / 60).ceil();
    return m < 1 ? 1 : m;
  }

  String _distanceLabel(AppLocalizations l) {
    final n = (distanceM / 10).round() * 10;
    return l.metersAway(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.md,
          vertical: LodzSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: LodzSpacing.xs),
                  Wrap(
                    spacing: LodzSpacing.xs,
                    runSpacing: LodzSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < lineNumbers.length; i++)
                        LineChip(
                          number: lineNumbers[i],
                          type: lineTypes[i],
                          selected: true,
                          onTap: null,
                          size: LineChipSize.dense,
                        ),
                      Text(
                        '•  ${l.walkMinutes(_walkMinutes)}  •  ${_distanceLabel(l)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LodzColors.outline),
          ],
        ),
      ),
    );
  }
}

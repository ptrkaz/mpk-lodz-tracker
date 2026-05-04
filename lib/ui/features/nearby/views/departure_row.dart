import 'package:flutter/material.dart';

import '../../../../domain/models/departure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../../filter/views/line_chip.dart';

class DepartureRow extends StatelessWidget {
  const DepartureRow({
    super.key,
    required this.departure,
    required this.now,
  });

  final Departure departure;
  final DateTime now;

  String _eta() {
    final eta = DateTime.fromMillisecondsSinceEpoch(departure.etaUnixSec * 1000);
    final diffSec = eta.difference(now).inSeconds;
    final diffMin = (diffSec / 60).round();
    if (diffMin < 60) return '$diffMin min';
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final delay = departure.delaySec;
    final delayMins = delay == null ? 0 : (delay.abs() / 60).round();
    Widget? delayBadge;
    if (delay != null && delay.abs() >= 60) {
      final isLate = delay > 0;
      delayBadge = Text(
        isLate ? l.delayLate(delayMins) : l.delayEarly(delayMins),
        style: TextStyle(
          color: isLate
              ? Theme.of(context).colorScheme.error
              : LodzColors.success,
          fontSize: 12,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LodzSpacing.md,
        vertical: LodzSpacing.sm,
      ),
      child: Row(
        children: [
          LineChip(
            number: departure.lineNumber,
            type: departure.lineType,
            selected: true,
            onTap: null,
            size: LineChipSize.dense,
          ),
          const SizedBox(width: LodzSpacing.md),
          Expanded(
            child: Text(
              departure.headsign ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_eta(), style: Theme.of(context).textTheme.titleMedium),
              ?delayBadge,
            ],
          ),
        ],
      ),
    );
  }
}

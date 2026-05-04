import 'package:flutter/material.dart';

import '../../../../domain/models/stop.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../widgets/sheet_handle.dart';
import 'nearby_list_row.dart';

typedef LineDescriptor = ({String number, VehicleType type});

class NearbyListView extends StatelessWidget {
  const NearbyListView({
    super.key,
    required this.stops,
    required this.linesByStopId,
    required this.distancesByStopId,
    required this.onTapStop,
  });

  final List<Stop> stops;
  final Map<String, List<LineDescriptor>> linesByStopId;
  final Map<String, double> distancesByStopId;
  final ValueChanged<Stop> onTapStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LodzSpacing.md, vertical: LodzSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.nearbyStopsCount(stops.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        Expanded(
          child: stops.isEmpty
              ? Center(child: Text(l.nearbyEmptyNoStops))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: stops.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: LodzColors.outlineVariant),
                  itemBuilder: (_, i) {
                    final s = stops[i];
                    final lines = linesByStopId[s.id] ?? const [];
                    return NearbyListRow(
                      stop: s,
                      lineNumbers: [for (final l in lines) l.number],
                      lineTypes: [for (final l in lines) l.type],
                      distanceM: distancesByStopId[s.id] ?? 0,
                      onTap: () => onTapStop(s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

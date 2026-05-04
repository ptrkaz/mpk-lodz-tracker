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
    this.scrollController,
  });

  final List<Stop> stops;
  final Map<String, List<LineDescriptor>> linesByStopId;
  final Map<String, double> distancesByStopId;
  final ValueChanged<Stop> onTapStop;

  /// When provided (e.g. from [DraggableScrollableSheet]), this controller is
  /// forwarded to the inner [ListView] so the draggable sheet controls
  /// scrolling. When null the [ListView] manages its own scroll.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final header = Column(
      mainAxisSize: MainAxisSize.min,
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
      ],
    );

    if (stops.isEmpty) {
      // Use a single-item ListView so the scrollController (if provided)
      // is still honoured and layout stays bounded.
      return ListView(
        controller: scrollController,
        shrinkWrap: scrollController == null,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(LodzSpacing.lg),
            child: Center(child: Text(l.nearbyEmptyNoStops)),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      shrinkWrap: scrollController == null,
      padding: EdgeInsets.zero,
      itemCount: stops.length + 1, // +1 for header
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox.shrink() : const Divider(height: 1, color: LodzColors.outlineVariant),
      itemBuilder: (_, i) {
        if (i == 0) return header;
        final s = stops[i - 1];
        final lines = linesByStopId[s.id] ?? const [];
        return NearbyListRow(
          stop: s,
          lineNumbers: [for (final l in lines) l.number],
          lineTypes: [for (final l in lines) l.type],
          distanceM: distancesByStopId[s.id] ?? 0,
          onTap: () => onTapStop(s),
        );
      },
    );
  }
}

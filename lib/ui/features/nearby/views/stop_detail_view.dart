import 'package:flutter/material.dart';

import '../../../../domain/models/departure.dart';
import '../../../../domain/models/stop.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../widgets/sheet_handle.dart';
import 'departure_row.dart';

class StopDetailView extends StatelessWidget {
  const StopDetailView({
    super.key,
    required this.stop,
    required this.departures,
    required this.lastFetched,
    required this.now,
    required this.onBack,
  });

  final Stop stop;
  final List<Departure> departures;
  final DateTime? lastFetched;
  final DateTime now;
  final VoidCallback onBack;

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LodzSpacing.sm, vertical: LodzSpacing.xs,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: Theme.of(context).textTheme.titleLarge),
                    if (lastFetched != null)
                      Text(
                        l.lastUpdatedAt(_hhmmss(lastFetched!)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: LodzColors.outlineVariant),
        if (departures.isEmpty)
          Padding(
            padding: const EdgeInsets.all(LodzSpacing.lg),
            child: Center(child: Text(l.nearbyEmptyNoDepartures)),
          )
        else
          for (final d in departures) DepartureRow(departure: d, now: now),
      ],
    );
  }
}

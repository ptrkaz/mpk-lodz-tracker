import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../../filter/views/filter_sheet.dart';

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCount = context.watch<FilterViewModel>().selectedRouteIds.length;
    final l10n = AppLocalizations.of(context);
    final label = selectedCount == 0
        ? l10n.filterChipAll
        : l10n.filterChipSome(selectedCount);

    return Positioned(
      top: 60,
      left: 12,
      right: 12,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => FilterSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

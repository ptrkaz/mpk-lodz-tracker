import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../filter/views/filter_sheet.dart';

/// Floating top-overlay search bar that doubles as the entry point to the
/// existing line-filter sheet. The text field is read-only on tap (it opens
/// the sheet, where the real search lives) and the trailing tune button opens
/// the same sheet directly.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.edgeMargin),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(LodzRadius.full),
          border: Border.all(color: scheme.surfaceContainerHighest),
          boxShadow: LodzShadows.level1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.md),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: LodzSpacing.stackGap),
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () => FilterSheet.show(context),
                decoration: InputDecoration(
                  hintText: l10n.searchPlaceholder,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: LodzSpacing.sm),
            _TuneButton(onTap: () => FilterSheet.show(context)),
          ],
        ),
      ),
    );
  }
}

class _TuneButton extends StatelessWidget {
  const _TuneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(LodzRadius.full),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.tune, color: scheme.onSurface),
      ),
    );
  }
}

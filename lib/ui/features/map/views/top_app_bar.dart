import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';

/// Translucent top app bar matching the Stitch design — menu icon on the
/// left, app title, settings icon on the right. Drawn over the map; the
/// white-with-90%-alpha background lets the map ghost through.
class LodzTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LodzTopAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: scheme.surfaceContainerHighest),
        ),
        boxShadow: LodzShadows.level1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.md),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.menu, color: scheme.onSurfaceVariant),
            const SizedBox(width: LodzSpacing.md),
            Text(
              l10n.appTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const Spacer(),
            Icon(Icons.settings, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

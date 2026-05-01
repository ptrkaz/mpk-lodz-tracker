import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(LodzSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_border,
                    size: 64, color: LodzColors.outline),
                const SizedBox(height: LodzSpacing.md),
                Text(
                  l10n.navFavorites,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: LodzSpacing.xs),
                Text(
                  l10n.screenComingSoon,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LodzColors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

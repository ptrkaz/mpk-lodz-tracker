import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../map/views/top_app_bar.dart';

class LinesScreen extends StatelessWidget {
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: const LodzTopAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(LodzSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_transit,
                size: 64,
                color: LodzColors.outline,
              ),
              const SizedBox(height: LodzSpacing.md),
              Text(
                l10n.navLines,
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
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../nearby_stops_view_model.dart';

class PermissionCtaView extends StatelessWidget {
  const PermissionCtaView({
    super.key,
    required this.status,
    required this.onGrant,
    required this.onOpenSettings,
  });

  final LocationStatus status;
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isService = status == LocationStatus.serviceDisabled;
    final isPermanent = status == LocationStatus.deniedForever;
    final title = isService
        ? l.permissionCtaTitleService
        : l.permissionCtaTitleDenied;
    final useSettings = isService || isPermanent;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LodzSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 48,
              color: LodzColors.onSurfaceVariant,
            ),
            const SizedBox(height: LodzSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LodzSpacing.lg),
            FilledButton(
              onPressed: useSettings ? onOpenSettings : onGrant,
              child: Text(
                useSettings
                    ? l.permissionCtaButtonSettings
                    : l.permissionCtaButtonGrant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

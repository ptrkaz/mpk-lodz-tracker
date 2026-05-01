import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../view_models/map_view_model.dart';

class LastUpdateHint extends StatefulWidget {
  const LastUpdateHint({super.key});

  @override
  State<LastUpdateHint> createState() => _LastUpdateHintState();
}

class _LastUpdateHintState extends State<LastUpdateHint> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = context.watch<MapViewModel>().lastUpdate;
    if (last == null) return const SizedBox.shrink();
    final ageSec = DateTime.now().difference(last).inSeconds.clamp(0, 99999);
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: 12,
      bottom: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            l10n.mapLastUpdate(ageSec),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

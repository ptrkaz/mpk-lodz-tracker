import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../map/view_models/bootstrap_view_model.dart';
import '../view_models/filter_view_model.dart';
import 'line_chip.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.6,
        child: FilterSheet(),
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: context.read<FilterViewModel>().query,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          context.watch<BootstrapViewModel>(),
          context.watch<FilterViewModel>(),
        ]),
        builder: (context, _) {
          final boot = context.read<BootstrapViewModel>();
          final filter = context.read<FilterViewModel>();
          final lines = _filterLines(boot.routes, filter);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.filterTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.filterSearchPlaceholder,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: filter.setQuery,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TabButton(
                    label: l10n.filterTabTram,
                    active: filter.activeTab == VehicleType.tram,
                    onTap: () => filter.setTab(VehicleType.tram),
                  ),
                  _TabButton(
                    label: l10n.filterTabBus,
                    active: filter.activeTab == VehicleType.bus,
                    onTap: () => filter.setTab(VehicleType.bus),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    children: [
                      for (final l in lines)
                        LineChip(
                          number: l.number,
                          type: l.type,
                          selected: filter.selectedRouteIds.contains(l.routeId),
                          onTap: () => filter.toggle(l.routeId),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: filter.clear,
                    child: Text(l10n.filterClear),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.filterApply),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Line> _filterLines(RoutesIndex index, FilterViewModel f) {
    final all = index.values.where((l) => l.type == f.activeTab).toList();
    final filtered = f.query.isEmpty
        ? all
        : all.where((l) => l.number.toLowerCase().contains(f.query)).toList();
    filtered.sort((a, b) => _compareNatural(a.number, b.number));
    return filtered;
  }

  int _compareNatural(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';

import '../../../core/design_tokens.dart';
import '../../map/views/map_screen.dart';
import 'favorites_screen.dart';
import 'lines_screen.dart';

/// Top-level app shell. Hosts the bottom nav and the three tab screens.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = <Widget>[
    MapScreen(),
    LinesScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _LodzBottomNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        labels: [l10n.navMap, l10n.navLines, l10n.navFavorites],
      ),
    );
  }
}

class _LodzBottomNav extends StatelessWidget {
  const _LodzBottomNav({
    required this.index,
    required this.onSelect,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LodzRadius.xl),
        ),
        border: Border(top: BorderSide(color: scheme.surfaceContainerHighest)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // ~4% black
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                active: index == 0,
                icon: Icons.map_outlined,
                activeIcon: Icons.map_outlined,
                label: labels[0],
                onTap: () => onSelect(0),
              ),
              _NavItem(
                active: index == 1,
                icon: Icons.directions_transit_outlined,
                activeIcon: Icons.directions_transit,
                label: labels[1],
                onTap: () => onSelect(1),
              ),
              _NavItem(
                active: index == 2,
                icon: Icons.star_border,
                activeIcon: Icons.star,
                label: labels[2],
                onTap: () => onSelect(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? LodzColors.transitCyan : scheme.outline;
    final bg = active ? LodzColors.cyanSurface : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LodzRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LodzRadius.xl),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.lg,
          vertical: LodzSpacing.xs,
        ),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color),
            const SizedBox(height: LodzSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/departures_repository.dart';
import '../../../data/repositories/favorite_stops_repository.dart';
import '../../../data/repositories/trip_updates_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/app_lifecycle_notifier.dart';
import '../../core/design_tokens.dart';
import '../../core/lodz_constants.dart';
import '../filter/view_models/filter_view_model.dart';
import 'nearby_stops_view_model.dart';
import 'stop_detail_view_model.dart';
import 'views/nearby_list_view.dart';
import 'views/permission_cta_view.dart';
import 'views/stop_detail_view.dart';
import 'widgets/sheet_handle.dart';

class NearbyStopsSheet extends StatefulWidget {
  const NearbyStopsSheet({super.key});

  @override
  State<NearbyStopsSheet> createState() => _NearbyStopsSheetState();
}

class _NearbyStopsSheetState extends State<NearbyStopsSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _drivingController = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSizeChange(NearbyStopsViewModel vm) {
    if (_drivingController) return;
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final mid =
        (LodzConstants.sheetPeekFraction +
            LodzConstants.sheetExpandedFraction) /
        2;
    final next = size > mid ? SheetSnap.expanded : SheetSnap.peek;
    vm.setSnap(next);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NearbyStopsViewModel>(
      builder: (ctx, vm, _) {
        // Auto-snap to expanded when CTA is required.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_controller.isAttached) return;
          final isCta =
              vm.status == LocationStatus.denied ||
              vm.status == LocationStatus.deniedForever ||
              vm.status == LocationStatus.serviceDisabled;
          if (isCta && vm.snap == SheetSnap.peek) {
            _animateTo(LodzConstants.sheetExpandedFraction);
          } else if (!isCta &&
              vm.snap == SheetSnap.peek &&
              _controller.size != LodzConstants.sheetPeekFraction) {
            _animateTo(LodzConstants.sheetPeekFraction);
          }
        });

        return DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: LodzConstants.sheetPeekFraction,
          minChildSize: LodzConstants.sheetPeekFraction,
          maxChildSize: LodzConstants.sheetExpandedFraction,
          snap: true,
          snapSizes: [
            LodzConstants.sheetPeekFraction,
            LodzConstants.sheetExpandedFraction,
          ],
          builder: (ctx, scrollCtl) {
            return NotificationListener<DraggableScrollableNotification>(
              onNotification: (_) {
                _onSizeChange(vm);
                return false;
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: LodzColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(LodzRadius.sheet),
                    topRight: Radius.circular(LodzRadius.sheet),
                  ),
                  boxShadow: LodzShadows.sheet,
                ),
                child: _contentWithScroll(ctx, vm, scrollCtl),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _animateTo(double size) async {
    _drivingController = true;
    try {
      await _controller.animateTo(
        size,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } finally {
      _drivingController = false;
    }
  }

  /// Builds the sheet content, forwarding [scrollCtl] to list-type content and
  /// wrapping non-scrollable content in a [SingleChildScrollView].
  Widget _contentWithScroll(
    BuildContext context,
    NearbyStopsViewModel vm,
    ScrollController scrollCtl,
  ) {
    if (vm.status == LocationStatus.denied ||
        vm.status == LocationStatus.deniedForever ||
        vm.status == LocationStatus.serviceDisabled) {
      return KeyedSubtree(
        key: const ValueKey('cta'),
        child: SingleChildScrollView(
          controller: scrollCtl,
          child: PermissionCtaView(
            status: vm.status,
            onGrant: vm.requestLocationPermission,
            onOpenSettings: vm.requestLocationPermission,
          ),
        ),
      );
    }

    if (vm.selected != null) {
      return KeyedSubtree(
        key: ValueKey('detail-${vm.selected!.id}'),
        child: ChangeNotifierProvider<StopDetailViewModel>(
          create: (ctx) => StopDetailViewModel(
            stop: vm.selected!,
            tripUpdates: ctx.read<TripUpdatesRepository>(),
            departures: ctx.read<DeparturesRepository>(),
            lifecycle: ctx.read<AppLifecycleNotifier>(),
            filterLines: () => ctx.read<FilterViewModel>().activeRouteIds,
          ),
          child: Consumer<StopDetailViewModel>(
            builder: (ctx, dvm, _) => Consumer<FavoriteStopsRepository>(
              builder: (ctx, favorites, _) => SingleChildScrollView(
                controller: scrollCtl,
                child: StopDetailView(
                  stop: vm.selected!,
                  departures: dvm.departures,
                  lastFetched: dvm.lastFetched,
                  now: DateTime.now(),
                  onBack: vm.clearSelection,
                  isFavorite: favorites.isFavorite(vm.selected!.id),
                  onToggleFavorite: () => favorites.toggle(vm.selected!),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final l = AppLocalizations.of(context);
    if (vm.status == LocationStatus.unknown) {
      return KeyedSubtree(
        key: const ValueKey('checking-location'),
        child: SingleChildScrollView(
          controller: scrollCtl,
          child: _SheetStatusMessage(message: l.nearbyCheckingLocation),
        ),
      );
    }

    if (vm.status == LocationStatus.granted && vm.lastFix == null) {
      return KeyedSubtree(
        key: const ValueKey('waiting-for-gps'),
        child: SingleChildScrollView(
          controller: scrollCtl,
          child: _SheetStatusMessage(message: l.nearbyWaitingForGps),
        ),
      );
    }

    // NearbyListView is a ListView; pass scrollCtl directly so the
    // DraggableScrollableSheet drives it.
    return KeyedSubtree(
      key: const ValueKey('nearby-list'),
      child: NearbyListView(
        stops: vm.nearby,
        linesByStopId: vm.linesByStopId,
        distancesByStopId: vm.distancesByStopId,
        onTapStop: vm.selectStop,
        scrollController: scrollCtl,
      ),
    );
  }
}

class _SheetStatusMessage extends StatelessWidget {
  const _SheetStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LodzSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LodzSpacing.lg),
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LodzColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

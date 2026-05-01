# Nearby Stops — Design

Date: 2026-05-02

## Summary

Add a persistent draggable bottom sheet to the Map screen that shows stops near the device, plus a per-stop detail view with live departures (line, headsign, ETA, delay). The sheet is anchored to the device's GPS — panning the map does not change the list. Tapping a stop swaps the sheet content to the detail view; the back arrow returns to the list. While the detail view is open, the trip-updates feed is polled at 5 s; otherwise the existing 10 s map tick is unchanged. The nearby-20 stops also render as dots on the map while the sheet is expanded.

## Goals

- Persistent peek state always visible on the Map tab; expanded state shows up to 20 nearest stops within 500 m, sorted by distance.
- Per-stop detail view with the next 10 upcoming departures, refreshed every 5 s.
- Headsigns shown alongside line number so direction is unambiguous.
- Reuse existing repository / cache / lifecycle patterns. No backend.

## Non-goals

- Marker-tap callout for vehicles (separate concern).
- Full static timetable view (`stop_times.txt`, 153 MB) — out of scope; rely on `trip_updates.bin` absolute `arrival.time`.
- Deep-linking to a stop URL — sheet uses in-place navigation, not a route.
- Stops rendered as map markers when the sheet is collapsed.
- Favorites / saved stops — Favorites tab stays a stub.

## UX decisions (resolved during brainstorming)

| # | Decision | Choice |
|---|---|---|
| Q1 | Entry point | Persistent draggable sheet on Map tab |
| Q2 | "Nearby" anchor as user pans | Locked to device GPS |
| Q3 | Sheet snap states | 2 — peek ↔ expanded (~70 %) |
| Q4 | Tap a stop in list | Same sheet swaps content (in-sheet detail) |
| Q5 | Timetable scope | Live + lightweight static (trips.txt for headsigns; no stop_times.txt) |
| Q6 | List sizing | 500 m radius, capped at 20, sorted by distance |
| Q7 | Permission denied / no fix | Fallback to last known fix; if none, CTA |
| Q8 | Filter integration | Filter applies to departures inside detail; nearby list unfiltered |
| Q9 | Stops on map | Render nearby-20 as dots only when sheet expanded |
| Q10 | Detail polling | 5 s while detail open, back to global 10 s otherwise |
| Q11 | Detail content | Flat chronological list, next 10 departures |
| Q12 | Nearby row content | Stop name + line chips + walk time + distance |
| Q13 | Headsigns | Cache `trips.txt` like `routes.txt` |

## Architecture

Layered MVVM consistent with the rest of `lib/` (see `CLAUDE.md`).

```
lib/
  data/
    services/
      gtfs_static_service.dart        # extend: parseStopsFromZip, parseTripsFromZip
      gtfs_cache_service.dart         # rename + generalize from routes_cache_service.dart
      trip_updates_service.dart       # NEW
    repositories/
      stops_repository.dart           # NEW
      trip_updates_repository.dart    # NEW
      departures_repository.dart      # NEW
  domain/
    models/
      stop.dart                       # NEW
      trip_info.dart                  # NEW
      trip_update.dart                # NEW
      departure.dart                  # NEW
  ui/
    core/
      app_lifecycle_notifier.dart     # NEW (extracted from MapViewModel)
    features/
      nearby/
        nearby_stops_view_model.dart  # NEW
        stop_detail_view_model.dart   # NEW
        nearby_stops_sheet.dart       # NEW
        views/
          nearby_list_view.dart       # NEW
          nearby_list_row.dart        # NEW
          stop_detail_view.dart       # NEW
          departure_row.dart          # NEW
          permission_cta_view.dart    # NEW
        widgets/
          sheet_handle.dart           # NEW
      map/
        views/
          stop_markers_layer.dart     # NEW (mirrors vehicle_markers_layer.dart)
```

## Data layer

### `TripUpdatesService`

Mirrors `GtfsRtService`. Polls `https://otwarte.miasto.lodz.pl/wp-content/uploads/2025/06/trip_updates.bin`, decodes as `FeedMessage`, projects to `List<TripUpdate>`. Stateless. No internal timer — caller drives cadence.

```dart
class TripUpdate {
  final String tripId;
  final int? delaySec;             // trip-level current deviation
  final List<StopTimeUpdate> stopTimeUpdates;
}
class StopTimeUpdate {
  final String stopId;
  final int? etaUnixSec;           // arrival.time, absolute
  final int? delaySec;             // arrival.delay, finer-grained
}
```

Trips with zero `stop_time_update` entries are dropped at decode (saves filtering downstream).

### `GtfsStaticService` (extended)

Add `parseStopsFromZip(bytes) -> StopsIndex` and `parseTripsFromZip(bytes) -> TripsIndex`. The same single `GTFS.zip` fetch yields all three indexes (routes + stops + trips). Decode entries one at a time and discard buffers to keep peak memory bounded.

```dart
typedef StopsIndex = Map<String, Stop>;
typedef TripsIndex = Map<String, TripInfo>;

class Stop {
  final String id;
  final String name;
  final double lat;
  final double lon;
}
class TripInfo {
  final String tripId;
  final String routeId;
  final String headsign;
}
```

Malformed rows are skipped silently (consistent with existing routes parser).

### `GtfsCacheService` (renamed from `RoutesCacheService`)

Three on-disk JSON snapshots in `getApplicationSupportDirectory()`:
- `routes.json`
- `stops.json`
- `trips.json` (~4-6 MB after JSON encode)

Single TTL value (`LodzConstants.routesCacheTtl`) gates all three. On read, any miss triggers a single static fetch+parse that writes all three at once.

### Repositories

- `StopsRepository.getStops()` → `StopsIndex`. `nearby(Position pos, {radiusM = 500, limit = 20})` → `List<Stop>` sorted by Haversine distance. Pure compute, no IO after initial load.
- `TripUpdatesRepository` holds the latest `Map<String, TripUpdate>` keyed by `tripId`. Exposes `refresh()` (calls service, swaps map) and a `ChangeNotifier` interface so VMs can listen. No internal timer.
- `DeparturesRepository.for(String stopId, {required DateTime now, Set<String>? lineFilter})` → `List<Departure>`. Joins `TripUpdate.stopTimeUpdates` × `TripsIndex` × `RoutesIndex`, drops past times, sorts by `etaUnixSec` ascending, caps at 10. Applies `lineFilter` if provided (Q8=C). If a `tripId` is missing from `TripsIndex` (cache lag, rare), the headsign is null and `Departure.lineNumber` falls back to whatever `RoutesIndex` returns.

```dart
class Departure {
  final String lineNumber;
  final VehicleType lineType;
  final String? headsign;
  final int etaUnixSec;
  final int? delaySec;
}
```

### Bootstrap

Extend `BootstrapViewModel` to await stops + trips alongside routes. Existing loading screen / retry path covers the new fetches. Failure modes:

- Routes fail → existing error UI (unchanged).
- Stops fail → same error UI; sheet cannot function without stops.
- Trips fail → soft-degrade. App continues; `Departure.headsign` is null, `DeparturesRepository` works fine, UI just shows line number with no `→ Stoki` suffix.

## State layer

### `AppLifecycleNotifier`

`ChangeNotifier` + `WidgetsBindingObserver`. Single source of truth for foreground/background. Currently this lives inside `MapViewModel`; extract so `StopDetailViewModel` (and any future consumer) can subscribe without each one registering its own observer.

```dart
class AppLifecycleNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleState state = AppLifecycleState.resumed;
}
```

`MapViewModel` migrates to subscribe to this notifier instead of being its own observer. Behaviour unchanged.

### `NearbyStopsViewModel`

Owns:
- `LocationStatus { unknown | granted | denied | deniedForever | serviceDisabled }`
- `Position? lastFix`
- `List<Stop> nearby` (re-derived from `lastFix` + `StopsRepository.nearby(...)`)
- `Stop? selected`
- `SheetSnap { peek | expanded }`

Subscribes to `Geolocator.getPositionStream(distanceFilter: 25 m)` while mounted. Each emission updates `lastFix` and recomputes `nearby`. Stream errors (briefly lost GPS) are tolerated — VM keeps `lastFix` and the list is stable. On permission revocation mid-session, transitions to `denied`.

API: `selectStop(Stop)`, `clearSelection()`, `setSnap(SheetSnap)`, `requestLocationPermission()`.

No timer. Stops list re-sorts only when device moves.

### `StopDetailViewModel`

Created on demand by the sheet when `selected != null`; disposed on `clearSelection()`. Lifetime equals polling lifetime (Q10=B).

Owns `Timer.periodic(Duration(seconds: 5))`. First fetch is immediate (not deferred to first tick). Each tick:
1. `await TripUpdatesRepository.refresh()`.
2. Recompute `departures = DeparturesRepository.for(stop.id, now: DateTime.now(), lineFilter: filterVm.activeLineIds)`.
3. `notifyListeners()`.

Subscribes to `AppLifecycleNotifier`: pauses the timer on background, resumes + immediate refresh on foreground.

State: `Stop stop`, `List<Departure> departures`, `bool loading`, `Object? error`, `DateTime? lastFetched`.

Race guard: after each `await`, check `_disposed` before mutating / notifying. Mirrors the existing `MapViewModel.refreshOnce` guard.

### Provider wiring (in `MapScreen`)

```
ChangeNotifierProvider(NearbyStopsViewModel)
  └── Selector<NearbyStopsViewModel, Stop?>(selected) →
        if non-null:
          ChangeNotifierProxyProvider(
            create: StopDetailViewModel(stop, tripUpdatesRepo, departuresRepo,
                                        filterVm, lifecycleNotifier))
```

`Selector` ensures the proxy provider rebuilds (and disposes the old VM) only when the selected stop identity changes.

## UI

### `NearbyStopsSheet`

`DraggableScrollableSheet` with `snap: true`, `snapSizes: [0.12, 0.7]`. Mounted in the `MapScreen` Stack, layered above the map and below the existing `MapSearchBar` overlay. Initial size: peek (0.12). Background: `LodzColors.surface`, top corners `LodzRadius.lg`, drop shadow added as new `LodzShadows.sheet` token (`offset: (0, -4)`, `blur: 16`, `color: LodzColors.shadow.withOpacity(0.08)`).

Content area is an `AnimatedSwitcher` (200 ms fade+slide) keyed on a discriminator derived from VM state:
- `permission_cta` when `LocationStatus` ∈ {`denied`, `deniedForever`, `serviceDisabled`}
- `nearby_list` when granted + `selected == null`
- `stop_detail` when `selected != null`
- `waiting` when granted + `lastFix == null` and no cached fix

Sheet position listener pushes `setSnap(...)` so the map can react (dot layer visibility, camera padding).

When `LocationStatus` transitions into `denied`/`deniedForever`/`serviceDisabled`, the sheet auto-snaps to expanded so the CTA is fully visible (peek height is too small to render the icon + button comfortably). When the user grants permission, the sheet auto-snaps back to peek.

### `NearbyListView` peek state

Single horizontal row: drag handle, status label, chevron-up affordance. Tap anywhere expands to 0.7. Label copy by state:

- granted, list non-empty: `nearbyStopsCount` ("X przystanków w pobliżu")
- granted, list empty: `nearbyEmptyNoStops`
- granted, no fix yet: `nearbyWaitingForGps`
- unknown: `nearbyCheckingLocation`
- denied / serviceDisabled: peek is replaced wholesale by `PermissionCtaView` (not by a label), so the user can act without expanding.

### `NearbyListView` expanded state

`ListView.builder` of `NearbyListRow`. Header pinned at top: stop count + small "powered by GTFS" muted footer below the list.

### `NearbyListRow`

```
[stop name (1 line, ellipsis)        chevron_right]
[12  86  N1  •  ~2 min  •  120 m                  ]
```

- Stop name: `LodzTypography.titleMedium`.
- Line chips: existing `features/filter/line_chip.dart` with new `dense` size variant (smaller pill, ~24 px tall).
- Walk time: `(distanceM / 1.4).round()` minutes (1.4 m·s⁻¹ ≈ average walking speed). Floor of 1.
- Distance: rounded to 10 m granularity below 100 m, 50 m granularity above.
- Tap → `selectStop(stop)`.

### `StopDetailView`

```
← [Stop name]
   ostatnia aktualizacja HH:MM:SS
─────
12  → Stoki Centrum     • 3 min  (+1 min)
86  → Dw. Kaliski       • 5 min
N1  → Manufaktura       • 12 min
… (max 10)
```

Sticky header with back arrow (`clearSelection()`), stop name, last-fetched timestamp from `lastFetched`. Body is a non-scrolling `Column` of `DepartureRow` (always ≤ 10).

`DepartureRow`:
- Line chip on the left (uses line type → existing `LodzColors` mapping).
- Headsign in the middle, ellipsis if too long.
- ETA on the right: `«N min»` if `eta - now < 60 min`, else `HH:MM`.
- Delay badge below the ETA when `|delaySec| ≥ 60`: `+N min` red (`LodzColors.danger`) or `−N min` green (`LodzColors.success`).

Empty state (no upcoming departures): full-width muted "Brak nadchodzących odjazdów" plus the timestamp underneath. Detail view does not auto-close.

### `PermissionCtaView`

Centered icon + title + body + button. Copy varies by status:
- `denied`: button "Włącz lokalizację" → `Geolocator.requestPermission()`.
- `deniedForever`: button "Otwórz ustawienia" → `Geolocator.openAppSettings()`.
- `serviceDisabled`: copy "Włącz usługi lokalizacji w ustawieniach systemu", same settings button.

### `StopMarkersLayer`

Mirrors `vehicle_markers_layer.dart`. Owns a single MapLibre `geojson` source + circle layer added to `MapScreen` when sheet is expanded, removed when peeked. Source is the `nearby` list serialized as a `FeatureCollection`. Selected stop styled with a 12 px ring (`LodzColors.cyan`) and filled center; others as 6 px filled circle. Tapping a circle resolves to `stopId` and calls `selectStop(...)`.

### Map camera padding

When the sheet is expanded, MapLibre camera padding-bottom is set to `screenHeight * 0.7`, so map gestures and `LocateFab` re-centering both account for the obscured area. Toggled in the same listener that drives `setSnap(...)`.

### Localization (new ARB keys, `lib/l10n/app_pl.arb`)

| Key | Value (Polish) |
|---|---|
| `nearbyStopsCount` | `{count, plural, one{1 przystanek w pobliżu} few{# przystanki w pobliżu} many{# przystanków w pobliżu} other{# przystanków w pobliżu}}` |
| `nearbyEmptyNoStops` | `Brak przystanków w promieniu 500 m` |
| `nearbyEmptyNoDepartures` | `Brak nadchodzących odjazdów` |
| `nearbyWaitingForGps` | `Czekam na sygnał GPS…` |
| `nearbyCheckingLocation` | `Sprawdzam lokalizację…` |
| `permissionCtaTitleDenied` | `Włącz lokalizację, by zobaczyć przystanki w pobliżu` |
| `permissionCtaButtonGrant` | `Włącz lokalizację` |
| `permissionCtaButtonSettings` | `Otwórz ustawienia` |
| `permissionCtaTitleService` | `Włącz usługi lokalizacji w ustawieniach systemu` |
| `walkMinutes` | `~{n} min` |
| `metersAway` | `{n} m` |
| `lastUpdatedAt` | `ostatnia aktualizacja {time}` |
| `delayLate` | `+{n} min` |
| `delayEarly` | `−{n} min` |

Run `flutter gen-l10n` after edits; commit regenerated `app_localizations*.dart`.

## Edge cases

- Permission `unknown` (initial frame): peek shows `nearbyCheckingLocation`. List empty. No CTA flicker.
- Granted, no fix, no `lastFix` cached: peek shows `nearbyWaitingForGps`. Position stream resolves and replaces.
- Granted, no fix, but `lastFix` exists from prior session: use it (Q7=C). `lastFix` persisted via `shared_preferences` after each successful fix (small JSON: `{lat, lon, ts}`); read once on VM init.
- No nearby stops within 500 m: expanded list shows centered `nearbyEmptyNoStops`.
- `trip_updates.bin` 4xx/5xx/timeout: `TripUpdatesRepository.refresh()` catches, logs, retains the prior snapshot. `StopDetailViewModel.error` is set only when no prior data exists; otherwise UI just shows slightly stale departures with the timestamp.
- `trips.txt` parse failure on cold start: `BootstrapViewModel` surfaces non-blocking warning; departures show with no headsign.
- Selected stop has zero upcoming entries (off-hours, gap): empty state. View stays open.
- App backgrounded with detail open: `AppLifecycleNotifier` pauses both timers. On resume, both refresh immediately.
- VM dispose race: `_disposed` flag checked after every `await` before `notifyListeners()`.
- Tab switch (Map → Lines → Map): sheet unmounts on leave (VMs disposed), remounts on return, position stream re-subscribes, last-known fix bridges any GPS gap. Selected stop is not preserved across tab switches.
- Sheet on Lines/Favorites: not present (it lives in `MapScreen` only).
- `maplibre_gl` PlatformView: cannot be widget-tested; `StopMarkersLayer` verified manually (`docs/manual-test.md`).

## Testing

### Unit

- `gtfs_static_service_test.dart` — extend with synthetic mini-zip fixtures for `parseStopsFromZip` + `parseTripsFromZip`. Assert row counts, lat/lon parse, headsign extraction, malformed-row skip.
- `trip_updates_service_test.dart` — synthetic `FeedMessage` byte fixture (`fixnum.Int64` for timestamps). Assert decode shape, missing-field tolerance, empty-stop_time_update trips dropped.
- `gtfs_cache_service_test.dart` — three-snapshot read/write, single TTL, partial-write recovery.
- `stops_repository_test.dart` — `nearby()` sorting + radius filter + cap; dense-cluster cap, sparse-area all-returned, zero-distance, edge lat/lon.
- `trip_updates_repository_test.dart` — `refresh()` swap semantics, listener fires once per refresh, errors retain prior state.
- `departures_repository_test.dart` — pure compose with fake indexes. Ordering, past-departure filter, 10-cap, headsign join, missing-trip fallback, line-filter application.
- `app_lifecycle_notifier_test.dart` — observer behaviour and `MapViewModel` regression after extraction.
- `nearby_stops_view_model_test.dart` — fake `StopsRepository` + controllable `Stream<Position>`. Use `fakeAsync`. Assert: list updates on movement, `selectStop`/`clearSelection`, permission denial path, `lastFix` fallback.
- `stop_detail_view_model_test.dart` — fake `TripUpdatesRepository` + `fakeAsync`. Assert: 5 s cadence, immediate first fetch, lifecycle pause/resume, dispose cancels timer, post-dispose race guard.

### Widget

- `nearby_list_row_test.dart` — name/chips/distance/walk-time render; long-name ellipsis.
- `stop_detail_view_test.dart` — three departures with one delayed; assert delay color + sign, ellipsis, empty-state copy, sticky header, back-arrow callback.
- `permission_cta_view_test.dart` — copy variants by status, button taps fire correct action.
- `nearby_stops_sheet_test.dart` — content swap (list ↔ detail ↔ CTA ↔ waiting) via VM state changes; `AnimatedSwitcher` keys differ. (Real snap drag is integration-only; not covered.)

### Manual (extends `docs/manual-test.md`)

- Expand sheet → 20 dots appear; collapse → dots disappear.
- Tap a dot → detail opens for that stop.
- Pan map → list does not change (Q2=A).
- Walk 100 m → list re-sorts.
- Toggle airplane mode while detail open → stale departures persist with timestamp; back online → resumes.
- Deny location → CTA shows; tap settings opens system; grant → list appears within one stream tick.
- Filter line in `FilterSheet` → that line disappears from `StopDetailView` departures (Q8=C); nearby list unchanged.
- Background app for >30 s during detail polling → resume fetches immediately and updates timestamp.
- Switch to Lines tab and back → sheet remounts, stops list refreshes, no leaks (devtools).

## Implementation notes

- `geolocator` is already a direct dep (used by `LocateFab`). The existing permission flow folds into `NearbyStopsViewModel.requestLocationPermission()` so there is a single source of truth.
- New direct dep: `shared_preferences` for `lastFix` persistence (`{lat, lon, ts}` in a single key). Not currently in `pubspec.yaml`; add it.
- `LineChip` gains a `dense` size variant; existing call sites unchanged (default size preserved).
- `LodzShadows.sheet` is a new token — add alongside existing shadow tokens.
- `MapViewModel` loses its own `WidgetsBindingObserver` registration in favour of subscribing to `AppLifecycleNotifier`. Public API unchanged.
- Headsign post-processing: `trips.txt` `trip_headsign` column is canonical. Strip `MPK Łódź ` prefix or any agency artifacts at parse time.
- Walk-time speed (1.4 m·s⁻¹) is a constant in `LodzConstants` so it's tweakable.
- Cache TTL value (`LodzConstants.routesCacheTtl`) is shared with stops + trips; if revisited later, can split per index.

## Out of scope (for follow-ups)

- Vehicle-tap callout with line + delay + next stop (separate PR; uses the same `TripUpdatesService`).
- Offline indicator (50 % opacity + toast) carried over from the original spec.
- Hide `LocateFab` on permission denial.
- `SystemUiOverlayStyle` polish on Android.
- Decoder-level filter for vehicles with `lat=0/lon=0`.
- Saved/favorite stops in the Favorites tab.
- Deep linking to `/stops/:id`.

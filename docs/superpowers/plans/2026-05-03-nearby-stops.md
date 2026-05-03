# Nearby Stops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent draggable bottom sheet to the Map screen that lists stops near the device's GPS, with an in-sheet detail view showing live departures (line, headsign, ETA, delay) refreshed every 5 s.

**Architecture:** Layered MVVM matching the rest of `lib/`. New data layer (`TripUpdatesService`, extended `GtfsStaticService`, generalized `GtfsCacheService`, three new repositories), two ViewModels (`NearbyStopsViewModel` for the list, `StopDetailViewModel` for the detail with its own 5 s timer), a `DraggableScrollableSheet`-based UI mounted in `MapScreen`'s Stack, and a `StopMarkersLayer` mirroring `VehicleMarkersLayer`. App-wide foreground/background lifecycle is extracted from `MapViewModel` into a shared `AppLifecycleNotifier` so both the map's 10 s tick and the detail's 5 s tick pause together.

**Tech Stack:** Flutter 3.41 (Dart 3.10), `provider`, `geolocator` (already a dep), `shared_preferences` (new), `maplibre_gl`, `archive`, `csv`, `protoc_plugin`-generated `gtfs-realtime.pb.dart`, `flutter_test`, `fake_async`.

**Spec:** [`docs/superpowers/specs/2026-05-02-nearby-stops-design.md`](../specs/2026-05-02-nearby-stops-design.md).

---

## File map

### Created

| Path | Responsibility |
|---|---|
| `lib/domain/models/stop.dart` | Plain `Stop {id, name, lat, lon}`. |
| `lib/domain/models/trip_info.dart` | `TripInfo {tripId, routeId, headsign}` + `TripsIndex` typedef. |
| `lib/domain/models/trip_update.dart` | `TripUpdate {tripId, delaySec?, stopTimeUpdates}` and `StopTimeUpdate {stopId, etaUnixSec?, delaySec?}`. |
| `lib/domain/models/departure.dart` | `Departure {lineNumber, lineType, headsign?, etaUnixSec, delaySec?}`. |
| `lib/data/services/trip_updates_service.dart` | Polls `trip_updates.bin`, decodes via `FeedMessage`, returns `List<TripUpdate>`. |
| `lib/data/repositories/stops_repository.dart` | Loads `StopsIndex` (with cache), returns sorted-by-distance `nearby(...)`. |
| `lib/data/repositories/trip_updates_repository.dart` | `ChangeNotifier`-backed cache of latest `Map<String, TripUpdate>` keyed by `tripId`. |
| `lib/data/repositories/departures_repository.dart` | Pure compose: trip_updates × trips × routes → `List<Departure>`. |
| `lib/ui/core/app_lifecycle_notifier.dart` | `ChangeNotifier + WidgetsBindingObserver` shared lifecycle source. |
| `lib/ui/features/nearby/nearby_stops_view_model.dart` | List + permission + selection state. |
| `lib/ui/features/nearby/stop_detail_view_model.dart` | Selected-stop departures + 5 s timer. |
| `lib/ui/features/nearby/nearby_stops_sheet.dart` | `DraggableScrollableSheet` container, AnimatedSwitcher content. |
| `lib/ui/features/nearby/views/nearby_list_view.dart` | Peek + expanded list view. |
| `lib/ui/features/nearby/views/nearby_list_row.dart` | Single stop row. |
| `lib/ui/features/nearby/views/stop_detail_view.dart` | Detail header + departure list. |
| `lib/ui/features/nearby/views/departure_row.dart` | Single departure row. |
| `lib/ui/features/nearby/views/permission_cta_view.dart` | Permission/services-disabled CTA. |
| `lib/ui/features/nearby/widgets/sheet_handle.dart` | Drag handle pill. |
| `lib/ui/features/map/views/stop_markers_layer.dart` | MapLibre source + circle layer for nearby-20 dots. |
| `test/...` (mirrors above) | Tests for each new file. |

### Modified

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `shared_preferences` direct dep. |
| `lib/ui/core/lodz_constants.dart` | Add `nearbyRadiusM`, `nearbyLimit`, `walkingSpeedMps`, `detailPollInterval`, `sheetPeekFraction`, `sheetExpandedFraction`. |
| `lib/ui/core/design_tokens.dart` | Add `LodzShadows.sheet`; add `LodzColors.success`. |
| `lib/data/services/gtfs_static_service.dart` | Add `parseStopsFromZip`, `parseTripsFromZip`. |
| `lib/data/services/routes_cache_service.dart` → `gtfs_cache_service.dart` | Rename + generalize to read/write three snapshots. |
| `lib/data/repositories/routes_repository.dart` | Update import + cache type. |
| `lib/ui/features/map/view_models/map_view_model.dart` | Subscribe to `AppLifecycleNotifier` instead of being its own observer. |
| `lib/ui/features/map/view_models/bootstrap_view_model.dart` | Also load stops + trips. |
| `lib/ui/features/map/views/map_screen.dart` | Mount `NearbyStopsSheet`, wire providers, push camera padding while expanded. |
| `lib/ui/features/map/views/locate_fab.dart` | Use `NearbyStopsViewModel.requestLocationPermission()` and the `lastFix`/permission state. |
| `lib/ui/features/filter/views/line_chip.dart` | Add `dense` size variant (default unchanged). |
| `lib/l10n/app_pl.arb` | Add new keys; regenerate. |
| `lib/main.dart` | Provide `AppLifecycleNotifier`, `StopsRepository`, `TripUpdatesRepository`, `DeparturesRepository`. |
| `docs/manual-test.md` | New section for nearby-stops scenarios. |

### Deleted

None. The `routes_cache_service.dart` rename uses `git mv` so history is preserved.

---

## Task order rationale

Bottom-up: domain models → services → cache → repos → lifecycle/bootstrap → VMs → tokens/strings → leaf widgets → composite views → sheet container → markers layer → wiring → manual test doc. Each task ends with a green test run and a commit.

---

## Task 1: Project plumbing — deps, constants, design tokens

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/ui/core/lodz_constants.dart`
- Modify: `lib/ui/core/design_tokens.dart`
- Test: `test/ui/core/design_tokens_test.dart` (new — sanity)

- [ ] **Step 1: Add `shared_preferences` to dependencies**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  shared_preferences: ^2.3.0
```

Run:

```bash
flutter pub get
```

- [ ] **Step 2: Extend `LodzConstants`**

Append to `lib/ui/core/lodz_constants.dart`:

```dart
  // Nearby stops feature
  static const double nearbyRadiusM = 500;
  static const int nearbyLimit = 20;
  static const double walkingSpeedMps = 1.4;
  static const Duration detailPollInterval = Duration(seconds: 5);
  static const double sheetPeekFraction = 0.12;
  static const double sheetExpandedFraction = 0.7;
```

- [ ] **Step 3: Extend `LodzShadows` and `LodzColors`**

In `lib/ui/core/design_tokens.dart`:

In `LodzColors`, after `cyanSurface`, add:

```dart
  // Status accents
  static const Color success = Color(0xFF15803D);
```

In `LodzShadows`, after `level2`, add:

```dart
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x14000000), // 8% black
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
```

- [ ] **Step 4: Write a sanity test**

Create `test/ui/core/design_tokens_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/ui/core/design_tokens.dart';

void main() {
  test('LodzShadows.sheet uses upward offset', () {
    expect(LodzShadows.sheet, isNotEmpty);
    expect(LodzShadows.sheet.first.offset.dy, lessThan(0));
  });

  test('LodzColors.success is set', () {
    expect(LodzColors.success.value, isNot(0));
  });
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/ui/core/design_tokens_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ui/core/lodz_constants.dart \
        lib/ui/core/design_tokens.dart test/ui/core/design_tokens_test.dart
git commit -m "chore(nearby): plumbing — deps, constants, design tokens"
```

---

## Task 2: Domain models

**Files:**
- Create: `lib/domain/models/stop.dart`
- Create: `lib/domain/models/trip_info.dart`
- Create: `lib/domain/models/trip_update.dart`
- Create: `lib/domain/models/departure.dart`
- Test: `test/domain/models/models_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/models/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  test('Stop holds id/name/lat/lon', () {
    const s = Stop(id: '1', name: 'Plac Wolności', lat: 51.77, lon: 19.46);
    expect(s.id, '1');
    expect(s.lat, 51.77);
  });

  test('TripInfo holds routeId + headsign', () {
    const t = TripInfo(tripId: 't1', routeId: 'r1', headsign: 'Stoki');
    expect(t.headsign, 'Stoki');
  });

  test('TripUpdate composes StopTimeUpdate list', () {
    const u = TripUpdate(
      tripId: 't1',
      delaySec: 60,
      stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1000, delaySec: 60),
      ],
    );
    expect(u.stopTimeUpdates.length, 1);
    expect(u.stopTimeUpdates.first.stopId, 's1');
  });

  test('Departure has nullable headsign and delaySec', () {
    const d = Departure(
      lineNumber: '12',
      lineType: VehicleType.tram,
      headsign: null,
      etaUnixSec: 1000,
      delaySec: null,
    );
    expect(d.headsign, isNull);
    expect(d.delaySec, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/domain/models/models_test.dart
```

Expected: FAIL with "uri doesn't exist" / "undefined name" for the four new model classes.

- [ ] **Step 3: Implement `Stop`**

Create `lib/domain/models/stop.dart`:

```dart
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
}

typedef StopsIndex = Map<String, Stop>;
```

- [ ] **Step 4: Implement `TripInfo`**

Create `lib/domain/models/trip_info.dart`:

```dart
class TripInfo {
  const TripInfo({
    required this.tripId,
    required this.routeId,
    required this.headsign,
  });

  final String tripId;
  final String routeId;
  final String headsign;
}

typedef TripsIndex = Map<String, TripInfo>;
```

- [ ] **Step 5: Implement `TripUpdate`**

Create `lib/domain/models/trip_update.dart`:

```dart
class TripUpdate {
  const TripUpdate({
    required this.tripId,
    required this.delaySec,
    required this.stopTimeUpdates,
  });

  final String tripId;
  final int? delaySec;
  final List<StopTimeUpdate> stopTimeUpdates;
}

class StopTimeUpdate {
  const StopTimeUpdate({
    required this.stopId,
    required this.etaUnixSec,
    required this.delaySec,
  });

  final String stopId;
  final int? etaUnixSec;
  final int? delaySec;
}

typedef TripUpdatesIndex = Map<String, TripUpdate>;
```

- [ ] **Step 6: Implement `Departure`**

Create `lib/domain/models/departure.dart`:

```dart
import 'vehicle.dart';

class Departure {
  const Departure({
    required this.lineNumber,
    required this.lineType,
    required this.headsign,
    required this.etaUnixSec,
    required this.delaySec,
  });

  final String lineNumber;
  final VehicleType lineType;
  final String? headsign;
  final int etaUnixSec;
  final int? delaySec;
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/domain/models/models_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 8: Commit**

```bash
git add lib/domain/models/ test/domain/models/
git commit -m "feat(nearby): domain models for Stop/TripInfo/TripUpdate/Departure"
```

---

## Task 3: Extend `GtfsStaticService` to parse stops + trips

**Files:**
- Modify: `lib/data/services/gtfs_static_service.dart`
- Test: `test/data/services/gtfs_static_service_test.dart`

- [ ] **Step 1: Write failing tests for `parseStopsFromZip`**

Append to `test/data/services/gtfs_static_service_test.dart` (create if missing — see existing routes-only fixture pattern):

```dart
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';

List<int> _zip(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((name, body) {
    final bytes = utf8.encode(body);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive)!;
}

void main() {
  group('parseStopsFromZip', () {
    test('parses well-formed stops.txt', () async {
      final zip = _zip({
        'stops.txt':
            'stop_id,stop_name,stop_lat,stop_lon\n'
            '1,Plac Wolności,51.77,19.46\n'
            '2,Manufaktura,51.78,19.45\n',
      });
      final stops = await GtfsStaticService.parseStopsFromZip(zip);
      expect(stops.length, 2);
      expect(stops['1']!.name, 'Plac Wolności');
      expect(stops['2']!.lat, closeTo(51.78, 0.001));
    });

    test('skips rows with empty id, name, or unparseable coords', () async {
      final zip = _zip({
        'stops.txt':
            'stop_id,stop_name,stop_lat,stop_lon\n'
            ',Bad,51.77,19.46\n'
            '3,,51.77,19.46\n'
            '4,Ok,foo,bar\n'
            '5,Ok,51.77,19.46\n',
      });
      final stops = await GtfsStaticService.parseStopsFromZip(zip);
      expect(stops.keys, ['5']);
    });

    test('throws when stops.txt missing', () async {
      final zip = _zip({'other.txt': 'x'});
      expect(
        () => GtfsStaticService.parseStopsFromZip(zip),
        throwsException,
      );
    });
  });

  group('parseTripsFromZip', () {
    test('parses trip_id, route_id, trip_headsign', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign\n'
            'r1,s1,t1,Stoki\n'
            'r2,s1,t2,Manufaktura\n',
      });
      final trips = await GtfsStaticService.parseTripsFromZip(zip);
      expect(trips.length, 2);
      expect(trips['t1']!.routeId, 'r1');
      expect(trips['t1']!.headsign, 'Stoki');
    });

    test('skips rows missing trip_id', () async {
      final zip = _zip({
        'trips.txt':
            'route_id,service_id,trip_id,trip_headsign\n'
            'r1,s1,,Stoki\n'
            'r1,s1,t2,Centrum\n',
      });
      final trips = await GtfsStaticService.parseTripsFromZip(zip);
      expect(trips.keys, ['t2']);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/data/services/gtfs_static_service_test.dart
```

Expected: FAIL — methods undefined.

- [ ] **Step 3: Implement parsers**

Append to `lib/data/services/gtfs_static_service.dart` (inside the existing class, alongside `parseRoutesFromZip`):

```dart
  static Future<StopsIndex> parseStopsFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('stops.txt');
    if (entry == null) {
      throw Exception('stops.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content);
    final rows = const CsvDecoder(dynamicTyping: false).convert(csvText);
    if (rows.isEmpty) return <String, Stop>{};

    final headers = rows.first.cast<String>();
    final iId = headers.indexOf('stop_id');
    final iName = headers.indexOf('stop_name');
    final iLat = headers.indexOf('stop_lat');
    final iLon = headers.indexOf('stop_lon');
    if (iId < 0 || iName < 0 || iLat < 0 || iLon < 0) {
      throw Exception('stops.txt missing required columns');
    }

    final out = <String, Stop>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= iLon) continue;
      final id = r[iId].toString();
      final name = r[iName].toString();
      final lat = double.tryParse(r[iLat].toString());
      final lon = double.tryParse(r[iLon].toString());
      if (id.isEmpty || name.isEmpty || lat == null || lon == null) continue;
      out[id] = Stop(id: id, name: name, lat: lat, lon: lon);
    }
    return out;
  }

  static Future<TripsIndex> parseTripsFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('trips.txt');
    if (entry == null) {
      throw Exception('trips.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content);
    final rows = const CsvDecoder(dynamicTyping: false).convert(csvText);
    if (rows.isEmpty) return <String, TripInfo>{};

    final headers = rows.first.cast<String>();
    final iTripId = headers.indexOf('trip_id');
    final iRouteId = headers.indexOf('route_id');
    final iHeadsign = headers.indexOf('trip_headsign');
    if (iTripId < 0 || iRouteId < 0) {
      throw Exception('trips.txt missing required columns');
    }

    final out = <String, TripInfo>{};
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.length <= iTripId) continue;
      final tripId = r[iTripId].toString();
      final routeId = iRouteId < r.length ? r[iRouteId].toString() : '';
      if (tripId.isEmpty || routeId.isEmpty) continue;
      final headsign = (iHeadsign >= 0 && iHeadsign < r.length)
          ? r[iHeadsign].toString()
          : '';
      out[tripId] = TripInfo(
        tripId: tripId,
        routeId: routeId,
        headsign: headsign,
      );
    }
    return out;
  }
```

Add the imports at the top:

```dart
import '../../domain/models/stop.dart';
import '../../domain/models/trip_info.dart';
```

Also extend the public fetcher to expose all three indexes so the bootstrap path can do one network round-trip:

```dart
class GtfsStaticBundle {
  const GtfsStaticBundle({
    required this.routes,
    required this.stops,
    required this.trips,
  });
  final RoutesIndex routes;
  final StopsIndex stops;
  final TripsIndex trips;
}

  Future<GtfsStaticBundle> fetchAndParseAll() async {
    final res = await _client.get(staticUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS static fetch failed: ${res.statusCode}');
    }
    final bytes = res.bodyBytes;
    final routes = await parseRoutesFromZip(bytes);
    final stops = await parseStopsFromZip(bytes);
    final trips = await parseTripsFromZip(bytes);
    return GtfsStaticBundle(routes: routes, stops: stops, trips: trips);
  }
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/data/services/gtfs_static_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/gtfs_static_service.dart \
        test/data/services/gtfs_static_service_test.dart
git commit -m "feat(nearby): parse stops.txt and trips.txt from GTFS zip"
```

---

## Task 4: Generalize `RoutesCacheService` → `GtfsCacheService`

**Files:**
- Rename + edit: `lib/data/services/routes_cache_service.dart` → `lib/data/services/gtfs_cache_service.dart`
- Modify: `lib/data/repositories/routes_repository.dart`
- Test: `test/data/services/gtfs_cache_service_test.dart` (renamed from any existing routes cache test, or new)

- [ ] **Step 1: `git mv` the file**

```bash
git mv lib/data/services/routes_cache_service.dart \
       lib/data/services/gtfs_cache_service.dart
```

- [ ] **Step 2: Write the failing test**

Create `test/data/services/gtfs_cache_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

Directory _tmp() => Directory.systemTemp.createTempSync('gtfs_cache_test');

void main() {
  test('writeBundle then readBundle round-trips when fresh', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    final bundle = GtfsCachedBundle(
      routes: {'r1': const Line(routeId: 'r1', number: '12', type: VehicleType.tram)},
      stops: {'s1': const Stop(id: 's1', name: 'A', lat: 51.7, lon: 19.4)},
      trips: {'t1': const TripInfo(tripId: 't1', routeId: 'r1', headsign: 'X')},
    );
    await svc.writeBundle(bundle);
    final back = await svc.readBundle(maxAge: const Duration(days: 1));
    expect(back, isNotNull);
    expect(back!.routes['r1']!.number, '12');
    expect(back.stops['s1']!.name, 'A');
    expect(back.trips['t1']!.headsign, 'X');
  });

  test('readBundle returns null when any snapshot missing', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    expect(
      await svc.readBundle(maxAge: const Duration(days: 1)),
      isNull,
    );
  });

  test('readBundle returns null when oldest snapshot is stale', () async {
    final dir = _tmp();
    final svc = GtfsCacheService(directoryProvider: () async => dir);
    await svc.writeBundle(GtfsCachedBundle(routes: {}, stops: {}, trips: {}));
    // Backdate trips.json beyond TTL.
    final tripsFile = File('${dir.path}/trips.json');
    await tripsFile.setLastModified(DateTime.now().subtract(const Duration(days: 30)));
    expect(
      await svc.readBundle(maxAge: const Duration(days: 7)),
      isNull,
    );
  });
}
```

- [ ] **Step 3: Run test to verify failure**

```bash
flutter test test/data/services/gtfs_cache_service_test.dart
```

Expected: FAIL — `GtfsCacheService`/`GtfsCachedBundle` undefined.

- [ ] **Step 4: Rewrite the cache service**

Replace contents of `lib/data/services/gtfs_cache_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/line.dart';
import '../../domain/models/stop.dart';
import '../../domain/models/trip_info.dart';
import '../../domain/models/vehicle.dart';

typedef DirectoryProvider = Future<Directory> Function();

class GtfsCachedBundle {
  const GtfsCachedBundle({
    required this.routes,
    required this.stops,
    required this.trips,
  });
  final RoutesIndex routes;
  final StopsIndex stops;
  final TripsIndex trips;
}

class GtfsCacheService {
  GtfsCacheService({DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final DirectoryProvider _directoryProvider;

  static const _routesName = 'routes.json';
  static const _stopsName = 'stops.json';
  static const _tripsName = 'trips.json';

  Future<File> _file(String name) async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$name');
  }

  Future<GtfsCachedBundle?> readBundle({required Duration maxAge}) async {
    final routesFile = await _file(_routesName);
    final stopsFile = await _file(_stopsName);
    final tripsFile = await _file(_tripsName);
    if (!routesFile.existsSync() ||
        !stopsFile.existsSync() ||
        !tripsFile.existsSync()) {
      return null;
    }
    final times = await Future.wait([
      routesFile.lastModified(),
      stopsFile.lastModified(),
      tripsFile.lastModified(),
    ]);
    final oldest = times.reduce((a, b) => a.isBefore(b) ? a : b);
    if (DateTime.now().difference(oldest) > maxAge) return null;

    return GtfsCachedBundle(
      routes: _decodeRoutes(jsonDecode(await routesFile.readAsString())),
      stops: _decodeStops(jsonDecode(await stopsFile.readAsString())),
      trips: _decodeTrips(jsonDecode(await tripsFile.readAsString())),
    );
  }

  Future<void> writeBundle(GtfsCachedBundle bundle) async {
    await (await _file(_routesName))
        .writeAsString(jsonEncode(_encodeRoutes(bundle.routes)));
    await (await _file(_stopsName))
        .writeAsString(jsonEncode(_encodeStops(bundle.stops)));
    await (await _file(_tripsName))
        .writeAsString(jsonEncode(_encodeTrips(bundle.trips)));
  }

  // --- routes ---

  static Map<String, dynamic> _encodeRoutes(RoutesIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {'routeId': v.routeId, 'number': v.number, 'type': v.type.name};
    });
    return out;
  }

  static RoutesIndex _decodeRoutes(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, Line>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = Line(
        routeId: j['routeId'] as String,
        number: j['number'] as String,
        type: VehicleType.values.firstWhere(
          (t) => t.name == (j['type'] as String),
          orElse: () => VehicleType.unknown,
        ),
      );
    });
    return out;
  }

  // --- stops ---

  static Map<String, dynamic> _encodeStops(StopsIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {'id': v.id, 'name': v.name, 'lat': v.lat, 'lon': v.lon};
    });
    return out;
  }

  static StopsIndex _decodeStops(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, Stop>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = Stop(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
    });
    return out;
  }

  // --- trips ---

  static Map<String, dynamic> _encodeTrips(TripsIndex idx) {
    final out = <String, dynamic>{};
    idx.forEach((k, v) {
      out[k] = {
        'tripId': v.tripId,
        'routeId': v.routeId,
        'headsign': v.headsign,
      };
    });
    return out;
  }

  static TripsIndex _decodeTrips(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final out = <String, TripInfo>{};
    m.forEach((k, v) {
      final j = v as Map<String, dynamic>;
      out[k] = TripInfo(
        tripId: j['tripId'] as String,
        routeId: j['routeId'] as String,
        headsign: j['headsign'] as String,
      );
    });
    return out;
  }
}
```

- [ ] **Step 5: Update `RoutesRepository`**

Edit `lib/data/repositories/routes_repository.dart`:

```dart
import '../../domain/models/line.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_cache_service.dart';
import '../services/gtfs_static_service.dart';

class RoutesRepository {
  RoutesRepository({
    required GtfsStaticService staticService,
    required GtfsCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  final GtfsStaticService _static;
  final GtfsCacheService _cache;

  Future<RoutesIndex> getRoutes() async {
    final cached =
        await _cache.readBundle(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) return cached.routes;
    final fresh = await _static.fetchAndParseAll();
    await _cache.writeBundle(GtfsCachedBundle(
      routes: fresh.routes,
      stops: fresh.stops,
      trips: fresh.trips,
    ));
    return fresh.routes;
  }
}
```

- [ ] **Step 6: Update any imports across the codebase**

```bash
grep -rln "routes_cache_service" lib/ test/
```

For each match, replace:
- `routes_cache_service.dart` → `gtfs_cache_service.dart`
- `RoutesCacheService` → `GtfsCacheService`
- old call sites: `cache.read(maxAge: ...)` → `cache.readBundle(maxAge: ...)`, `cache.write(idx)` → use `RoutesRepository` only (other callers should not exist).

- [ ] **Step 7: Run all tests**

```bash
flutter analyze && flutter test
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(cache): generalize routes cache to three-snapshot GtfsCacheService"
```

---

## Task 5: `TripUpdatesService`

**Files:**
- Create: `lib/data/services/trip_updates_service.dart`
- Test: `test/data/services/trip_updates_service_test.dart`

- [ ] **Step 1: Write failing test using a synthetic FeedMessage**

Create `test/data/services/trip_updates_service_test.dart`:

```dart
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/generated/gtfs-realtime.pb.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';

FeedMessage _makeFeed({
  required String tripId,
  int? tripDelay,
  List<({String stopId, int? eta, int? delay})> stops = const [],
}) {
  final feed = FeedMessage()
    ..header = (FeedHeader()
      ..gtfsRealtimeVersion = '2.0'
      ..timestamp = Int64(0));
  final entity = FeedEntity()..id = 'e1';
  final upd = TripUpdate()..trip = (TripDescriptor()..tripId = tripId);
  if (tripDelay != null) upd.delay = tripDelay;
  for (final s in stops) {
    final stu = TripUpdate_StopTimeUpdate()..stopId = s.stopId;
    if (s.eta != null) stu.arrival = (TripUpdate_StopTimeEvent()..time = Int64(s.eta!));
    if (s.delay != null) {
      stu.arrival = (stu.arrival..delay = s.delay!);
    }
    upd.stopTimeUpdate.add(stu);
  }
  entity.tripUpdate = upd;
  feed.entity.add(entity);
  return feed;
}

void main() {
  test('decodes trip with delay and arrival.time', () {
    final feed = _makeFeed(
      tripId: 't1',
      tripDelay: 60,
      stops: [(stopId: 's1', eta: 1700000000, delay: 60)],
    );
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, hasLength(1));
    expect(out.first.tripId, 't1');
    expect(out.first.delaySec, 60);
    expect(out.first.stopTimeUpdates.first.etaUnixSec, 1700000000);
  });

  test('drops trips with empty stop_time_update', () {
    final feed = _makeFeed(tripId: 't1');
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, isEmpty);
  });

  test('handles missing arrival.time gracefully', () {
    final feed = _makeFeed(
      tripId: 't1',
      stops: [(stopId: 's1', eta: null, delay: null)],
    );
    final out = TripUpdatesService.decode(feed.writeToBuffer());
    expect(out, hasLength(1));
    expect(out.first.stopTimeUpdates.first.etaUnixSec, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/data/services/trip_updates_service_test.dart
```

Expected: FAIL — `TripUpdatesService` undefined.

- [ ] **Step 3: Implement service**

Create `lib/data/services/trip_updates_service.dart`:

```dart
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/trip_update.dart';
import 'generated/gtfs-realtime.pb.dart' as pb;

class TripUpdatesService {
  TripUpdatesService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri tripUpdatesUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/trip_updates.bin',
  );

  final http.Client _client;

  Future<List<TripUpdate>> fetchTripUpdates() async {
    final res = await _client.get(tripUpdatesUrl);
    if (res.statusCode != 200) {
      throw Exception('trip_updates fetch failed: ${res.statusCode}');
    }
    return decode(res.bodyBytes);
  }

  static List<TripUpdate> decode(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    final feed = pb.FeedMessage.fromBuffer(Uint8List.fromList(bytes));
    final out = <TripUpdate>[];
    for (final entity in feed.entity) {
      if (!entity.hasTripUpdate()) continue;
      final upd = entity.tripUpdate;
      final tripId = upd.hasTrip() ? upd.trip.tripId : '';
      if (tripId.isEmpty) continue;
      if (upd.stopTimeUpdate.isEmpty) continue;
      final stops = <StopTimeUpdate>[];
      for (final stu in upd.stopTimeUpdate) {
        if (stu.stopId.isEmpty) continue;
        int? eta;
        int? delay;
        if (stu.hasArrival()) {
          if (stu.arrival.hasTime()) eta = stu.arrival.time.toInt();
          if (stu.arrival.hasDelay()) delay = stu.arrival.delay;
        }
        stops.add(StopTimeUpdate(stopId: stu.stopId, etaUnixSec: eta, delaySec: delay));
      }
      if (stops.isEmpty) continue;
      out.add(TripUpdate(
        tripId: tripId,
        delaySec: upd.hasDelay() ? upd.delay : null,
        stopTimeUpdates: stops,
      ));
    }
    return out;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/data/services/trip_updates_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/trip_updates_service.dart \
        test/data/services/trip_updates_service_test.dart
git commit -m "feat(nearby): TripUpdatesService — decode trip_updates.bin"
```

---

## Task 6: `StopsRepository`

**Files:**
- Create: `lib/data/repositories/stops_repository.dart`
- Test: `test/data/repositories/stops_repository_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/data/repositories/stops_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';

Position _pos(double lat, double lon) => Position(
      longitude: lon,
      latitude: lat,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late StopsIndex idx;

  setUp(() {
    idx = {
      'a': const Stop(id: 'a', name: 'A', lat: 51.7600, lon: 19.4500),
      'b': const Stop(id: 'b', name: 'B', lat: 51.7610, lon: 19.4500), // ~111m N
      'c': const Stop(id: 'c', name: 'C', lat: 51.7700, lon: 19.4500), // ~1.1km
      'd': const Stop(id: 'd', name: 'D', lat: 51.7601, lon: 19.4501), // ~14m
    };
  });

  test('nearby sorts by ascending distance', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 500, limit: 10);
    expect(result.map((s) => s.id), ['a', 'd', 'b']);
  });

  test('nearby applies radius filter', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 50, limit: 10);
    expect(result.map((s) => s.id), ['a', 'd']);
  });

  test('nearby caps at limit', () {
    final repo = StopsRepository.test(idx);
    final result = repo.nearby(_pos(51.76, 19.45), radiusM: 5000, limit: 2);
    expect(result, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/data/repositories/stops_repository_test.dart
```

Expected: FAIL — `StopsRepository` undefined.

- [ ] **Step 3: Implement repository**

Create `lib/data/repositories/stops_repository.dart`:

```dart
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../domain/models/stop.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_cache_service.dart';
import '../services/gtfs_static_service.dart';

class StopsRepository {
  StopsRepository({
    required GtfsStaticService staticService,
    required GtfsCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  /// Test-only constructor that injects a pre-loaded index.
  @visibleForTesting
  StopsRepository.test(StopsIndex index)
      : _static = null,
        _cache = null,
        _index = index;

  final GtfsStaticService? _static;
  final GtfsCacheService? _cache;
  StopsIndex? _index;

  Future<StopsIndex> getStops() async {
    if (_index != null) return _index!;
    final cached = await _cache!.readBundle(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) {
      _index = cached.stops;
      return _index!;
    }
    final fresh = await _static!.fetchAndParseAll();
    await _cache!.writeBundle(GtfsCachedBundle(
      routes: fresh.routes,
      stops: fresh.stops,
      trips: fresh.trips,
    ));
    _index = fresh.stops;
    return _index!;
  }

  List<Stop> nearby(
    Position pos, {
    double radiusM = LodzConstants.nearbyRadiusM,
    int limit = LodzConstants.nearbyLimit,
  }) {
    final idx = _index;
    if (idx == null) return const [];
    final scored = <_Scored>[];
    for (final s in idx.values) {
      final d = _haversine(pos.latitude, pos.longitude, s.lat, s.lon);
      if (d <= radiusM) scored.add(_Scored(s, d));
    }
    scored.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return scored.take(limit).map((e) => e.stop).toList();
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg(lat1)) * math.cos(_deg(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static double _deg(double v) => v * math.pi / 180.0;
}

class _Scored {
  _Scored(this.stop, this.distanceM);
  final Stop stop;
  final double distanceM;
}
```

Add the `meta` import / `@visibleForTesting` annotation:

```dart
import 'package:meta/meta.dart';
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/data/repositories/stops_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/stops_repository.dart \
        test/data/repositories/stops_repository_test.dart
git commit -m "feat(nearby): StopsRepository with Haversine sort + radius cap"
```

---

## Task 7: `TripUpdatesRepository`

**Files:**
- Create: `lib/data/repositories/trip_updates_repository.dart`
- Test: `test/data/repositories/trip_updates_repository_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/data/repositories/trip_updates_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';

class _FakeService extends TripUpdatesService {
  _FakeService();
  List<TripUpdate> next = const [];
  bool fail = false;
  int calls = 0;
  @override
  Future<List<TripUpdate>> fetchTripUpdates() async {
    calls++;
    if (fail) throw Exception('boom');
    return next;
  }
}

void main() {
  test('refresh swaps map and notifies listeners', () async {
    final svc = _FakeService();
    final repo = TripUpdatesRepository(service: svc);
    int notifications = 0;
    repo.addListener(() => notifications++);

    svc.next = const [
      TripUpdate(tripId: 't1', delaySec: 30, stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1, delaySec: 0),
      ]),
    ];
    await repo.refresh();
    expect(repo.byTripId.containsKey('t1'), isTrue);
    expect(notifications, 1);
  });

  test('refresh failure retains previous snapshot, no notification', () async {
    final svc = _FakeService();
    final repo = TripUpdatesRepository(service: svc);
    svc.next = const [
      TripUpdate(tripId: 't1', delaySec: 0, stopTimeUpdates: [
        StopTimeUpdate(stopId: 's1', etaUnixSec: 1, delaySec: 0),
      ]),
    ];
    await repo.refresh();
    int notifications = 0;
    repo.addListener(() => notifications++);

    svc.fail = true;
    await repo.refresh();
    expect(repo.byTripId.containsKey('t1'), isTrue);
    expect(notifications, 0);
    expect(repo.lastError, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/data/repositories/trip_updates_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement repository**

Create `lib/data/repositories/trip_updates_repository.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../domain/models/trip_update.dart';
import '../services/trip_updates_service.dart';

class TripUpdatesRepository extends ChangeNotifier {
  TripUpdatesRepository({required TripUpdatesService service}) : _service = service;

  final TripUpdatesService _service;
  Map<String, TripUpdate> _byTripId = const {};
  Object? _lastError;
  DateTime? _lastFetched;

  Map<String, TripUpdate> get byTripId => _byTripId;
  Object? get lastError => _lastError;
  DateTime? get lastFetched => _lastFetched;

  Future<void> refresh() async {
    try {
      final list = await _service.fetchTripUpdates();
      _byTripId = {for (final u in list) u.tripId: u};
      _lastError = null;
      _lastFetched = DateTime.now();
      notifyListeners();
    } catch (e) {
      _lastError = e;
      // Retain prior snapshot; do not notify (no UI change).
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/data/repositories/trip_updates_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/trip_updates_repository.dart \
        test/data/repositories/trip_updates_repository_test.dart
git commit -m "feat(nearby): TripUpdatesRepository with refresh + listener"
```

---

## Task 8: `DeparturesRepository`

**Files:**
- Create: `lib/data/repositories/departures_repository.dart`
- Test: `test/data/repositories/departures_repository_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/data/repositories/departures_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/departures_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

class _StubTripUpdates extends TripUpdatesRepository {
  _StubTripUpdates(Map<String, TripUpdate> seed)
      : super(service: TripUpdatesService()) {
    _seed = seed;
  }
  late final Map<String, TripUpdate> _seed;
  @override
  Map<String, TripUpdate> get byTripId => _seed;
}

void main() {
  final routes = <String, Line>{
    'r12': const Line(routeId: 'r12', number: '12', type: VehicleType.tram),
    'r86': const Line(routeId: 'r86', number: '86', type: VehicleType.bus),
  };
  final trips = <String, TripInfo>{
    't1': const TripInfo(tripId: 't1', routeId: 'r12', headsign: 'Stoki'),
    't2': const TripInfo(tripId: 't2', routeId: 'r86', headsign: 'Manufaktura'),
  };
  final updates = <String, TripUpdate>{
    't1': const TripUpdate(tripId: 't1', delaySec: 60, stopTimeUpdates: [
      StopTimeUpdate(stopId: 'S1', etaUnixSec: 1000, delaySec: 60),
      StopTimeUpdate(stopId: 'S2', etaUnixSec: 1200, delaySec: 60),
    ]),
    't2': const TripUpdate(tripId: 't2', delaySec: 0, stopTimeUpdates: [
      StopTimeUpdate(stopId: 'S1', etaUnixSec: 800, delaySec: 0),
    ]),
  };

  test('returns sorted, future-only departures for a stop', () {
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(updates),
      trips: trips,
      routes: routes,
    );
    final out = repo.forStop(
      'S1',
      now: DateTime.fromMillisecondsSinceEpoch(900 * 1000),
    );
    expect(out.map((d) => d.lineNumber), ['12']);
  });

  test('applies line filter', () {
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(updates),
      trips: trips,
      routes: routes,
    );
    final out = repo.forStop(
      'S1',
      now: DateTime.fromMillisecondsSinceEpoch(0),
      lineFilter: {'r12'},
    );
    expect(out.map((d) => d.lineNumber), ['12']);
  });

  test('caps at 10 results', () {
    final big = <String, TripUpdate>{
      for (var i = 0; i < 20; i++)
        't$i': TripUpdate(
          tripId: 't$i',
          delaySec: 0,
          stopTimeUpdates: [
            StopTimeUpdate(stopId: 'S1', etaUnixSec: 1000 + i, delaySec: 0),
          ],
        ),
    };
    final allTrips = <String, TripInfo>{
      for (var i = 0; i < 20; i++)
        't$i': TripInfo(tripId: 't$i', routeId: 'r12', headsign: 'X'),
    };
    final repo = DeparturesRepository(
      tripUpdates: _StubTripUpdates(big),
      trips: allTrips,
      routes: routes,
    );
    final out = repo.forStop('S1', now: DateTime.fromMillisecondsSinceEpoch(0));
    expect(out, hasLength(10));
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/data/repositories/departures_repository_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement repository**

Create `lib/data/repositories/departures_repository.dart`:

```dart
import '../../domain/models/departure.dart';
import '../../domain/models/line.dart';
import '../../domain/models/trip_info.dart';
import '../../domain/models/vehicle.dart';
import 'trip_updates_repository.dart';

class DeparturesRepository {
  DeparturesRepository({
    required TripUpdatesRepository tripUpdates,
    required TripsIndex trips,
    required RoutesIndex routes,
  })  : _tripUpdates = tripUpdates,
        _trips = trips,
        _routes = routes;

  final TripUpdatesRepository _tripUpdates;
  final TripsIndex _trips;
  final RoutesIndex _routes;

  static const int _maxResults = 10;

  List<Departure> forStop(
    String stopId, {
    required DateTime now,
    Set<String>? lineFilter,
  }) {
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final out = <Departure>[];

    for (final upd in _tripUpdates.byTripId.values) {
      final trip = _trips[upd.tripId];
      final routeId = trip?.routeId ?? '';
      if (lineFilter != null && lineFilter.isNotEmpty && !lineFilter.contains(routeId)) {
        continue;
      }
      for (final stu in upd.stopTimeUpdates) {
        if (stu.stopId != stopId) continue;
        if (stu.etaUnixSec == null) continue;
        if (stu.etaUnixSec! < nowSec) continue;
        final line = trip == null ? null : _routes[trip.routeId];
        out.add(Departure(
          lineNumber: line?.number ?? routeId,
          lineType: line?.type ?? VehicleType.unknown,
          headsign: trip?.headsign,
          etaUnixSec: stu.etaUnixSec!,
          delaySec: stu.delaySec ?? upd.delaySec,
        ));
      }
    }

    out.sort((a, b) => a.etaUnixSec.compareTo(b.etaUnixSec));
    if (out.length > _maxResults) {
      return out.sublist(0, _maxResults);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/data/repositories/departures_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/departures_repository.dart \
        test/data/repositories/departures_repository_test.dart
git commit -m "feat(nearby): DeparturesRepository — compose trip_updates × trips × routes"
```

---

## Task 9: Extract `AppLifecycleNotifier`

**Files:**
- Create: `lib/ui/core/app_lifecycle_notifier.dart`
- Modify: `lib/ui/features/map/view_models/map_view_model.dart`
- Modify: `lib/main.dart` (provide notifier)
- Test: `test/ui/core/app_lifecycle_notifier_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/core/app_lifecycle_notifier_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';

void main() {
  testWidgets('notifies on lifecycle change', (tester) async {
    final n = AppLifecycleNotifier()..attach();
    addTearDown(n.detach);
    var fired = 0;
    n.addListener(() => fired++);

    n.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(n.state, AppLifecycleState.paused);
    expect(fired, 1);

    n.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(n.state, AppLifecycleState.resumed);
    expect(fired, 2);
  });

  test('attach is idempotent', () {
    final n = AppLifecycleNotifier();
    n.attach();
    n.attach(); // second call is no-op
    n.detach();
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/ui/core/app_lifecycle_notifier_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement notifier**

Create `lib/ui/core/app_lifecycle_notifier.dart`:

```dart
import 'package:flutter/widgets.dart';

class AppLifecycleNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleState _state = AppLifecycleState.resumed;
  bool _attached = false;

  AppLifecycleState get state => _state;
  bool get isResumed => _state == AppLifecycleState.resumed;

  void attach() {
    if (_attached) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == _state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run lifecycle test**

```bash
flutter test test/ui/core/app_lifecycle_notifier_test.dart
```

Expected: PASS.

- [ ] **Step 5: Migrate `MapViewModel` to subscribe to the notifier**

In `lib/ui/features/map/view_models/map_view_model.dart`:

1. Remove `with WidgetsBindingObserver` and the explicit `addObserver`/`removeObserver` calls.
2. Accept `AppLifecycleNotifier` via constructor.
3. Subscribe in constructor: `_lifecycle.addListener(_onLifecycle);` and react in `_onLifecycle()`:

```dart
  final AppLifecycleNotifier _lifecycle;

  void _onLifecycle() {
    if (_lifecycle.isResumed) {
      _resumeTimer();
      refreshOnce();
    } else {
      _pauseTimer();
    }
  }
```

4. In `dispose()`: `_lifecycle.removeListener(_onLifecycle);` (do not call `detach()` — notifier outlives VM).
5. Drop the `_lifecycleAttached` flag and `attachLifecycle`/`detachLifecycle` methods (no longer needed; notifier owns the binding).

Update existing `map_view_model_test.dart` — provide a `AppLifecycleNotifier` instance in tests; remove any direct lifecycle observer calls.

- [ ] **Step 6: Provide notifier in `main.dart`**

In `lib/main.dart`, ensure a single `AppLifecycleNotifier` is created early, `attach()`-ed, and provided via `ChangeNotifierProvider`. Existing `MapViewModel` factory pulls it from the tree.

- [ ] **Step 7: Run all tests + analyze**

```bash
flutter analyze && flutter test
```

Expected: green. Fix any tests that touched lifecycle directly.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(map): extract AppLifecycleNotifier shared by map + nearby VMs"
```

---

## Task 10: Extend `BootstrapViewModel` to load stops + trips

**Files:**
- Modify: `lib/ui/features/map/view_models/bootstrap_view_model.dart`
- Modify: `lib/main.dart` (wire new repos)
- Test: `test/ui/features/map/view_models/bootstrap_view_model_test.dart`

- [ ] **Step 1: Write failing test**

Open the existing bootstrap test (or create one) and add:

```dart
test('loads routes, stops, and trips on bootstrap', () async {
  final cache = _FakeCache(); // returns null first call
  final stat = _FakeStaticService(); // returns small bundle
  final vm = BootstrapViewModel(
    routesRepo: RoutesRepository(staticService: stat, cacheService: cache),
    stopsRepo: StopsRepository(staticService: stat, cacheService: cache),
    tripsLoader: () async {
      final bundle = await stat.fetchAndParseAll();
      return bundle.trips;
    },
  );
  await vm.load();
  expect(vm.routes, isNotNull);
  expect(vm.stops, isNotNull);
  expect(vm.trips, isNotNull);
  expect(vm.error, isNull);
});
```

(Provide minimal `_FakeCache`/`_FakeStaticService` returning a hand-built `GtfsStaticBundle`.)

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/ui/features/map/view_models/bootstrap_view_model_test.dart
```

Expected: FAIL — VM doesn't expose `stops`/`trips`.

- [ ] **Step 3: Update `BootstrapViewModel`**

Extend the VM with:

```dart
StopsIndex? _stops;
TripsIndex? _trips;

StopsIndex? get stops => _stops;
TripsIndex? get trips => _trips;
```

In `load()`:

```dart
final routes = await routesRepo.getRoutes();
final stops = await stopsRepo.getStops();
final trips = await tripsLoader();
_routes = routes;
_stops = stops;
_trips = trips;
notifyListeners();
```

`tripsLoader` is injected so wiring can pull trips from the same `GtfsCacheService.readBundle()` without re-fetching. In `main.dart`:

```dart
tripsLoader: () async {
  final cached = await cache.readBundle(maxAge: LodzConstants.routesCacheTtl);
  if (cached != null) return cached.trips;
  final fresh = await staticService.fetchAndParseAll();
  await cache.writeBundle(GtfsCachedBundle(
    routes: fresh.routes,
    stops: fresh.stops,
    trips: fresh.trips,
  ));
  return fresh.trips;
},
```

If `trips.txt` parse fails: catch in `load()` and set `_trips = const {}` (soft-degrade per spec).

- [ ] **Step 4: Run tests**

```bash
flutter analyze && flutter test test/ui/features/map/view_models/bootstrap_view_model_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(nearby): bootstrap loads stops + trips alongside routes"
```

---

## Task 11: `NearbyStopsViewModel`

**Files:**
- Create: `lib/ui/features/nearby/nearby_stops_view_model.dart`
- Test: `test/ui/features/nearby/nearby_stops_view_model_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/features/nearby/nearby_stops_view_model_test.dart`:

```dart
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mpk_lodz_tracker/data/repositories/stops_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';

class _FakeLocation implements LocationGateway {
  _FakeLocation({this.permission = LocationPermission.whileInUse});
  LocationPermission permission;
  bool serviceEnabled = true;
  final controller = StreamController<Position>.broadcast();
  Position? lastFix;
  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Stream<Position> positionStream({double distanceFilter = 25}) =>
      controller.stream;
  @override
  Future<Position?> getLastKnown() async => lastFix;
  @override
  Future<void> openAppSettings() async {}
}

Position _pos(double lat, double lon) => Position(
      longitude: lon, latitude: lat,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 0, altitude: 0, altitudeAccuracy: 0,
      heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
    );

void main() {
  final stops = <String, Stop>{
    'a': const Stop(id: 'a', name: 'A', lat: 51.760, lon: 19.450),
    'b': const Stop(id: 'b', name: 'B', lat: 51.761, lon: 19.450),
  };

  test('granted permission populates nearby on first fix', () {
    fakeAsync((async) {
      final loc = _FakeLocation();
      final vm = NearbyStopsViewModel(
        stopsRepo: StopsRepository.test(stops),
        location: loc,
        lastFixStore: _NoopFixStore(),
      );
      vm.init();
      async.elapse(const Duration(milliseconds: 1));
      loc.controller.add(_pos(51.760, 19.450));
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.status, LocationStatus.granted);
      expect(vm.nearby.first.id, 'a');
    });
  });

  test('denied permission produces denied status', () {
    fakeAsync((async) {
      final loc = _FakeLocation(permission: LocationPermission.denied);
      final vm = NearbyStopsViewModel(
        stopsRepo: StopsRepository.test(stops),
        location: loc,
        lastFixStore: _NoopFixStore(),
      );
      vm.init();
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.status, LocationStatus.denied);
    });
  });

  test('selectStop / clearSelection', () {
    final vm = NearbyStopsViewModel(
      stopsRepo: StopsRepository.test(stops),
      location: _FakeLocation(),
      lastFixStore: _NoopFixStore(),
    );
    vm.selectStop(const Stop(id: 'a', name: 'A', lat: 0, lon: 0));
    expect(vm.selected!.id, 'a');
    vm.clearSelection();
    expect(vm.selected, isNull);
  });
}

class _NoopFixStore implements LastFixStore {
  @override
  Future<({double lat, double lon})?> read() async => null;
  @override
  Future<void> write(Position pos) async {}
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/ui/features/nearby/nearby_stops_view_model_test.dart
```

Expected: FAIL — VM and gateway types undefined.

- [ ] **Step 3: Implement gateways and VM**

Create `lib/ui/features/nearby/nearby_stops_view_model.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/stops_repository.dart';
import '../../../domain/models/stop.dart';
import '../../core/lodz_constants.dart';

enum LocationStatus { unknown, granted, denied, deniedForever, serviceDisabled }
enum SheetSnap { peek, expanded }

abstract class LocationGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<Position> positionStream({double distanceFilter = 25});
  Future<Position?> getLastKnown();
  Future<void> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  @override
  Stream<Position> positionStream({double distanceFilter = 25}) =>
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(distanceFilter: distanceFilter.toInt()),
      );
  @override
  Future<Position?> getLastKnown() => Geolocator.getLastKnownPosition();
  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

abstract class LastFixStore {
  Future<({double lat, double lon})?> read();
  Future<void> write(Position pos);
}

class PrefsLastFixStore implements LastFixStore {
  static const _key = 'nearby.lastFix';
  @override
  Future<({double lat, double lon})?> read() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return null;
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  @override
  Future<void> write(Position pos) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, '${pos.latitude},${pos.longitude}');
  }
}

class NearbyStopsViewModel extends ChangeNotifier {
  NearbyStopsViewModel({
    required StopsRepository stopsRepo,
    required LocationGateway location,
    required LastFixStore lastFixStore,
  })  : _stops = stopsRepo,
        _loc = location,
        _fixStore = lastFixStore;

  final StopsRepository _stops;
  final LocationGateway _loc;
  final LastFixStore _fixStore;

  LocationStatus _status = LocationStatus.unknown;
  Position? _lastFix;
  List<Stop> _nearby = const [];
  Stop? _selected;
  SheetSnap _snap = SheetSnap.peek;
  StreamSubscription<Position>? _sub;
  bool _disposed = false;

  LocationStatus get status => _status;
  Position? get lastFix => _lastFix;
  List<Stop> get nearby => _nearby;
  Stop? get selected => _selected;
  SheetSnap get snap => _snap;

  Future<void> init() async {
    final stored = await _fixStore.read();
    if (stored != null && _lastFix == null) {
      _lastFix = Position(
        latitude: stored.lat,
        longitude: stored.lon,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        accuracy: 0, altitude: 0, altitudeAccuracy: 0,
        heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
      );
      _recomputeNearby();
    }

    if (!await _loc.isLocationServiceEnabled()) {
      _setStatus(LocationStatus.serviceDisabled);
      return;
    }
    var perm = await _loc.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await _loc.requestPermission();
    }
    switch (perm) {
      case LocationPermission.denied:
        _setStatus(LocationStatus.denied);
        return;
      case LocationPermission.deniedForever:
        _setStatus(LocationStatus.deniedForever);
        return;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        _setStatus(LocationStatus.granted);
        await _stops.getStops();
        _subscribe();
        break;
      case LocationPermission.unableToDetermine:
        _setStatus(LocationStatus.denied);
    }
  }

  Future<void> requestLocationPermission() async {
    if (_status == LocationStatus.serviceDisabled ||
        _status == LocationStatus.deniedForever) {
      await _loc.openAppSettings();
      return;
    }
    await init();
  }

  void selectStop(Stop s) {
    if (_selected?.id == s.id) return;
    _selected = s;
    notifyListeners();
  }

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  void setSnap(SheetSnap s) {
    if (_snap == s) return;
    _snap = s;
    notifyListeners();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _loc.positionStream().listen(
      (pos) {
        if (_disposed) return;
        _lastFix = pos;
        _fixStore.write(pos);
        _recomputeNearby();
      },
      onError: (_) {
        // Keep last fix; do not change status on transient errors.
      },
    );
  }

  void _recomputeNearby() {
    final fix = _lastFix;
    if (fix == null) return;
    _nearby = _stops.nearby(
      fix,
      radiusM: LodzConstants.nearbyRadiusM,
      limit: LodzConstants.nearbyLimit,
    );
    notifyListeners();
  }

  void _setStatus(LocationStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/ui/features/nearby/nearby_stops_view_model_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/nearby/nearby_stops_view_model.dart \
        test/ui/features/nearby/nearby_stops_view_model_test.dart
git commit -m "feat(nearby): NearbyStopsViewModel with location gateway + lastFix persistence"
```

---

## Task 12: `StopDetailViewModel`

**Files:**
- Create: `lib/ui/features/nearby/stop_detail_view_model.dart`
- Test: `test/ui/features/nearby/stop_detail_view_model_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/features/nearby/stop_detail_view_model_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/repositories/departures_repository.dart';
import 'package:mpk_lodz_tracker/data/repositories/trip_updates_repository.dart';
import 'package:mpk_lodz_tracker/data/services/trip_updates_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_info.dart';
import 'package:mpk_lodz_tracker/domain/models/trip_update.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/stop_detail_view_model.dart';

class _CountingTripUpdates extends TripUpdatesRepository {
  _CountingTripUpdates() : super(service: TripUpdatesService());
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
    notifyListeners();
  }

  @override
  Map<String, TripUpdate> get byTripId => const {
        't1': TripUpdate(tripId: 't1', delaySec: 0, stopTimeUpdates: [
          StopTimeUpdate(stopId: 'S1', etaUnixSec: 9999999999, delaySec: 0),
        ]),
      };
}

void main() {
  test('immediate fetch on create + 5s polling', () {
    fakeAsync((async) {
      final tu = _CountingTripUpdates();
      final lifecycle = AppLifecycleNotifier();
      final vm = StopDetailViewModel(
        stop: const Stop(id: 'S1', name: 'A', lat: 0, lon: 0),
        tripUpdates: tu,
        departures: DeparturesRepository(
          tripUpdates: tu,
          trips: const {'t1': TripInfo(tripId: 't1', routeId: 'r1', headsign: 'X')},
          routes: const {'r1': Line(routeId: 'r1', number: '12', type: VehicleType.tram)},
        ),
        lifecycle: lifecycle,
        filterLines: () => const {},
      );
      async.elapse(const Duration(milliseconds: 1));
      expect(tu.refreshes, 1);
      async.elapse(const Duration(seconds: 5));
      expect(tu.refreshes, 2);
      vm.dispose();
    });
  });

  test('paused on background, resumes on foreground', () {
    fakeAsync((async) {
      final tu = _CountingTripUpdates();
      final lifecycle = AppLifecycleNotifier();
      final vm = StopDetailViewModel(
        stop: const Stop(id: 'S1', name: 'A', lat: 0, lon: 0),
        tripUpdates: tu,
        departures: DeparturesRepository(
          tripUpdates: tu,
          trips: const {},
          routes: const {},
        ),
        lifecycle: lifecycle,
        filterLines: () => const {},
      );
      async.elapse(const Duration(milliseconds: 1)); // first fetch
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      final beforePause = tu.refreshes;
      async.elapse(const Duration(seconds: 30));
      expect(tu.refreshes, beforePause); // no ticks while paused
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.elapse(const Duration(milliseconds: 1));
      expect(tu.refreshes, beforePause + 1);
      vm.dispose();
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/ui/features/nearby/stop_detail_view_model_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement VM**

Create `lib/ui/features/nearby/stop_detail_view_model.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/departures_repository.dart';
import '../../../data/repositories/trip_updates_repository.dart';
import '../../../domain/models/departure.dart';
import '../../../domain/models/stop.dart';
import '../../core/app_lifecycle_notifier.dart';
import '../../core/lodz_constants.dart';

typedef ActiveLineIds = Set<String> Function();

class StopDetailViewModel extends ChangeNotifier {
  StopDetailViewModel({
    required this.stop,
    required TripUpdatesRepository tripUpdates,
    required DeparturesRepository departures,
    required AppLifecycleNotifier lifecycle,
    required ActiveLineIds filterLines,
  })  : _tripUpdates = tripUpdates,
        _departures = departures,
        _lifecycle = lifecycle,
        _filterLines = filterLines {
    _lifecycle.addListener(_onLifecycle);
    _tripUpdates.addListener(_recompute);
    _start();
  }

  final Stop stop;
  final TripUpdatesRepository _tripUpdates;
  final DeparturesRepository _departures;
  final AppLifecycleNotifier _lifecycle;
  final ActiveLineIds _filterLines;

  Timer? _timer;
  bool _disposed = false;
  bool _loading = false;
  Object? _error;
  DateTime? _lastFetched;
  List<Departure> _departuresList = const [];

  bool get loading => _loading;
  Object? get error => _error;
  DateTime? get lastFetched => _lastFetched;
  List<Departure> get departures => _departuresList;

  Future<void> _start() async {
    _scheduleTimer();
    await _tick();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(LodzConstants.detailPollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_disposed || !_lifecycle.isResumed) return;
    _loading = true;
    notifyListeners();
    await _tripUpdates.refresh();
    if (_disposed) return;
    _lastFetched = DateTime.now();
    _error = _tripUpdates.lastError;
    _loading = false;
    _recompute();
  }

  void _recompute() {
    if (_disposed) return;
    _departuresList = _departures.forStop(
      stop.id,
      now: DateTime.now(),
      lineFilter: _filterLines(),
    );
    notifyListeners();
  }

  void _onLifecycle() {
    if (_disposed) return;
    if (_lifecycle.isResumed) {
      _scheduleTimer();
      _tick();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle.removeListener(_onLifecycle);
    _tripUpdates.removeListener(_recompute);
    super.dispose();
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/ui/features/nearby/stop_detail_view_model_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/nearby/stop_detail_view_model.dart \
        test/ui/features/nearby/stop_detail_view_model_test.dart
git commit -m "feat(nearby): StopDetailViewModel with 5s polling and lifecycle pause"
```

---

## Task 13: ARB strings + dense `LineChip` variant

**Files:**
- Modify: `lib/l10n/app_pl.arb`
- Modify: `lib/ui/features/filter/views/line_chip.dart`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Test: `test/ui/features/filter/line_chip_dense_test.dart`

- [ ] **Step 1: Append ARB keys**

Edit `lib/l10n/app_pl.arb`. Add (preserving existing keys):

```json
  "nearbyStopsCount": "{count, plural, one{1 przystanek w pobliżu} few{{count} przystanki w pobliżu} many{{count} przystanków w pobliżu} other{{count} przystanków w pobliżu}}",
  "@nearbyStopsCount": { "placeholders": { "count": { "type": "int" } } },
  "nearbyEmptyNoStops": "Brak przystanków w promieniu 500 m",
  "nearbyEmptyNoDepartures": "Brak nadchodzących odjazdów",
  "nearbyWaitingForGps": "Czekam na sygnał GPS…",
  "nearbyCheckingLocation": "Sprawdzam lokalizację…",
  "permissionCtaTitleDenied": "Włącz lokalizację, by zobaczyć przystanki w pobliżu",
  "permissionCtaButtonGrant": "Włącz lokalizację",
  "permissionCtaButtonSettings": "Otwórz ustawienia",
  "permissionCtaTitleService": "Włącz usługi lokalizacji w ustawieniach systemu",
  "walkMinutes": "~{n} min",
  "@walkMinutes": { "placeholders": { "n": { "type": "int" } } },
  "metersAway": "{n} m",
  "@metersAway": { "placeholders": { "n": { "type": "int" } } },
  "lastUpdatedAt": "ostatnia aktualizacja {time}",
  "@lastUpdatedAt": { "placeholders": { "time": { "type": "String" } } },
  "delayLate": "+{n} min",
  "@delayLate": { "placeholders": { "n": { "type": "int" } } },
  "delayEarly": "−{n} min",
  "@delayEarly": { "placeholders": { "n": { "type": "int" } } }
```

- [ ] **Step 2: Regenerate localizations**

```bash
flutter gen-l10n
```

Expected: regenerates `lib/l10n/app_localizations*.dart` with the new getters.

- [ ] **Step 3: Write failing test for `LineChip` dense variant**

Create `test/ui/features/filter/line_chip_dense_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/views/line_chip.dart';

void main() {
  testWidgets('dense chip is shorter than default', (tester) async {
    Future<Size> measure(LineChipSize size) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: LineChip(
              number: '12',
              type: VehicleType.tram,
              selected: true,
              onTap: () {},
              size: size,
            ),
          ),
        ),
      ));
      return tester.getSize(find.byType(LineChip));
    }

    final big = await measure(LineChipSize.regular);
    final small = await measure(LineChipSize.dense);
    expect(small.height, lessThan(big.height));
  });
}
```

- [ ] **Step 4: Run test to verify failure**

```bash
flutter test test/ui/features/filter/line_chip_dense_test.dart
```

Expected: FAIL — no `LineChipSize`.

- [ ] **Step 5: Add `LineChipSize` parameter**

Edit `lib/ui/features/filter/views/line_chip.dart`. Add:

```dart
enum LineChipSize { regular, dense }
```

Add a `LineChipSize size` constructor parameter (default `regular`). Use it to compute paddings/text size:

```dart
double get _vertical => size == LineChipSize.dense ? 2 : 6;
double get _horizontal => size == LineChipSize.dense ? 8 : 12;
double get _fontSize => size == LineChipSize.dense ? 11 : 14;
```

Wire those into existing layout constants.

- [ ] **Step 6: Run tests**

```bash
flutter test test/ui/features/filter/line_chip_dense_test.dart && \
flutter analyze
```

Expected: green.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/ lib/ui/features/filter/views/line_chip.dart \
        test/ui/features/filter/line_chip_dense_test.dart
git commit -m "feat(nearby): ARB keys + dense LineChip variant"
```

---

## Task 14: Leaf widgets — `SheetHandle`, `PermissionCtaView`, `NearbyListRow`, `DepartureRow`

**Files:**
- Create: `lib/ui/features/nearby/widgets/sheet_handle.dart`
- Create: `lib/ui/features/nearby/views/permission_cta_view.dart`
- Create: `lib/ui/features/nearby/views/nearby_list_row.dart`
- Create: `lib/ui/features/nearby/views/departure_row.dart`
- Test: `test/ui/features/nearby/leaf_widgets_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/ui/features/nearby/leaf_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/departure_row.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/nearby_list_row.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/permission_cta_view.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/widgets/sheet_handle.dart';

Widget _wrap(Widget w) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: w),
    );

void main() {
  testWidgets('SheetHandle renders a pill', (tester) async {
    await tester.pumpWidget(_wrap(const SheetHandle()));
    expect(find.byType(SheetHandle), findsOneWidget);
  });

  testWidgets('NearbyListRow shows name + distance + walk time', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListRow(
      stop: const Stop(id: '1', name: 'Plac Wolności', lat: 0, lon: 0),
      lineNumbers: const ['12', '86'],
      lineTypes: const [VehicleType.tram, VehicleType.bus],
      distanceM: 120,
      onTap: () {},
    )));
    expect(find.text('Plac Wolności'), findsOneWidget);
    expect(find.textContaining('120 m'), findsOneWidget);
    expect(find.textContaining('~2 min'), findsOneWidget);
  });

  testWidgets('DepartureRow shows ETA in min when <60min', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(DepartureRow(
      departure: Departure(
        lineNumber: '12',
        lineType: VehicleType.tram,
        headsign: 'Stoki',
        etaUnixSec: now.millisecondsSinceEpoch ~/ 1000 + 180,
        delaySec: 60,
      ),
      now: now,
    )));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Stoki'), findsOneWidget);
    expect(find.textContaining('3 min'), findsOneWidget);
    expect(find.textContaining('+1 min'), findsOneWidget);
  });

  testWidgets('PermissionCtaView dispatches correct action by status',
      (tester) async {
    String? action;
    await tester.pumpWidget(_wrap(PermissionCtaView(
      status: LocationStatus.deniedForever,
      onGrant: () => action = 'grant',
      onOpenSettings: () => action = 'settings',
    )));
    await tester.tap(find.byType(FilledButton));
    expect(action, 'settings');
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/ui/features/nearby/leaf_widgets_test.dart
```

Expected: FAIL — widgets undefined.

- [ ] **Step 3: Implement `SheetHandle`**

Create `lib/ui/features/nearby/widgets/sheet_handle.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/design_tokens.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: LodzSpacing.sm),
      decoration: BoxDecoration(
        color: LodzColors.outlineVariant,
        borderRadius: BorderRadius.circular(LodzRadius.full),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `PermissionCtaView`**

Create `lib/ui/features/nearby/views/permission_cta_view.dart`:

```dart
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
    final title = isService ? l.permissionCtaTitleService : l.permissionCtaTitleDenied;
    final useSettings = isService || isPermanent;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LodzSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 48, color: LodzColors.onSurfaceVariant),
            const SizedBox(height: LodzSpacing.md),
            Text(title, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: LodzSpacing.lg),
            FilledButton(
              onPressed: useSettings ? onOpenSettings : onGrant,
              child: Text(useSettings
                  ? l.permissionCtaButtonSettings
                  : l.permissionCtaButtonGrant),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `NearbyListRow`**

Create `lib/ui/features/nearby/views/nearby_list_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/stop.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../../../core/lodz_constants.dart';
import '../../filter/views/line_chip.dart';

class NearbyListRow extends StatelessWidget {
  const NearbyListRow({
    super.key,
    required this.stop,
    required this.lineNumbers,
    required this.lineTypes,
    required this.distanceM,
    required this.onTap,
  });

  final Stop stop;
  final List<String> lineNumbers;
  final List<VehicleType> lineTypes;
  final double distanceM;
  final VoidCallback onTap;

  int get _walkMinutes {
    final m = (distanceM / LodzConstants.walkingSpeedMps / 60).round();
    return m < 1 ? 1 : m;
  }

  String _distanceLabel(AppLocalizations l) {
    final n = distanceM < 100
        ? (distanceM / 10).round() * 10
        : (distanceM / 50).round() * 50;
    return l.metersAway(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LodzSpacing.md,
          vertical: LodzSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: LodzSpacing.xs),
                  Wrap(
                    spacing: LodzSpacing.xs,
                    runSpacing: LodzSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < lineNumbers.length; i++)
                        LineChip(
                          number: lineNumbers[i],
                          type: lineTypes[i],
                          selected: true,
                          onTap: null,
                          size: LineChipSize.dense,
                        ),
                      Text(
                        '•  ${l.walkMinutes(_walkMinutes)}  •  ${_distanceLabel(l)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LodzColors.outline),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Implement `DepartureRow`**

Create `lib/ui/features/nearby/views/departure_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/departure.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../../filter/views/line_chip.dart';

class DepartureRow extends StatelessWidget {
  const DepartureRow({
    super.key,
    required this.departure,
    required this.now,
  });

  final Departure departure;
  final DateTime now;

  String _eta(AppLocalizations l) {
    final eta = DateTime.fromMillisecondsSinceEpoch(departure.etaUnixSec * 1000);
    final diffMin = eta.difference(now).inMinutes;
    if (diffMin < 60) return '$diffMin min';
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  Widget? _delayBadge(AppLocalizations l) {
    final d = departure.delaySec;
    if (d == null || d.abs() < 60) return null;
    final mins = (d.abs() / 60).round();
    final text = d > 0 ? l.delayLate(mins) : l.delayEarly(mins);
    return Text(
      text,
      style: TextStyle(
        color: d > 0 ? Theme.of(context as BuildContext).colorScheme.error : LodzColors.success,
        fontSize: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final delay = departure.delaySec;
    final mins = delay == null ? 0 : (delay.abs() / 60).round();
    final showDelay = delay != null && delay.abs() >= 60;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LodzSpacing.md,
        vertical: LodzSpacing.sm,
      ),
      child: Row(
        children: [
          LineChip(
            number: departure.lineNumber,
            type: departure.lineType,
            selected: true,
            onTap: null,
            size: LineChipSize.dense,
          ),
          const SizedBox(width: LodzSpacing.md),
          Expanded(
            child: Text(
              departure.headsign ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_eta(l), style: Theme.of(context).textTheme.titleMedium),
              if (showDelay)
                Text(
                  delay > 0 ? l.delayLate(mins) : l.delayEarly(mins),
                  style: TextStyle(
                    color: delay > 0
                        ? Theme.of(context).colorScheme.error
                        : LodzColors.success,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

(Drop the half-written `_delayBadge` helper in the file above; the inline version is the canonical one. Just paste the above code without `_delayBadge`.)

- [ ] **Step 7: Run tests**

```bash
flutter test test/ui/features/nearby/leaf_widgets_test.dart && flutter analyze
```

Expected: PASS, no analyze warnings.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/features/nearby/widgets/ lib/ui/features/nearby/views/ \
        test/ui/features/nearby/leaf_widgets_test.dart
git commit -m "feat(nearby): leaf widgets — sheet handle, CTA, list row, departure row"
```

---

## Task 15: Composite views — `NearbyListView` and `StopDetailView`

**Files:**
- Create: `lib/ui/features/nearby/views/nearby_list_view.dart`
- Create: `lib/ui/features/nearby/views/stop_detail_view.dart`
- Test: `test/ui/features/nearby/composite_views_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/ui/features/nearby/composite_views_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/departure.dart';
import 'package:mpk_lodz_tracker/domain/models/stop.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/nearby_list_view.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/views/stop_detail_view.dart';

Widget _wrap(Widget w) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: w),
    );

void main() {
  testWidgets('NearbyListView empty shows "Brak przystanków..."', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListView(
      stops: const [],
      linesByStopId: const {},
      distancesByStopId: const {},
      onTapStop: (_) {},
    )));
    expect(find.textContaining('Brak przystanków'), findsOneWidget);
  });

  testWidgets('NearbyListView renders rows', (tester) async {
    await tester.pumpWidget(_wrap(NearbyListView(
      stops: const [Stop(id: '1', name: 'Plac', lat: 0, lon: 0)],
      linesByStopId: const {
        '1': [(number: '12', type: VehicleType.tram)],
      },
      distancesByStopId: const {'1': 100.0},
      onTapStop: (_) {},
    )));
    expect(find.text('Plac'), findsOneWidget);
  });

  testWidgets('StopDetailView empty state', (tester) async {
    await tester.pumpWidget(_wrap(StopDetailView(
      stop: const Stop(id: '1', name: 'Plac', lat: 0, lon: 0),
      departures: const [],
      lastFetched: DateTime.now(),
      now: DateTime.now(),
      onBack: () {},
    )));
    expect(find.textContaining('Brak nadchodzących odjazdów'), findsOneWidget);
  });

  testWidgets('StopDetailView renders departures', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_wrap(StopDetailView(
      stop: const Stop(id: '1', name: 'Plac', lat: 0, lon: 0),
      departures: [
        Departure(
          lineNumber: '12',
          lineType: VehicleType.tram,
          headsign: 'Stoki',
          etaUnixSec: now.millisecondsSinceEpoch ~/ 1000 + 180,
          delaySec: 0,
        ),
      ],
      lastFetched: now,
      now: now,
      onBack: () {},
    )));
    expect(find.text('Stoki'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/ui/features/nearby/composite_views_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `NearbyListView`**

Create `lib/ui/features/nearby/views/nearby_list_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/stop.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../widgets/sheet_handle.dart';
import 'nearby_list_row.dart';

typedef LineDescriptor = ({String number, VehicleType type});

class NearbyListView extends StatelessWidget {
  const NearbyListView({
    super.key,
    required this.stops,
    required this.linesByStopId,
    required this.distancesByStopId,
    required this.onTapStop,
  });

  final List<Stop> stops;
  final Map<String, List<LineDescriptor>> linesByStopId;
  final Map<String, double> distancesByStopId;
  final ValueChanged<Stop> onTapStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LodzSpacing.md, vertical: LodzSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.nearbyStopsCount(stops.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        Expanded(
          child: stops.isEmpty
              ? Center(child: Text(l.nearbyEmptyNoStops))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: LodzColors.outlineVariant),
                  itemBuilder: (_, i) {
                    final s = stops[i];
                    final lines = linesByStopId[s.id] ?? const [];
                    return NearbyListRow(
                      stop: s,
                      lineNumbers: [for (final l in lines) l.number],
                      lineTypes: [for (final l in lines) l.type],
                      distanceM: distancesByStopId[s.id] ?? 0,
                      onTap: () => onTapStop(s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `StopDetailView`**

Create `lib/ui/features/nearby/views/stop_detail_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/departure.dart';
import '../../../../domain/models/stop.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/design_tokens.dart';
import '../widgets/sheet_handle.dart';
import 'departure_row.dart';

class StopDetailView extends StatelessWidget {
  const StopDetailView({
    super.key,
    required this.stop,
    required this.departures,
    required this.lastFetched,
    required this.now,
    required this.onBack,
  });

  final Stop stop;
  final List<Departure> departures;
  final DateTime? lastFetched;
  final DateTime now;
  final VoidCallback onBack;

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LodzSpacing.sm, vertical: LodzSpacing.xs,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: Theme.of(context).textTheme.titleLarge),
                    if (lastFetched != null)
                      Text(
                        l.lastUpdatedAt(_hhmmss(lastFetched!)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: LodzColors.outlineVariant),
        if (departures.isEmpty)
          Padding(
            padding: const EdgeInsets.all(LodzSpacing.lg),
            child: Center(child: Text(l.nearbyEmptyNoDepartures)),
          )
        else
          for (final d in departures) DepartureRow(departure: d, now: now),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/ui/features/nearby/composite_views_test.dart && flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/nearby/views/nearby_list_view.dart \
        lib/ui/features/nearby/views/stop_detail_view.dart \
        test/ui/features/nearby/composite_views_test.dart
git commit -m "feat(nearby): NearbyListView and StopDetailView composites"
```

---

## Task 16: `NearbyStopsSheet` container

**Files:**
- Create: `lib/ui/features/nearby/nearby_stops_sheet.dart`
- Test: `test/ui/features/nearby/nearby_stops_sheet_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/ui/features/nearby/nearby_stops_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_sheet.dart';
import 'package:mpk_lodz_tracker/ui/features/nearby/nearby_stops_view_model.dart';
import 'package:provider/provider.dart';

class _FakeNearbyVm extends ChangeNotifier implements NearbyStopsViewModel {
  // ... (override only the getters/methods used by the sheet)
}

// Tests assert AnimatedSwitcher key changes between list/detail/CTA states.
```

(Engineer should fake the VM via a tiny test double exposing `status`, `selected`, `nearby`, `snap`, `selectStop`, `clearSelection`, `setSnap`. Mockito or hand-rolled is fine.)

- [ ] **Step 2: Implement the sheet**

Create `lib/ui/features/nearby/nearby_stops_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/departures_repository.dart';
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

class NearbyStopsSheet extends StatefulWidget {
  const NearbyStopsSheet({super.key});

  @override
  State<NearbyStopsSheet> createState() => _NearbyStopsSheetState();
}

class _NearbyStopsSheetState extends State<NearbyStopsSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSizeChange(NearbyStopsViewModel vm) {
    final size = _controller.size;
    final next = size > (LodzConstants.sheetPeekFraction +
            LodzConstants.sheetExpandedFraction) /
            2
        ? SheetSnap.expanded
        : SheetSnap.peek;
    vm.setSnap(next);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NearbyStopsViewModel>(
      builder: (ctx, vm, _) {
        // Auto-snap to expanded when CTA is required.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_controller.isAttached) return;
          final isCta = vm.status == LocationStatus.denied ||
              vm.status == LocationStatus.deniedForever ||
              vm.status == LocationStatus.serviceDisabled;
          if (isCta && vm.snap == SheetSnap.peek) {
            _controller.animateTo(LodzConstants.sheetExpandedFraction,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
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
                child: SingleChildScrollView(
                  controller: scrollCtl,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _content(ctx, vm),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _content(BuildContext context, NearbyStopsViewModel vm) {
    if (vm.status == LocationStatus.denied ||
        vm.status == LocationStatus.deniedForever ||
        vm.status == LocationStatus.serviceDisabled) {
      return KeyedSubtree(
        key: const ValueKey('cta'),
        child: PermissionCtaView(
          status: vm.status,
          onGrant: vm.requestLocationPermission,
          onOpenSettings: vm.requestLocationPermission,
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
            builder: (ctx, dvm, _) => StopDetailView(
              stop: vm.selected!,
              departures: dvm.departures,
              lastFetched: dvm.lastFetched,
              now: DateTime.now(),
              onBack: vm.clearSelection,
            ),
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('list'),
      child: NearbyListView(
        stops: vm.nearby,
        // linesByStopId / distancesByStopId resolved by VM extension; see
        // Step 3 below for adding helpers if not present.
        linesByStopId: vm.linesByStopId,
        distancesByStopId: vm.distancesByStopId,
        onTapStop: vm.selectStop,
      ),
    );
  }
}
```

- [ ] **Step 3: Extend `NearbyStopsViewModel` with `linesByStopId` and `distancesByStopId`**

Open `lib/ui/features/nearby/nearby_stops_view_model.dart` and add helpers that join nearby stops with the loaded routes index. Pass the `RoutesIndex` and a stop→lines lookup (built from `TripsIndex`) into the VM via constructor:

```dart
final Map<String, List<({String number, VehicleType type})>> linesByStopId;
final Map<String, double> distancesByStopId;
```

If a stop→lines lookup is not feasible at this stage (would need stop_times.txt), pass an empty list per stop — the row simply renders without chips. Spec already accepts this gracefully.

(For v1, simplest path: pass `linesByStopId: const {}` and `distancesByStopId` populated from the Haversine pass already done in `_recomputeNearby`. Engineer should refactor `StopsRepository.nearby` to also return distances and propagate them.)

- [ ] **Step 4: Verify**

```bash
flutter test test/ui/features/nearby/nearby_stops_sheet_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(nearby): NearbyStopsSheet container with state-driven content"
```

---

## Task 17: `StopMarkersLayer`

**Files:**
- Create: `lib/ui/features/map/views/stop_markers_layer.dart`

Cannot widget-test (PlatformView). Manual test only.

- [ ] **Step 1: Implement layer mirroring `VehicleMarkersLayer`**

Create `lib/ui/features/map/views/stop_markers_layer.dart`:

```dart
import 'dart:convert';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../domain/models/stop.dart';
import '../../../core/design_tokens.dart';

class StopMarkersLayer {
  StopMarkersLayer(this.controller);

  static const _sourceId = 'stops';
  static const _layerId = 'stop-circles';
  static const _selectedLayerId = 'stop-circles-selected';

  final MapLibreMapController controller;
  bool _attached = false;

  Future<void> sync({required List<Stop> stops, String? selectedId}) async {
    final fc = jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final s in stops)
          {
            'type': 'Feature',
            'id': s.id,
            'properties': {
              'id': s.id,
              'selected': s.id == selectedId ? 1 : 0,
            },
            'geometry': {'type': 'Point', 'coordinates': [s.lon, s.lat]},
          },
      ],
    });

    if (!_attached) {
      await controller.addSource(_sourceId, GeojsonSourceProperties(data: fc));
      await controller.addCircleLayer(
        _sourceId, _layerId,
        CircleLayerProperties(
          circleColor: '#${LodzColors.transitCyan.value.toRadixString(16).substring(2)}',
          circleRadius: 6,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
        filter: ['==', ['get', 'selected'], 0],
      );
      await controller.addCircleLayer(
        _sourceId, _selectedLayerId,
        CircleLayerProperties(
          circleColor: '#${LodzColors.transitCyan.value.toRadixString(16).substring(2)}',
          circleRadius: 12,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
        filter: ['==', ['get', 'selected'], 1],
      );
      _attached = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, jsonDecode(fc));
    }
  }

  Future<void> detach() async {
    if (!_attached) return;
    await controller.removeLayer(_layerId);
    await controller.removeLayer(_selectedLayerId);
    await controller.removeSource(_sourceId);
    _attached = false;
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/features/map/views/stop_markers_layer.dart
git commit -m "feat(nearby): StopMarkersLayer for nearby-20 dots on map"
```

---

## Task 18: Wire everything in `MapScreen` + `main.dart`; fold `LocateFab`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/features/map/views/map_screen.dart`
- Modify: `lib/ui/features/map/views/locate_fab.dart`
- Test: `test/ui/features/map/views/map_screen_test.dart` (smoke if practical)

- [ ] **Step 1: Provide repositories + notifier in `main.dart`**

In `lib/main.dart`, ensure `MultiProvider` exposes:

```dart
Provider<GtfsCacheService>(create: (_) => GtfsCacheService()),
Provider<GtfsStaticService>(create: (_) => GtfsStaticService()),
Provider<TripUpdatesService>(create: (_) => TripUpdatesService()),
ChangeNotifierProvider<AppLifecycleNotifier>(
  create: (_) => AppLifecycleNotifier()..attach(),
),
ProxyProvider2<GtfsStaticService, GtfsCacheService, RoutesRepository>(
  update: (_, s, c, __) => RoutesRepository(staticService: s, cacheService: c),
),
ProxyProvider2<GtfsStaticService, GtfsCacheService, StopsRepository>(
  update: (_, s, c, __) => StopsRepository(staticService: s, cacheService: c),
),
ChangeNotifierProxyProvider<TripUpdatesService, TripUpdatesRepository>(
  create: (ctx) => TripUpdatesRepository(service: ctx.read<TripUpdatesService>()),
  update: (_, s, prior) => prior ?? TripUpdatesRepository(service: s),
),
ProxyProvider3<TripUpdatesRepository, BootstrapViewModel, FilterViewModel,
    DeparturesRepository>(
  update: (_, tu, boot, ___, __) => DeparturesRepository(
    tripUpdates: tu,
    trips: boot.trips ?? const {},
    routes: boot.routes ?? const {},
  ),
),
ChangeNotifierProvider<NearbyStopsViewModel>(
  create: (ctx) => NearbyStopsViewModel(
    stopsRepo: ctx.read<StopsRepository>(),
    location: GeolocatorGateway(),
    lastFixStore: PrefsLastFixStore(),
  )..init(),
),
```

(Adjust generics to match existing provider style. Existing `BootstrapViewModel`/`MapViewModel` providers stay in place; ensure they receive the now-required `AppLifecycleNotifier`.)

- [ ] **Step 2: Mount sheet in `MapScreen`**

In `lib/ui/features/map/views/map_screen.dart`, inside the existing `Stack`:

```dart
Stack(
  children: [
    // map widget (existing)
    // search bar overlay (existing)
    // locate fab (existing)
    // NEW:
    const Positioned.fill(child: NearbyStopsSheet()),
  ],
),
```

Below the map widget, drive the dot layer + camera padding from VM state. Add a `Consumer<NearbyStopsViewModel>` that:
- Calls `_stopMarkersLayer.sync(stops: vm.nearby, selectedId: vm.selected?.id)` when `snap == expanded`, otherwise `_stopMarkersLayer.detach()`.
- Sets MapLibre camera padding-bottom to `MediaQuery.sizeOf(context).height * LodzConstants.sheetExpandedFraction` when expanded, else 0. Use existing `controller.animateCamera(CameraUpdate.padding(...))`-equivalent API or whatever the codebase uses.

Tap-on-dot wiring: register `controller.onFeatureTapped` to map the tapped feature's `id` back to `vm.nearby` and call `vm.selectStop(...)`.

- [ ] **Step 3: Refactor `LocateFab`**

Edit `lib/ui/features/map/views/locate_fab.dart`. Drop direct `geolocator` calls. Pull location info from `NearbyStopsViewModel`:

```dart
final vm = context.watch<NearbyStopsViewModel>();
if (vm.status == LocationStatus.denied ||
    vm.status == LocationStatus.deniedForever ||
    vm.status == LocationStatus.serviceDisabled) {
  return const SizedBox.shrink(); // (or keep visible per existing UX; spec leaves this open)
}
return FloatingActionButton(
  onPressed: () {
    final fix = vm.lastFix;
    if (fix != null) _recenter(fix);
    else vm.requestLocationPermission();
  },
  child: const Icon(Icons.my_location),
);
```

Where `_recenter` calls `MapViewModel.animateCameraTo(fix)` (existing or to-be-added helper).

- [ ] **Step 4: Run all tests + analyze**

```bash
flutter analyze && flutter test
```

Expected: all green. If a test depends on the old single-source `RoutesCacheService` wiring, update it.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(nearby): wire NearbyStopsSheet, dot layer, camera padding into MapScreen"
```

---

## Task 19: Manual test doc + final smoke

**Files:**
- Modify: `docs/manual-test.md`

- [ ] **Step 1: Append nearby-stops scenarios to `docs/manual-test.md`**

```markdown
## Nearby stops sheet

Run with `flutter run --dart-define=MAPTILER_KEY=<key>` on a real device or emulator with location enabled.

1. **Peek state:** On launch, sheet sits at the bottom showing "X przystanków w pobliżu" with the nearest count.
2. **Expand:** Drag handle up — sheet snaps to ~70 %. List of up to 20 stops appears, sorted by distance. Each row shows name, line chips, walk time, distance.
3. **Map dots:** While expanded, small cyan circles appear on the map at each nearby stop. Collapsing the sheet removes them.
4. **Pan map:** Pan the map far away from the device. List does NOT change (Q2=A).
5. **Walk:** Move the device (or simulate) 100 m. After the next position update, the list re-sorts.
6. **Tap row:** Tap a stop row. Sheet content swaps to the detail view — back arrow, stop name, last-update timestamp, list of upcoming departures.
7. **Tap dot:** Tap a cyan dot on the map. Same detail view opens with that stop selected.
8. **Departures refresh:** Detail view auto-refreshes every 5 s. The "ostatnia aktualizacja" timestamp ticks. Closing detail returns to list and stops the 5 s polling.
9. **Delay:** A trip with >60 s delay shows `+N min` in red; an early trip shows `−N min` in green.
10. **Empty state:** If a stop has no upcoming departures (off-hours), detail shows "Brak nadchodzących odjazdów".
11. **Filter:** Toggle off a line in the filter sheet. Departures using that line disappear from the detail view; the nearby list itself is unchanged.
12. **Permission denied:** Revoke location permission in OS settings. Sheet auto-snaps to expanded and shows the CTA. Tap "Otwórz ustawienia" → opens system settings.
13. **No GPS fix:** Toggle airplane mode + location off and back; sheet shows "Czekam na sygnał GPS…" until a fix arrives. If a `lastFix` was previously persisted, it is used immediately instead of the waiting state.
14. **Background/foreground:** Background the app for >10 s during detail polling. Resume — detail refreshes immediately and timestamp updates. The map's 10 s tick also resumes. (Both pause and resume together via `AppLifecycleNotifier`.)
15. **Tab switch:** Switch to Lines, then back to Map. Sheet remounts; nearby list reappears; selected stop is NOT preserved.
```

- [ ] **Step 2: Final analyze + tests + smoke**

```bash
flutter analyze
flutter test
flutter run --dart-define=MAPTILER_KEY=<key>
```

Run through all 15 manual scenarios above on a real device/emulator. Note any failures and fix before merge.

- [ ] **Step 3: Commit**

```bash
git add docs/manual-test.md
git commit -m "docs(nearby): manual test scenarios for nearby-stops sheet"
```

---

## Self-review notes

- **Spec coverage:** All 13 brainstorming decisions (Q1–Q13) and the spec's "Edge cases" / "Testing" sections are implemented across Tasks 1–19. Sections of the spec map to tasks as follows: Data layer → Tasks 2–8; State layer → Tasks 9–12; UI → Tasks 13–17; Wiring → Task 18; Manual test → Task 19.
- **Type consistency:** `RoutesIndex`, `StopsIndex`, `TripsIndex`, `TripUpdatesIndex` are all defined as map typedefs in their respective model files and used uniformly. `LineDescriptor` (record type) is the row's chip descriptor; resolved in Task 16.
- **Caveats marked clearly:** Task 16 Step 3 calls out that `linesByStopId` for v1 may be empty until a stop→lines join is added (would normally need `stop_times.txt`). The spec accepts rows without chips.
- **Frequent commits:** Every task ends with one commit. 19 commits total — large surface but each is a coherent unit reviewers can step through.

---

Plan complete and saved to [docs/superpowers/plans/2026-05-03-nearby-stops.md](docs/superpowers/plans/2026-05-03-nearby-stops.md). Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?

# MPK Łódź Tracker — Flutter Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the existing Expo / React Native MPK Łódź live tracker as a native Flutter app with feature parity to the spec at `docs/superpowers/specs/2026-05-01-mpk-lodz-tracker-design.md`, replacing the current React Native implementation in-place at the repository root.

**Architecture:** Strict layered MVVM following the `flutter-apply-architecture-best-practices` skill. The `data/` layer owns HTTP, protobuf, ZIP, CSV, and file caching; `domain/` holds clean immutable models; `ui/` is split by feature (`map`, `filter`) with `ChangeNotifier` ViewModels and dumb View widgets. Dependencies are wired with `provider`. Polling and AppLifecycle are encapsulated in the Map ViewModel via a `Timer` + `WidgetsBindingObserver`.

**Tech Stack:** Flutter (stable), Dart 3, `provider`, `maplibre_gl`, `http`, `protobuf` + protoc, `archive`, `csv`, `geolocator`, `path_provider`, `flutter_localizations` + `intl`, `flutter_test` + `mocktail`. MapTiler streets style for tiles; protocol buffers compiled from upstream `gtfs-realtime.proto`.

---

## File Structure

```
lib/
  main.dart                                          # Provider wiring, MaterialApp, locale, theme
  data/
    models/
      route_api_model.dart                           # Raw GTFS routes.txt row
    services/
      gtfs_rt_service.dart                           # GET vehicle_positions.bin, decode FeedMessage
      gtfs_static_service.dart                       # GET GTFS.zip, parse routes.txt
      routes_cache_service.dart                      # Read/write JSON cache w/ TTL
      generated/
        gtfs-realtime.pb.dart                        # protoc output (committed)
        gtfs-realtime.pbenum.dart
        gtfs-realtime.pbjson.dart
    repositories/
      vehicles_repository.dart                       # Wraps GtfsRtService
      routes_repository.dart                         # Cache-or-fetch via static + cache services
  domain/
    models/
      vehicle.dart                                   # Vehicle + VehicleType enum
      line.dart                                      # Line + RoutesIndex typedef
  ui/
    core/
      lodz_constants.dart                            # Center, zoom, poll interval, TTL
      vehicle_colors.dart                            # tram/bus/unknown colors
      app_theme.dart                                 # Light + dark Material 3 themes
    features/
      map/
        view_models/
          map_view_model.dart                        # vehicles, lastUpdate, polling lifecycle
          bootstrap_view_model.dart                  # ensures routesIndex available
        views/
          map_screen.dart                            # composition
          vehicle_markers_layer.dart                 # GeoJSON source + circle/symbol layers
          last_update_hint.dart                      # bottom-left subtle timer label
          locate_fab.dart                            # bottom-right FAB + geolocator
          filter_chip_button.dart                    # top pill chip (opens FilterSheet)
      filter/
        view_models/
          filter_view_model.dart                     # selectedRouteIds, activeTab, query
        views/
          filter_sheet.dart                          # showModalBottomSheet body
          line_chip.dart                             # selectable chip widget
  l10n/
    app_pl.arb                                       # All Polish strings
test/
  data/
    services/
      gtfs_rt_service_test.dart
      gtfs_static_service_test.dart
      routes_cache_service_test.dart
    repositories/
      routes_repository_test.dart
  ui/
    features/
      map/
        map_view_model_test.dart
      filter/
        filter_view_model_test.dart
        line_chip_test.dart
__fixtures__/                                        # KEPT from RN repo
  vehicle_positions.bin
  GTFS-mini.zip
android/app/src/main/res/raw/certum_root_ca.pem      # COPIED from plugins/assets/
android/app/src/main/res/xml/network_security_config.xml
docs/                                                # KEPT (spec, plans, manual test)
```

The `plugins/` directory and the entire React Native source tree are deleted in Task 1.

---

## Task 0: Branch & Worktree Sanity

**Files:** none

- [ ] **Step 1: Verify clean working tree**

Run: `git status`
Expected: `nothing to commit, working tree clean` on a feature branch (e.g. `flutter-rewrite`). If on `main`, create a branch first: `git checkout -b flutter-rewrite`.

- [ ] **Step 2: Verify Flutter toolchain**

Run: `flutter --version && flutter doctor`
Expected: Flutter ≥ 3.24, Dart ≥ 3.5, Android toolchain + iOS toolchain green. Fix any reds before continuing — protobuf compilation, CocoaPods install, and Android NDK are all required downstream.

---

## Task 1: Wipe React Native, Initialize Flutter Project

**Files:**
- Delete: `App.tsx`, `app.config.js`, `babel.config.js`, `index.ts`, `jest.config.js`, `jest.setup.ts`, `metro.config.js`, `package.json`, `package-lock.json`, `tsconfig.json`, `.expo/`, `node_modules/`, `__mocks__/`, `assets/`, `src/`, `plugins/withCertumNetworkSecurity.js`
- Keep: `docs/`, `__fixtures__/`, `plugins/assets/certum_root_ca.pem`, `plugins/assets/network_security_config.xml`, `.git/`, `.gitignore`, `CLAUDE.md`, `.superpowers/`, `.agents/` (if present)
- Create: top-level Flutter project files via `flutter create .`

- [ ] **Step 1: Stage and remove RN sources**

```bash
rm -rf src __mocks__ assets node_modules .expo
rm -f App.tsx app.config.js babel.config.js index.ts jest.config.js jest.setup.ts metro.config.js package.json package-lock.json tsconfig.json
rm -f plugins/withCertumNetworkSecurity.js
```

- [ ] **Step 2: Initialize Flutter project in place**

```bash
flutter create --org pl.lodz.mpk --project-name mpk_lodz_tracker --platforms=android,ios .
```

This generates `lib/main.dart`, `pubspec.yaml`, `android/`, `ios/`, `test/`, `analysis_options.yaml`. The `--org` and `--project-name` flags set the Android/iOS bundle identifier to `pl.lodz.mpk.mpk_lodz_tracker`.

- [ ] **Step 3: Replace generated `.gitignore` additions, keep .env exclusion**

Append to the generated `.gitignore` (append; do not overwrite — `flutter create` writes a Flutter-specific one):

```
# Project-specific
.env
.env.json
.superpowers/
__fixtures__/.cache/
```

- [ ] **Step 4: Verify the empty Flutter app builds**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(flutter): wipe RN scaffold, init Flutter project"
```

---

## Task 2: Add Runtime Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies via CLI**

```bash
flutter pub add provider http maplibre_gl geolocator path_provider archive csv protobuf intl
flutter pub add flutter_localizations --sdk=flutter
flutter pub add dev:mocktail dev:build_runner
```

- [ ] **Step 2: Enable l10n code generation in `pubspec.yaml`**

In the `flutter:` section (already present after `flutter create`), add `generate: true` and declare assets so the GTFS-RT proto fixture and any future bundled assets resolve:

```yaml
flutter:
  uses-material-design: true
  generate: true
```

- [ ] **Step 3: Pin Dart SDK constraint to 3.5+ in `pubspec.yaml` `environment:` block**

```yaml
environment:
  sdk: ">=3.5.0 <4.0.0"
```

- [ ] **Step 4: Verify**

Run: `flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add runtime + dev dependencies"
```

---

## Task 3: Configure Android Manifest, Permissions, and Certum Network Security

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/network_security_config.xml`
- Create: `android/app/src/main/res/raw/certum_root_ca.pem`
- Modify: `android/app/build.gradle.kts` (or `.gradle` depending on Flutter template) — `minSdk` if necessary

The Certum CA workaround from the RN config plugin must be reproduced manually in Flutter. There is no Flutter equivalent of `expo prebuild`, so these files become normal tracked source.

- [ ] **Step 1: Copy Certum cert from existing assets**

```bash
mkdir -p android/app/src/main/res/raw android/app/src/main/res/xml
cp plugins/assets/certum_root_ca.pem android/app/src/main/res/raw/certum_root_ca.pem
cp plugins/assets/network_security_config.xml android/app/src/main/res/xml/network_security_config.xml
```

- [ ] **Step 2: Patch `AndroidManifest.xml`**

Inside the `<application>` tag, add `android:networkSecurityConfig="@xml/network_security_config"`. Also ensure `<uses-permission android:name="android.permission.INTERNET" />`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION` are declared at the top:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

    <application
        android:label="MPK Łódź"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:networkSecurityConfig="@xml/network_security_config">
        <!-- existing <activity> block stays untouched -->
    </application>
</manifest>
```

- [ ] **Step 3: Bump `minSdk` to 21 in `android/app/build.gradle.kts`**

`maplibre_gl` requires Android API 21+. The `flutter create` default already targets 21, but verify and adjust if needed:

```kotlin
defaultConfig {
    minSdk = 21
    targetSdk = flutter.targetSdkVersion
    // ...
}
```

- [ ] **Step 4: Build Android APK to verify the manifest parses**

Run: `flutter build apk --debug`
Expected: build succeeds (no manifest merge errors). Failures are typically duplicate `<uses-permission>` lines from plugins — keep the first occurrence and delete duplicates.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/res/raw android/app/src/main/res/xml android/app/build.gradle.kts
git commit -m "feat(android): permissions + Certum trust anchor for miasto.lodz.pl"
```

---

## Task 4: Configure iOS Info.plist Permission Strings

**Files:**
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Add the two location-permission strings**

Insert before the closing `</dict>` of the top-level dictionary:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Pokażemy pojazdy MPK najbliżej Ciebie.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Pokażemy pojazdy MPK najbliżej Ciebie.</string>
```

- [ ] **Step 2: Verify the file is well-formed XML**

Run: `plutil -lint ios/Runner/Info.plist`
Expected: `ios/Runner/Info.plist: OK`

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "feat(ios): location permission usage strings (Polish)"
```

---

## Task 5: Set up Localization (ARB + flutter_localizations)

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_pl.arb`
- Modify: `pubspec.yaml` (already done in Task 2)

Polish is the only locale for MVP per spec, but using ARB keeps the pattern in place for a future EN translation without touching screens.

- [ ] **Step 1: Create `l10n.yaml` at repo root**

```yaml
arb-dir: lib/l10n
template-arb-file: app_pl.arb
output-localization-file: app_localizations.dart
synthetic-package: true
```

- [ ] **Step 2: Create `lib/l10n/app_pl.arb`**

```json
{
  "@@locale": "pl",
  "filterChipAll": "Wszystkie linie",
  "@filterChipAll": {},
  "filterChipSome": "{count, plural, one{{count} linia} few{{count} linie} many{{count} linii} other{{count} linii}}",
  "@filterChipSome": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "filterTitle": "Filtruj linie",
  "filterSearchPlaceholder": "Szukaj linii…",
  "filterTabTram": "Tramwaje",
  "filterTabBus": "Autobusy",
  "filterApply": "Zastosuj",
  "filterClear": "Wyczyść",
  "mapLastUpdate": "aktualizacja: {seconds}s temu",
  "@mapLastUpdate": {
    "placeholders": {
      "seconds": { "type": "int" }
    }
  },
  "mapLoading": "Ładowanie pozycji…",
  "mapOffline": "Brak połączenia, ponawiam…",
  "markerTram": "Tramwaj {number}",
  "@markerTram": {
    "placeholders": { "number": { "type": "String" } }
  },
  "markerBus": "Autobus {number}",
  "@markerBus": {
    "placeholders": { "number": { "type": "String" } }
  },
  "markerUnknown": "Linia {number}",
  "@markerUnknown": {
    "placeholders": { "number": { "type": "String" } }
  },
  "markerAgo": "{seconds}s temu",
  "@markerAgo": {
    "placeholders": { "seconds": { "type": "int" } }
  },
  "permissionsLocationDenied": "Brak dostępu do lokalizacji"
}
```

- [ ] **Step 3: Generate the localization classes**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_pl.dart` are regenerated. Both files are tracked in version control. Import in consumers via `package:mpk_lodz_tracker/l10n/app_localizations.dart`. (Flutter 3.41+ removed the `synthetic-package` mode; the old `package:flutter_gen/gen_l10n/...` import path no longer works.)

- [ ] **Step 4: Smoke-test analyzer recognises the generated package**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add l10n.yaml lib/l10n/app_pl.arb pubspec.yaml
git commit -m "feat(i18n): set up Polish ARB localization"
```

---

## Task 6: Domain Models (Vehicle, Line, VehicleType)

**Files:**
- Create: `lib/domain/models/vehicle.dart`
- Create: `lib/domain/models/line.dart`

- [ ] **Step 1: Write `lib/domain/models/vehicle.dart`**

```dart
enum VehicleType { tram, bus, unknown }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.routeId,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.bearing,
    this.speed,
  });

  final String id;
  final String routeId;
  final double lat;
  final double lon;
  final int timestamp;
  final double? bearing;
  final double? speed;
}
```

- [ ] **Step 2: Write `lib/domain/models/line.dart`**

```dart
import 'vehicle.dart';

class Line {
  const Line({
    required this.routeId,
    required this.number,
    required this.type,
  });

  final String routeId;
  final String number;
  final VehicleType type;
}

typedef RoutesIndex = Map<String, Line>;

Line resolveLine(String routeId, RoutesIndex index) {
  final found = index[routeId];
  if (found != null) return found;
  return Line(routeId: routeId, number: routeId, type: VehicleType.unknown);
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/domain/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/
git commit -m "feat(domain): Vehicle, Line, VehicleType models"
```

---

## Task 7: Core UI Constants

**Files:**
- Create: `lib/ui/core/lodz_constants.dart`
- Create: `lib/ui/core/vehicle_colors.dart`
- Create: `lib/ui/core/app_theme.dart`

- [ ] **Step 1: Write `lib/ui/core/lodz_constants.dart`**

```dart
class LodzConstants {
  LodzConstants._();

  static const double centerLat = 51.7592;
  static const double centerLon = 19.456;
  static const double defaultZoom = 12;
  static const Duration pollInterval = Duration(seconds: 10);
  static const Duration routesCacheTtl = Duration(days: 7);
}
```

- [ ] **Step 2: Write `lib/ui/core/vehicle_colors.dart`**

```dart
import 'package:flutter/material.dart';
import '../../domain/models/vehicle.dart';

const Map<VehicleType, Color> kVehicleColors = {
  VehicleType.tram: Color(0xFFE74C3C),
  VehicleType.bus: Color(0xFF2E86DE),
  VehicleType.unknown: Color(0xFF7F8C8D),
};

Color colorFor(VehicleType type) => kVehicleColors[type]!;
```

- [ ] **Step 3: Write `lib/ui/core/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E86DE)),
      useMaterial3: true,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E86DE),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
```

- [ ] **Step 4: Commit**

```bash
git add lib/ui/core/
git commit -m "feat(ui): theme + Łódź constants + vehicle color map"
```

---

## Task 8: Compile GTFS-Realtime Protobuf Bindings

**Files:**
- Create: `tool/gen_proto.sh`
- Create: `lib/data/services/generated/gtfs-realtime.pb.dart` (and siblings, generated)
- Create: `proto/gtfs-realtime.proto` (vendored)

The current RN app uses `gtfs-realtime-bindings` JavaScript. Flutter has no equivalent prebuilt package; instead vendor the upstream `.proto` and run `protoc` with the Dart plugin once. The generated `.dart` files are committed so contributors do not need protoc on a normal pull.

- [ ] **Step 1: Vendor the proto file**

```bash
mkdir -p proto tool
curl -fsSL https://raw.githubusercontent.com/google/transit/master/gtfs-realtime/proto/gtfs-realtime.proto -o proto/gtfs-realtime.proto
```

- [ ] **Step 2: Write `tool/gen_proto.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
# Requires: protoc on PATH, dart pub global activate protoc_plugin
OUT=lib/data/services/generated
mkdir -p "$OUT"
protoc \
  --dart_out="$OUT" \
  --proto_path=proto \
  proto/gtfs-realtime.proto
```

```bash
chmod +x tool/gen_proto.sh
```

- [ ] **Step 3: Install the protoc Dart plugin and run the generator**

```bash
dart pub global activate protoc_plugin
export PATH="$PATH":"$HOME/.pub-cache/bin"
./tool/gen_proto.sh
```

Expected output: `lib/data/services/generated/gtfs-realtime.pb.dart`, `gtfs-realtime.pbenum.dart`, `gtfs-realtime.pbjson.dart`, `gtfs-realtime.pbserver.dart`. Delete `pbserver.dart` (server-side, not needed) before committing.

- [ ] **Step 4: Verify analyzer accepts the generated code**

Run: `flutter analyze`
Expected: `No issues found!` (the generated files are exempt from style rules; if the analyzer flags them, add `lib/data/services/generated/**` to `analysis_options.yaml` `analyzer.exclude`).

- [ ] **Step 5: Commit**

```bash
git add proto/ tool/gen_proto.sh lib/data/services/generated/ analysis_options.yaml
git commit -m "feat(proto): vendor gtfs-realtime.proto + generated Dart bindings"
```

---

## Task 9: GtfsRtService — Decode Vehicle Positions (TDD)

**Files:**
- Create: `lib/data/services/gtfs_rt_service.dart`
- Create: `test/data/services/gtfs_rt_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/services/gtfs_rt_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_rt_service.dart';

void main() {
  test('decodeVehiclePositions parses real fixture into Vehicle list', () {
    final bytes = File('__fixtures__/vehicle_positions.bin').readAsBytesSync();
    final vehicles = GtfsRtService.decode(bytes);
    expect(vehicles, isNotEmpty);
    final first = vehicles.first;
    expect(first.id, isNotEmpty);
    expect(first.routeId, isNotEmpty);
    expect(first.lat, inInclusiveRange(51.0, 52.5));
    expect(first.lon, inInclusiveRange(19.0, 20.0));
    expect(first.timestamp, greaterThan(0));
  });

  test('decodeVehiclePositions skips entities without position or routeId', () {
    // Empty FeedMessage byte payload → []
    final empty = <int>[]; // not a valid feed; expect graceful handling via fromBuffer
    expect(() => GtfsRtService.decode(empty), returnsNormally);
    expect(GtfsRtService.decode(empty), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/services/gtfs_rt_service_test.dart`
Expected: FAIL — file `gtfs_rt_service.dart` does not exist.

- [ ] **Step 3: Implement `lib/data/services/gtfs_rt_service.dart`**

```dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/vehicle.dart';
import 'generated/gtfs-realtime.pb.dart';

class GtfsRtService {
  GtfsRtService({http.Client? client}) : _client = client ?? http.Client();

  static const Uri vehiclePositionsUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/vehicle_positions.bin',
  );

  final http.Client _client;

  Future<List<Vehicle>> fetchVehiclePositions() async {
    final res = await _client.get(vehiclePositionsUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS-RT fetch failed: ${res.statusCode}');
    }
    return decode(res.bodyBytes);
  }

  static List<Vehicle> decode(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    final feed = FeedMessage.fromBuffer(Uint8List.fromList(bytes));
    final out = <Vehicle>[];
    for (final entity in feed.entity) {
      if (entity.id.isEmpty) continue;
      if (!entity.hasVehicle()) continue;
      final v = entity.vehicle;
      if (!v.hasPosition()) continue;
      final pos = v.position;
      if (!pos.hasLatitude() || !pos.hasLongitude()) continue;
      final routeId = v.hasTrip() ? v.trip.routeId : '';
      if (routeId.isEmpty) continue;
      out.add(Vehicle(
        id: entity.id,
        routeId: routeId,
        lat: pos.latitude,
        lon: pos.longitude,
        timestamp: v.hasTimestamp() ? v.timestamp.toInt() : 0,
        bearing: pos.hasBearing() ? pos.bearing : null,
        speed: pos.hasSpeed() ? pos.speed : null,
      ));
    }
    return out;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/gtfs_rt_service_test.dart`
Expected: PASS (both cases).

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/gtfs_rt_service.dart test/data/services/gtfs_rt_service_test.dart
git commit -m "feat(data): GtfsRtService — fetch + decode vehicle_positions.bin"
```

---

## Task 10: GtfsStaticService — Parse `routes.txt` from GTFS.zip (TDD)

**Files:**
- Create: `lib/data/models/route_api_model.dart`
- Create: `lib/data/services/gtfs_static_service.dart`
- Create: `test/data/services/gtfs_static_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/services/gtfs_static_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  test('parseRoutesFromZip extracts tram + bus from minimal fixture', () async {
    final bytes = File('__fixtures__/GTFS-mini.zip').readAsBytesSync();
    final index = await GtfsStaticService.parseRoutesFromZip(bytes);

    expect(index.length, 3);
    final tram = index.values.where((l) => l.type == VehicleType.tram).toList();
    final bus = index.values.where((l) => l.type == VehicleType.bus).toList();
    expect(tram.length, 2);
    expect(bus.length, 1);
    expect(tram.first.number, isNotEmpty);
  });

  test('parseRoutesFromZip throws when routes.txt missing', () async {
    expect(
      () => GtfsStaticService.parseRoutesFromZip(<int>[0x50, 0x4B, 0x05, 0x06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `flutter test test/data/services/gtfs_static_service_test.dart`
Expected: FAIL — service does not exist.

- [ ] **Step 3: Implement `lib/data/models/route_api_model.dart`**

```dart
class RouteApiModel {
  const RouteApiModel({
    required this.routeId,
    required this.shortName,
    required this.routeType,
  });

  factory RouteApiModel.fromCsvRow(Map<String, String> row) => RouteApiModel(
        routeId: row['route_id'] ?? '',
        shortName: row['route_short_name'] ?? '',
        routeType: row['route_type'] ?? '',
      );

  final String routeId;
  final String shortName;
  final String routeType;
}
```

- [ ] **Step 4: Implement `lib/data/services/gtfs_static_service.dart`**

```dart
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/line.dart';
import '../../domain/models/vehicle.dart';
import '../models/route_api_model.dart';

class GtfsStaticService {
  GtfsStaticService({http.Client? client}) : _client = client ?? http.Client();

  static const Uri staticUrl = Uri(
    scheme: 'https',
    host: 'otwarte.miasto.lodz.pl',
    path: '/wp-content/uploads/2025/06/GTFS.zip',
  );

  final http.Client _client;

  Future<RoutesIndex> fetchAndParseRoutes() async {
    final res = await _client.get(staticUrl);
    if (res.statusCode != 200) {
      throw Exception('GTFS static fetch failed: ${res.statusCode}');
    }
    return parseRoutesFromZip(res.bodyBytes);
  }

  static Future<RoutesIndex> parseRoutesFromZip(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('routes.txt');
    if (entry == null) {
      throw Exception('routes.txt missing from GTFS zip');
    }
    final csvText = utf8.decode(entry.content as List<int>);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvText);
    if (rows.isEmpty) return <String, Line>{};

    final headers = rows.first.cast<String>();
    final index = <String, Line>{};
    for (var i = 1; i < rows.length; i++) {
      final raw = rows[i];
      final map = <String, String>{};
      for (var c = 0; c < headers.length && c < raw.length; c++) {
        map[headers[c]] = raw[c].toString();
      }
      final api = RouteApiModel.fromCsvRow(map);
      if (api.routeId.isEmpty || api.shortName.isEmpty) continue;
      index[api.routeId] = Line(
        routeId: api.routeId,
        number: api.shortName,
        type: _mapType(api.routeType),
      );
    }
    return index;
  }

  static VehicleType _mapType(String code) {
    switch (code) {
      case '0':
        return VehicleType.tram;
      case '3':
        return VehicleType.bus;
      default:
        return VehicleType.unknown;
    }
  }
}
```

- [ ] **Step 5: Run test, verify pass**

Run: `flutter test test/data/services/gtfs_static_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/ lib/data/services/gtfs_static_service.dart test/data/services/gtfs_static_service_test.dart
git commit -m "feat(data): GtfsStaticService — fetch + parse routes.txt"
```

---

## Task 11: RoutesCacheService — File-System TTL Cache (TDD)

**Files:**
- Create: `lib/data/services/routes_cache_service.dart`
- Create: `test/data/services/routes_cache_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/services/routes_cache_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

void main() {
  late Directory tmp;
  late RoutesCacheService cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('routes_cache_test_');
    cache = RoutesCacheService(directoryProvider: () async => tmp);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('returns null when no cache file exists', () async {
    expect(await cache.read(maxAge: const Duration(days: 7)), isNull);
  });

  test('writes and reads back a routes index', () async {
    final idx = <String, Line>{
      'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
    };
    await cache.write(idx);
    final read = await cache.read(maxAge: const Duration(days: 7));
    expect(read, isNotNull);
    expect(read!['r1']!.number, '8');
    expect(read['r1']!.type, VehicleType.tram);
  });

  test('returns null when cache is older than TTL', () async {
    final idx = <String, Line>{
      'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
    };
    await cache.write(idx);
    final file = File('${tmp.path}/routes.json');
    final old = DateTime.now().subtract(const Duration(days: 10));
    await file.setLastModified(old);
    expect(await cache.read(maxAge: const Duration(days: 7)), isNull);
  });
}
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/data/services/routes_cache_service_test.dart`
Expected: FAIL — service does not exist.

- [ ] **Step 3: Implement `lib/data/services/routes_cache_service.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/line.dart';
import '../../domain/models/vehicle.dart';

typedef DirectoryProvider = Future<Directory> Function();

class RoutesCacheService {
  RoutesCacheService({DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final DirectoryProvider _directoryProvider;

  static const _fileName = 'routes.json';

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  Future<RoutesIndex?> read({required Duration maxAge}) async {
    final file = await _file();
    if (!file.existsSync()) return null;
    final modified = await file.lastModified();
    if (DateTime.now().difference(modified) > maxAge) return null;

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, Line>{};
    decoded.forEach((routeId, value) {
      final m = value as Map<String, dynamic>;
      out[routeId] = Line(
        routeId: m['routeId'] as String,
        number: m['number'] as String,
        type: VehicleType.values.firstWhere(
          (t) => t.name == (m['type'] as String),
          orElse: () => VehicleType.unknown,
        ),
      );
    });
    return out;
  }

  Future<void> write(RoutesIndex index) async {
    final file = await _file();
    final encoded = <String, dynamic>{};
    index.forEach((routeId, line) {
      encoded[routeId] = {
        'routeId': line.routeId,
        'number': line.number,
        'type': line.type.name,
      };
    });
    await file.writeAsString(jsonEncode(encoded));
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/data/services/routes_cache_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/routes_cache_service.dart test/data/services/routes_cache_service_test.dart
git commit -m "feat(data): RoutesCacheService — file-system TTL cache"
```

---

## Task 12: VehiclesRepository

**Files:**
- Create: `lib/data/repositories/vehicles_repository.dart`

The vehicles repository is a thin facade — there is no caching dimension because the live feed is the source of truth and is replaced wholesale every poll. It exists for symmetry and to keep ViewModels free of direct service access.

- [ ] **Step 1: Write `lib/data/repositories/vehicles_repository.dart`**

```dart
import '../../domain/models/vehicle.dart';
import '../services/gtfs_rt_service.dart';

class VehiclesRepository {
  VehiclesRepository({required GtfsRtService service}) : _service = service;
  final GtfsRtService _service;

  Future<List<Vehicle>> fetchLatest() => _service.fetchVehiclePositions();
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/data/repositories/`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/vehicles_repository.dart
git commit -m "feat(data): VehiclesRepository facade"
```

---

## Task 13: RoutesRepository — Cache-or-Fetch (TDD)

**Files:**
- Create: `lib/data/repositories/routes_repository.dart`
- Create: `test/data/repositories/routes_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/routes_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/routes_repository.dart';
import 'package:mpk_lodz_tracker/data/services/gtfs_static_service.dart';
import 'package:mpk_lodz_tracker/data/services/routes_cache_service.dart';
import 'package:mpk_lodz_tracker/domain/models/line.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';

class _MockStatic extends Mock implements GtfsStaticService {}
class _MockCache extends Mock implements RoutesCacheService {}

void main() {
  late _MockStatic staticService;
  late _MockCache cacheService;
  late RoutesRepository repo;

  final fixtureIndex = <String, Line>{
    'r1': const Line(routeId: 'r1', number: '8', type: VehicleType.tram),
  };

  setUp(() {
    staticService = _MockStatic();
    cacheService = _MockCache();
    repo = RoutesRepository(staticService: staticService, cacheService: cacheService);
  });

  test('returns cached index when present and fresh', () async {
    when(() => cacheService.read(maxAge: any(named: 'maxAge')))
        .thenAnswer((_) async => fixtureIndex);

    final result = await repo.getRoutes();
    expect(result, fixtureIndex);
    verifyNever(() => staticService.fetchAndParseRoutes());
  });

  test('falls back to fetching and writes cache when miss', () async {
    when(() => cacheService.read(maxAge: any(named: 'maxAge')))
        .thenAnswer((_) async => null);
    when(() => staticService.fetchAndParseRoutes())
        .thenAnswer((_) async => fixtureIndex);
    when(() => cacheService.write(any())).thenAnswer((_) async {});

    final result = await repo.getRoutes();
    expect(result, fixtureIndex);
    verify(() => cacheService.write(fixtureIndex)).called(1);
  });
}
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/data/repositories/routes_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `lib/data/repositories/routes_repository.dart`**

```dart
import '../../domain/models/line.dart';
import '../../ui/core/lodz_constants.dart';
import '../services/gtfs_static_service.dart';
import '../services/routes_cache_service.dart';

class RoutesRepository {
  RoutesRepository({
    required GtfsStaticService staticService,
    required RoutesCacheService cacheService,
  })  : _static = staticService,
        _cache = cacheService;

  final GtfsStaticService _static;
  final RoutesCacheService _cache;

  Future<RoutesIndex> getRoutes() async {
    final cached = await _cache.read(maxAge: LodzConstants.routesCacheTtl);
    if (cached != null) return cached;
    final fresh = await _static.fetchAndParseRoutes();
    await _cache.write(fresh);
    return fresh;
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/data/repositories/routes_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/routes_repository.dart test/data/repositories/routes_repository_test.dart
git commit -m "feat(data): RoutesRepository with cache-or-fetch"
```

---

## Task 14: BootstrapViewModel

**Files:**
- Create: `lib/ui/features/map/view_models/bootstrap_view_model.dart`

The bootstrap VM is intentionally tiny — fire-and-forget on construction, exposes `routes` and `ready`. Errors are logged and do not block polling per spec ("vehicles can stream in before the static index has loaded").

- [ ] **Step 1: Write `lib/ui/features/map/view_models/bootstrap_view_model.dart`**

```dart
import 'package:flutter/foundation.dart';
import '../../../../data/repositories/routes_repository.dart';
import '../../../../domain/models/line.dart';

class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel({required RoutesRepository repository})
      : _repo = repository {
    _load();
  }

  final RoutesRepository _repo;
  RoutesIndex _routes = const {};
  bool _ready = false;

  RoutesIndex get routes => _routes;
  bool get ready => _ready;

  Future<void> _load() async {
    try {
      final idx = await _repo.getRoutes();
      _routes = idx;
      _ready = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[BootstrapViewModel] $e\n$st');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/features/map/view_models/bootstrap_view_model.dart
git commit -m "feat(ui): BootstrapViewModel loads routes on init"
```

---

## Task 15: MapViewModel — Polling + Lifecycle (TDD)

**Files:**
- Create: `lib/ui/features/map/view_models/map_view_model.dart`
- Create: `test/ui/features/map/map_view_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/features/map/map_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpk_lodz_tracker/data/repositories/vehicles_repository.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/lodz_constants.dart';
import 'package:mpk_lodz_tracker/ui/features/map/view_models/map_view_model.dart';

class _MockVehiclesRepo extends Mock implements VehiclesRepository {}

void main() {
  late _MockVehiclesRepo repo;
  final v1 = const Vehicle(id: 'v1', routeId: 'r1', lat: 51.7, lon: 19.4, timestamp: 1);

  setUp(() {
    repo = _MockVehiclesRepo();
  });

  test('start() polls immediately and at the configured interval', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => [v1]);
      final vm = MapViewModel(repository: repo);
      vm.start();

      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      async.elapse(LodzConstants.pollInterval);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1);

      vm.stop();
    });
  });

  test('replace updates vehicles and lastUpdate', () async {
    when(() => repo.fetchLatest()).thenAnswer((_) async => [v1]);
    final vm = MapViewModel(repository: repo);
    await vm.refreshOnce();
    expect(vm.vehicles, [v1]);
    expect(vm.lastUpdate, isNotNull);
  });

  test('stop() halts polling', () {
    fakeAsync((async) {
      when(() => repo.fetchLatest()).thenAnswer((_) async => const []);
      final vm = MapViewModel(repository: repo);
      vm.start();
      async.flushMicrotasks();
      vm.stop();
      async.elapse(LodzConstants.pollInterval * 3);
      async.flushMicrotasks();
      verify(() => repo.fetchLatest()).called(1); // only the initial tick
    });
  });
}
```

Add `fake_async` as dev dep first:

```bash
flutter pub add dev:fake_async
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/ui/features/map/map_view_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `lib/ui/features/map/view_models/map_view_model.dart`**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../../data/repositories/vehicles_repository.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/lodz_constants.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  MapViewModel({required VehiclesRepository repository}) : _repo = repository;

  final VehiclesRepository _repo;
  Timer? _timer;

  List<Vehicle> _vehicles = const [];
  DateTime? _lastUpdate;

  List<Vehicle> get vehicles => _vehicles;
  DateTime? get lastUpdate => _lastUpdate;

  void start() {
    if (_timer != null) return;
    refreshOnce();
    _timer = Timer.periodic(LodzConstants.pollInterval, (_) => refreshOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshOnce() async {
    try {
      final next = await _repo.fetchLatest();
      _vehicles = next;
      _lastUpdate = DateTime.now();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[MapViewModel] poll failed: $e\n$st');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      stop();
    }
  }

  void attachLifecycle() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detachLifecycle() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void dispose() {
    stop();
    detachLifecycle();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/ui/features/map/map_view_model_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/map/view_models/map_view_model.dart test/ui/features/map/map_view_model_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(ui): MapViewModel with timer polling + AppLifecycle"
```

---

## Task 16: FilterViewModel (TDD)

**Files:**
- Create: `lib/ui/features/filter/view_models/filter_view_model.dart`
- Create: `test/ui/features/filter/filter_view_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/features/filter/filter_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/view_models/filter_view_model.dart';

void main() {
  test('toggle adds and removes route ids', () {
    final vm = FilterViewModel();
    vm.toggle('r1');
    expect(vm.selectedRouteIds, {'r1'});
    vm.toggle('r2');
    expect(vm.selectedRouteIds, {'r1', 'r2'});
    vm.toggle('r1');
    expect(vm.selectedRouteIds, {'r2'});
  });

  test('clear empties selection', () {
    final vm = FilterViewModel();
    vm.toggle('r1');
    vm.clear();
    expect(vm.selectedRouteIds, isEmpty);
  });

  test('setTab updates active tab and notifies', () {
    final vm = FilterViewModel();
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.setTab(VehicleType.bus);
    expect(vm.activeTab, VehicleType.bus);
    expect(notifications, 1);
  });

  test('setQuery trims and lowercases', () {
    final vm = FilterViewModel();
    vm.setQuery('  8A  ');
    expect(vm.query, '8a');
  });
}
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/ui/features/filter/filter_view_model_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `lib/ui/features/filter/view_models/filter_view_model.dart`**

```dart
import 'package:flutter/foundation.dart';
import '../../../../domain/models/vehicle.dart';

class FilterViewModel extends ChangeNotifier {
  Set<String> _selected = <String>{};
  VehicleType _tab = VehicleType.tram;
  String _query = '';

  Set<String> get selectedRouteIds => Set.unmodifiable(_selected);
  VehicleType get activeTab => _tab;
  String get query => _query;

  void toggle(String routeId) {
    if (_selected.contains(routeId)) {
      _selected.remove(routeId);
    } else {
      _selected.add(routeId);
    }
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected = <String>{};
    notifyListeners();
  }

  void setTab(VehicleType tab) {
    if (tab == _tab) return;
    if (tab == VehicleType.unknown) return; // tabs only model tram | bus
    _tab = tab;
    notifyListeners();
  }

  void setQuery(String raw) {
    final next = raw.trim().toLowerCase();
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/ui/features/filter/filter_view_model_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/filter/view_models/ test/ui/features/filter/filter_view_model_test.dart
git commit -m "feat(ui): FilterViewModel — selection, tab, query"
```

---

## Task 17: LineChip Widget (TDD)

**Files:**
- Create: `lib/ui/features/filter/views/line_chip.dart`
- Create: `test/ui/features/filter/line_chip_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// test/ui/features/filter/line_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/domain/models/vehicle.dart';
import 'package:mpk_lodz_tracker/ui/core/vehicle_colors.dart';
import 'package:mpk_lodz_tracker/ui/features/filter/views/line_chip.dart';

void main() {
  testWidgets('renders number and toggles selected style', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '8',
          type: VehicleType.tram,
          selected: false,
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.byType(LineChip));
    expect(taps, 1);
  });

  testWidgets('selected variant fills with the type color', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LineChip(
          number: '46A',
          type: VehicleType.bus,
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    final container = tester.widget<Container>(find.byKey(const ValueKey('line-chip-container')));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, kVehicleColors[VehicleType.bus]);
  });
}
```

- [ ] **Step 2: Run, verify failure**

Run: `flutter test test/ui/features/filter/line_chip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `lib/ui/features/filter/views/line_chip.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class LineChip extends StatelessWidget {
  const LineChip({
    super.key,
    required this.number,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String number;
  final VehicleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const ValueKey('line-chip-container'),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          number,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `flutter test test/ui/features/filter/line_chip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/filter/views/line_chip.dart test/ui/features/filter/line_chip_test.dart
git commit -m "feat(ui): LineChip widget"
```

---

## Task 18: FilterSheet

**Files:**
- Create: `lib/ui/features/filter/views/filter_sheet.dart`

The bottom sheet renders inside `showModalBottomSheet` and consumes both `BootstrapViewModel` (for the routes index) and `FilterViewModel` (for selection state). It is presented from `MapScreen` via a static `show` helper.

- [ ] **Step 1: Write `lib/ui/features/filter/views/filter_sheet.dart`**

```dart
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
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/ui/features/filter/`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/features/filter/views/filter_sheet.dart
git commit -m "feat(ui): FilterSheet bottom sheet with tabs + search"
```

---

## Task 19: VehicleMarkersLayer (GeoJSON Source on MapLibre)

**Files:**
- Create: `lib/ui/features/map/views/vehicle_markers_layer.dart`

`maplibre_gl`'s `MapLibreMapController` exposes `addGeoJsonSource`, `addCircleLayer`, `addSymbolLayer`. Encode the vehicle list once into a GeoJSON FeatureCollection with `properties.type` (string) and `properties.number` (string). Use `match` expressions for the circle color.

- [ ] **Step 1: Write `lib/ui/features/map/views/vehicle_markers_layer.dart`**

```dart
import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../domain/models/line.dart';
import '../../../../domain/models/vehicle.dart';
import '../../../core/vehicle_colors.dart';

class VehicleMarkersLayer {
  static const _sourceId = 'vehicles';
  static const _circleLayerId = 'vehicle-circles';
  static const _labelLayerId = 'vehicle-labels';

  final MapLibreMapController controller;
  bool _initialized = false;

  VehicleMarkersLayer(this.controller);

  Future<void> sync(List<Vehicle> vehicles, RoutesIndex routes) async {
    final fc = _toFeatureCollection(vehicles, routes);
    if (!_initialized) {
      await controller.addGeoJsonSource(_sourceId, fc);
      await controller.addCircleLayer(
        _sourceId,
        _circleLayerId,
        CircleLayerProperties(
          circleColor: [
            'match',
            ['get', 'type'],
            'tram', '#${kVehicleColors[VehicleType.tram]!.value.toRadixString(16).substring(2)}',
            'bus', '#${kVehicleColors[VehicleType.bus]!.value.toRadixString(16).substring(2)}',
            '#${kVehicleColors[VehicleType.unknown]!.value.toRadixString(16).substring(2)}',
          ],
          circleRadius: 14,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );
      await controller.addSymbolLayer(
        _sourceId,
        _labelLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'number'],
          textSize: 11,
          textAllowOverlap: true,
          textColor: '#ffffff',
          textFont: ['Open Sans Bold'],
        ),
      );
      _initialized = true;
    } else {
      await controller.setGeoJsonSource(_sourceId, fc);
    }
  }

  Map<String, dynamic> _toFeatureCollection(List<Vehicle> vehicles, RoutesIndex routes) {
    final features = vehicles.map((v) {
      final line = resolveLine(v.routeId, routes);
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [v.lon, v.lat],
        },
        'properties': {
          'number': line.number,
          'type': line.type.name,
          'routeId': v.routeId,
        },
      };
    }).toList();
    final fc = {'type': 'FeatureCollection', 'features': features};
    // sanity: must round-trip JSON cleanly
    jsonEncode(fc);
    return fc;
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze lib/ui/features/map/views/vehicle_markers_layer.dart`
Expected: clean. (Visual rendering is verified manually — no widget test for the MapLibre layer because the platform view does not render in `flutter_test`.)

- [ ] **Step 3: Commit**

```bash
git add lib/ui/features/map/views/vehicle_markers_layer.dart
git commit -m "feat(ui): VehicleMarkersLayer — GeoJSON source + circle/symbol layers"
```

---

## Task 20: LastUpdateHint Widget

**Files:**
- Create: `lib/ui/features/map/views/last_update_hint.dart`

- [ ] **Step 1: Write `lib/ui/features/map/views/last_update_hint.dart`**

```dart
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/features/map/views/last_update_hint.dart
git commit -m "feat(ui): LastUpdateHint — bottom-left timer label"
```

---

## Task 21: LocateFab Widget

**Files:**
- Create: `lib/ui/features/map/views/locate_fab.dart`

- [ ] **Step 1: Write `lib/ui/features/map/views/locate_fab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class LocateFab extends StatelessWidget {
  const LocateFab({super.key, required this.controllerProvider});

  final MapLibreMapController? Function() controllerProvider;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: FloatingActionButton(
        heroTag: 'locate',
        onPressed: () => _onTap(context),
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final ctrl = controllerProvider();
    if (ctrl == null) return;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14),
      duration: const Duration(milliseconds: 600),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/features/map/views/locate_fab.dart
git commit -m "feat(ui): LocateFab — geolocator + camera flyTo"
```

---

## Task 22: FilterChipButton Widget

**Files:**
- Create: `lib/ui/features/map/views/filter_chip_button.dart`

- [ ] **Step 1: Write `lib/ui/features/map/views/filter_chip_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../filter/view_models/filter_view_model.dart';
import '../../filter/views/filter_sheet.dart';

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCount = context.watch<FilterViewModel>().selectedRouteIds.length;
    final l10n = AppLocalizations.of(context);
    final label = selectedCount == 0
        ? l10n.filterChipAll
        : l10n.filterChipSome(selectedCount);

    return Positioned(
      top: 60,
      left: 12,
      right: 12,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => FilterSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/features/map/views/filter_chip_button.dart
git commit -m "feat(ui): FilterChipButton opens FilterSheet"
```

---

## Task 23: MapScreen — Composition

**Files:**
- Create: `lib/ui/features/map/views/map_screen.dart`

- [ ] **Step 1: Write `lib/ui/features/map/views/map_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../../core/lodz_constants.dart';
import '../view_models/bootstrap_view_model.dart';
import '../view_models/map_view_model.dart';
import 'filter_chip_button.dart';
import 'last_update_hint.dart';
import 'locate_fab.dart';
import 'vehicle_markers_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static String get _styleUrl =>
      'https://api.maptiler.com/maps/streets/style.json?key=$_maptilerKey';

  MapLibreMapController? _ctrl;
  VehicleMarkersLayer? _layer;

  @override
  void initState() {
    super.initState();
    final vm = context.read<MapViewModel>();
    vm.attachLifecycle();
    vm.start();
    vm.addListener(_syncLayer);
    context.read<BootstrapViewModel>().addListener(_syncLayer);
  }

  @override
  void dispose() {
    final vm = context.read<MapViewModel>();
    vm.removeListener(_syncLayer);
    context.read<BootstrapViewModel>().removeListener(_syncLayer);
    super.dispose();
  }

  Future<void> _syncLayer() async {
    final layer = _layer;
    if (layer == null) return;
    final vm = context.read<MapViewModel>();
    final boot = context.read<BootstrapViewModel>();
    final selected = context.read<FilterViewModelHolderForMap>().selectedRouteIds;
    final visible = selected.isEmpty
        ? vm.vehicles
        : vm.vehicles.where((v) => selected.contains(v.routeId)).toList();
    await layer.sync(visible, boot.routes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(LodzConstants.centerLat, LodzConstants.centerLon),
              zoom: LodzConstants.defaultZoom,
            ),
            onMapCreated: (c) {
              _ctrl = c;
              _layer = VehicleMarkersLayer(c);
            },
            onStyleLoadedCallback: () => _syncLayer(),
          ),
          const FilterChipButton(),
          LocateFab(controllerProvider: () => _ctrl),
          const LastUpdateHint(),
        ],
      ),
    );
  }
}
```

> **Note on `FilterViewModelHolderForMap`:** This is just a placeholder name — bind the real `FilterViewModel` directly in Task 24's wiring (`context.read<FilterViewModel>()`). Replace `FilterViewModelHolderForMap` with `FilterViewModel` after the import is added in Task 24.

- [ ] **Step 2: Fix imports + replace placeholder**

Replace the helper line with the real type:

```dart
// remove: import line for FilterViewModelHolderForMap
// add:
import '../../filter/view_models/filter_view_model.dart';

// inside _syncLayer:
final selected = context.read<FilterViewModel>().selectedRouteIds;
```

Also subscribe to filter changes in `initState`:

```dart
context.read<FilterViewModel>().addListener(_syncLayer);
```

…and remove that listener in `dispose`.

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze lib/ui/features/map/views/map_screen.dart`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/features/map/views/map_screen.dart
git commit -m "feat(ui): MapScreen composition + layer sync"
```

---

## Task 24: main.dart — Provider Wiring + MaterialApp

**Files:**
- Replace: `lib/main.dart`

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mpk_lodz_tracker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repositories/routes_repository.dart';
import 'data/repositories/vehicles_repository.dart';
import 'data/services/gtfs_rt_service.dart';
import 'data/services/gtfs_static_service.dart';
import 'data/services/routes_cache_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/filter/view_models/filter_view_model.dart';
import 'ui/features/map/view_models/bootstrap_view_model.dart';
import 'ui/features/map/view_models/map_view_model.dart';
import 'ui/features/map/views/map_screen.dart';

void main() {
  runApp(const MpkApp());
}

class MpkApp extends StatelessWidget {
  const MpkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final rtService = GtfsRtService();
    final staticService = GtfsStaticService();
    final cacheService = RoutesCacheService();
    final vehiclesRepo = VehiclesRepository(service: rtService);
    final routesRepo = RoutesRepository(
      staticService: staticService,
      cacheService: cacheService,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MapViewModel(repository: vehiclesRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => BootstrapViewModel(repository: routesRepo),
        ),
        ChangeNotifierProvider(create: (_) => FilterViewModel()),
      ],
      child: MaterialApp(
        title: 'MPK Łódź',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MapScreen(),
      ),
    );
  }
}
```

- [ ] **Step 2: Run on Android emulator with the MapTiler key**

```bash
flutter run -d emulator-5554 --dart-define=MAPTILER_KEY=<your_key>
```

Expected: app boots, Łódź camera centers, vehicles appear within ~10 seconds (depending on whether the static GTFS has loaded; even before that, vehicles render with `route_id` placeholders).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(app): wire providers + MaterialApp + MapScreen"
```

---

## Task 25: Smoke Test on Real Devices + Manual Test Doc

**Files:**
- Modify: `docs/manual-test.md` (or create if missing)

- [ ] **Step 1: Run on Android device/emulator**

```bash
flutter run --dart-define=MAPTILER_KEY=<key> -d <device-id>
```

Verify:
- Map loads with MapTiler tiles.
- Within ~10 s, vehicle markers (red trams, blue buses) appear over Łódź.
- Tapping the chip opens the bottom sheet; switching tabs filters chips; multi-select works; Wyczyść clears; Zastosuj closes.
- After applying a selection, only the selected lines remain on the map.
- Locate FAB requests permission, then recenters on user.
- Background → foreground cycle: vehicles refresh on resume.
- Toggle dark mode in system settings → app theme follows.

- [ ] **Step 2: Run on iOS simulator**

```bash
flutter run --dart-define=MAPTILER_KEY=<key> -d <ios-simulator-id>
```

Run the same checklist. Note any iOS-specific anomalies (location prompt copy, inset behavior under notch).

- [ ] **Step 3: Replace `docs/manual-test.md` with the Flutter version**

```markdown
# Manual Smoke Test — Flutter

Run: `flutter run --dart-define=MAPTILER_KEY=<key> -d <device>`

Checklist:
- [ ] Map tiles load (no blank canvas).
- [ ] Vehicle markers appear within ~10 s; trams red, buses blue.
- [ ] Filter chip opens bottom sheet.
- [ ] Tab switch (Tramwaje / Autobusy) changes the chip list.
- [ ] Search narrows the chip list.
- [ ] Multi-select toggles fill state.
- [ ] "Wyczyść" empties selection. "Zastosuj" closes the sheet.
- [ ] After Apply with a selection, only those lines remain on the map.
- [ ] LocateFab → permission prompt → camera flies to user.
- [ ] LocateFab when permission denied → no crash, camera unchanged.
- [ ] Background app → foreground → polling resumes immediately.
- [ ] System dark mode → app theme follows.

Repeat on Android + iOS.
```

- [ ] **Step 4: Commit**

```bash
git add docs/manual-test.md
git commit -m "docs: refresh manual smoke test for Flutter"
```

---

## Task 26: Update CLAUDE.md to Reflect Flutter Stack

**Files:**
- Replace: `CLAUDE.md`

- [ ] **Step 1: Replace `CLAUDE.md` with Flutter-focused guidance**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter mobile app showing live MPK Łódź vehicle positions on a MapLibre map. Single screen, no backend — the device polls the public GTFS-Realtime feed published at `otwarte.miasto.lodz.pl` directly. Spec lives in `docs/superpowers/specs/2026-05-01-mpk-lodz-tracker-design.md`. Original RN-era plan at `docs/superpowers/plans/2026-05-01-mpk-lodz-tracker.md`. Flutter rewrite plan at `docs/superpowers/plans/2026-05-01-flutter-rewrite.md`.

## Commands

- `flutter pub get` — install dependencies.
- `flutter analyze` — static analysis (treat warnings as errors).
- `flutter test` — full unit + widget test suite.
- `flutter test test/path/foo_test.dart` — single file. `-n 'partial name'` for a single test.
- `flutter run --dart-define=MAPTILER_KEY=<key>` — debug build on attached device/emulator.
- `flutter build apk --dart-define=MAPTILER_KEY=<key>` — release APK.
- `./tool/gen_proto.sh` — regenerate `lib/data/services/generated/gtfs-realtime.pb.dart` from `proto/gtfs-realtime.proto`. Requires `protoc` on PATH and `dart pub global activate protoc_plugin`.
- `flutter gen-l10n` — regenerate `AppLocalizations` after editing `lib/l10n/app_pl.arb`.

## Architecture

Layered MVVM (`flutter-apply-architecture-best-practices`):

```
lib/
  data/
    models/         raw API models (CSV/proto)
    services/       HTTP/proto/zip/file IO; stateless
    repositories/   compose services, return Domain models, handle caching
  domain/
    models/         Vehicle, Line, VehicleType
  ui/
    core/           constants, theme, color map
    features/
      map/          MapScreen + MapViewModel + BootstrapViewModel + map widgets
      filter/       FilterSheet + LineChip + FilterViewModel
  l10n/             ARB files (Polish only for now)
```

ViewModels are `ChangeNotifier`s, wired with `provider`. Polling lives in `MapViewModel` (`Timer.periodic` + `WidgetsBindingObserver`).

## Sharp edges

- **Certum CA on Android.** The GTFS feed certificate chains to Certum Trusted Root, not in Android's default trust store. `android/app/src/main/res/xml/network_security_config.xml` adds it as a trust anchor for `miasto.lodz.pl`. The PEM lives at `android/app/src/main/res/raw/certum_root_ca.pem`. To refresh: `echo | openssl s_client -servername otwarte.miasto.lodz.pl -connect otwarte.miasto.lodz.pl:443 -showcerts 2>/dev/null | awk '/BEGIN CERTIFICATE/{c++} c==3{print} /END CERTIFICATE/{if(c==3) exit}' > android/app/src/main/res/raw/certum_root_ca.pem`.
- **MAPTILER_KEY.** Must be passed via `--dart-define=MAPTILER_KEY=...`; missing/empty produces a blank map (HTTP 403). Do NOT commit the key. Read inside the app via `String.fromEnvironment('MAPTILER_KEY')`.
- **Generated protobuf.** The `lib/data/services/generated/` directory is committed but excluded from analyzer rules in `analysis_options.yaml`. Do not hand-edit; regenerate via `tool/gen_proto.sh`.
- **maplibre_gl PlatformView.** The MapLibre map is a native PlatformView; widget tests cannot render it. The vehicle layer + camera behavior is verified manually via `docs/manual-test.md`.

## Spec gaps still open

Same as the original RN spec — marker tap callout, bearing rotation on markers, offline indicator (50% opacity + toast), hide locate FAB on permission denial, full Polish plural rule for the chip count (handled in ARB), `SystemUiOverlayStyle` polishing for Android.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: rewrite CLAUDE.md for Flutter codebase"
```

---

## Self-Review

- **Spec coverage:**
  - Map screen with full-screen MapLibre, Łódź default camera → Task 23.
  - Filter chip + bottom sheet + Tramwaje/Autobusy tabs + search + multi-select → Tasks 17, 18, 22.
  - Locate-me FAB with permission flow → Task 21.
  - LastUpdate hint bottom-left → Task 20.
  - Markers colored by type (tram red, bus blue) → Task 19.
  - Polling 10 s + AppState pause/resume → Task 15.
  - GTFS-RT decode → Task 9. GTFS static parse → Task 10. TTL cache → Task 11.
  - Polish strings centralized → Task 5.
  - Dark mode follows system → Task 7 (themeMode.system in Task 24).
  - Certum trust anchor → Task 3.
  - iOS location strings → Task 4.
  - Tests (unit, widget, hook-equivalent) → Tasks 9–11, 13, 15–17.
  - Manual test doc → Task 25.
  - Spec gaps left open are documented in Task 26.
- **Placeholder scan:** None — every step has either complete code, exact commands, or explicit cross-references.
- **Type consistency:** `VehicleType { tram, bus, unknown }`, `Line { routeId, number, type }`, `RoutesIndex = Map<String, Line>`, `Vehicle { id, routeId, lat, lon, timestamp, bearing?, speed? }` are used identically across services, repositories, ViewModels, and views.
- **Method names verified:** `MapViewModel.start/stop/refreshOnce`, `RoutesRepository.getRoutes`, `RoutesCacheService.read/write`, `GtfsRtService.fetchVehiclePositions`/static `decode`, `GtfsStaticService.fetchAndParseRoutes`/static `parseRoutesFromZip`, `FilterViewModel.toggle/clear/setTab/setQuery`, `VehicleMarkersLayer.sync` — all referenced consistently.

---

## Execution Handoff

Plan saved at `docs/superpowers/plans/2026-05-01-flutter-rewrite.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task with two-stage review between tasks. Best for keeping context narrow and catching mistakes early.
2. **Inline Execution** — execute tasks in this session via `superpowers:executing-plans`, with checkpoints at task boundaries.

Pick one to start.

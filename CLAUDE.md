# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter mobile app showing live MPK Łódź vehicle positions on a MapLibre map. Single screen, no backend — the device polls the public GTFS-Realtime feed published at `otwarte.miasto.lodz.pl` directly. Spec lives in `docs/superpowers/specs/2026-05-01-mpk-lodz-tracker-design.md`. The original RN-era plan is at `docs/superpowers/plans/2026-05-01-mpk-lodz-tracker.md` (kept for history); the Flutter rewrite plan lives at `docs/superpowers/plans/2026-05-01-flutter-rewrite.md`.

## Commands

- `flutter pub get` — install dependencies.
- `flutter analyze` — static analysis. Treat warnings as errors.
- `flutter test` — full unit + widget test suite.
- `flutter test test/path/foo_test.dart` — single file. Add `-n 'partial name'` to narrow further.
- `flutter run --dart-define=MAPTILER_KEY=<key>` — debug build on attached device/emulator.
- `flutter build apk --dart-define=MAPTILER_KEY=<key>` — release APK.
- `./tool/gen_proto.sh` — regenerate `lib/data/services/generated/gtfs-realtime.pb.dart` from `proto/gtfs-realtime.proto`. Requires `protoc` on PATH and `dart pub global activate protoc_plugin`.
- `flutter gen-l10n` — regenerate `AppLocalizations` after editing `lib/l10n/app_pl.arb`.

Toolchain is managed via `fvm` (`fvm install stable && fvm global stable`); `flutter` and `dart` resolve through `~/fvm/default/bin` (symlinked into `~/.local/bin`). Android SDK lives at `~/Library/Android/sdk` with cmdline-tools provided by `brew install android-commandlinetools`.

## Architecture

Layered MVVM (`flutter-apply-architecture-best-practices`):

```
lib/
  data/
    models/         raw API models (CSV row → RouteApiModel)
    services/       HTTP/proto/zip/file IO; stateless
      generated/    protoc output, never hand-edited
    repositories/   compose services, return Domain models, handle caching
  domain/
    models/         Vehicle, Line, VehicleType, RoutesIndex typedef
  ui/
    core/           design tokens (LodzColors/Spacing/Radius/Shadows), theme, vehicle colors
    features/
      shell/        RootShell with bottom nav + LinesScreen/FavoritesScreen stubs
      map/          MapScreen + MapViewModel + BootstrapViewModel + LodzTopAppBar + MapSearchBar + LocateFab + LastUpdateHint + VehicleMarkersLayer
      filter/       FilterSheet + LineChip + FilterViewModel
  l10n/             ARB files (Polish only) + generated AppLocalizations
```

ViewModels are `ChangeNotifier`s wired via `provider`. `MapViewModel` owns `Timer.periodic` polling + `WidgetsBindingObserver` for AppLifecycle pause/resume. The vehicle layer is a separate `VehicleMarkersLayer` adapter that pushes GeoJSON into the MapLibre native source on every store change. `RootShell` hosts the three tabs in an `IndexedStack`; only the Map tab is functional, Lines/Favorites are "Wkrótce" placeholders.

Visual style follows the Stitch "Łódź Urban Transit System" design (`stitch_city_transit_tracker/d_urban_transit_system/DESIGN.md`): paper-white surfaces, Inter typography (loaded at runtime via `google_fonts`), tram=yellow `#FACC15`, bus=magenta `#D946EF`, cyan `#06B6D4` for interactive states. Tokens live in `lib/ui/core/design_tokens.dart`; never hardcode colors/spacing in widgets — pull from `LodzColors`/`LodzSpacing`/`LodzRadius`/`LodzShadows`.

## Sharp edges

- **Certum CA on Android.** GTFS feed certs chain to Certum Trusted Root, not in Android's default trust store. `android/app/src/main/res/xml/network_security_config.xml` adds it as a trust anchor for `miasto.lodz.pl`. The PEM lives at `android/app/src/main/res/raw/certum_root_ca.pem` (and is allowlisted in `.gitignore` despite the global `*.pem` rule). To refresh the cert: `echo | openssl s_client -servername otwarte.miasto.lodz.pl -connect otwarte.miasto.lodz.pl:443 -showcerts 2>/dev/null | awk '/BEGIN CERTIFICATE/{c++} c==3{print} /END CERTIFICATE/{if(c==3) exit}' > android/app/src/main/res/raw/certum_root_ca.pem`.
- **MAPTILER_KEY.** Pass via `--dart-define=MAPTILER_KEY=...`. Missing/empty produces a blank map (HTTP 403 from MapTiler). Read inside the app via `String.fromEnvironment('MAPTILER_KEY')`. Do NOT commit the key.
- **Generated protobuf.** `lib/data/services/generated/` is committed but excluded from analyzer rules in `analysis_options.yaml`. Do not hand-edit; regenerate via `tool/gen_proto.sh`.
- **maplibre_gl PlatformView.** The MapLibre map is a native PlatformView; `flutter_test` cannot render it. Vehicle layer + camera behavior is verified manually via `docs/manual-test.md`.
- **Dart SDK pinned to `>=3.10.0`.** Required because the Flutter scaffold's `lib/main.dart` (and downstream code) uses dot-shorthand syntax which is a Dart 3.10 language feature.
- **`pubspec.lock` is tracked.** This is an application package; the Flutter scaffold's default `.gitignore` rule excluding it (library convention) was removed.
- **Localization import path.** Use `package:mpk_lodz_tracker/l10n/app_localizations.dart`. Flutter 3.41 removed the synthetic-package mode, so the older `package:flutter_gen/...` path no longer works. `nullable-getter: false` in `l10n.yaml` means `AppLocalizations.of(context)` returns non-nullable — no bang assertion needed.
- **`MapViewModel` post-dispose race.** `refreshOnce` checks `_disposed` after the await before mutating state, to avoid `notifyListeners()` on a disposed `ChangeNotifier`. `detachLifecycle()` is idempotent (`_lifecycleAttached` flag) so unit tests without a `WidgetsBinding` don't crash.
- **`fixnum` declared as direct dev-dep.** Required by the gtfs-realtime synthetic-feed test (`Int64` for proto timestamps); transitively available via `protobuf` but the analyzer's `depend_on_referenced_packages` lint requires explicit declaration.

## Spec gaps still open

Carryover from the original RN spec — marker tap callout, offline indicator (50% opacity + toast), hide locate FAB on permission denial, `SystemUiOverlayStyle` polish for Android. Plus: the GTFS-RT decoder passes through vehicles with `lat=0/lon=0` (real fixture-data quirk); a small filter at the decoder level would tighten correctness. Bearing rotation on markers is now wired (Stitch restyle T11) — vehicles missing `bearing` simply don't render the arrow, which is intentional.

## Iterating on this codebase

- After editing `lib/l10n/app_pl.arb`, run `flutter gen-l10n` and commit the regenerated `lib/l10n/app_localizations*.dart`.
- After editing the proto, run `./tool/gen_proto.sh` and commit the regenerated bindings.
- Native folders (`android/`, `ios/`) ARE source of truth — do not regenerate via `flutter create .`.

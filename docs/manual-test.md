# Manual smoke test — Flutter

## Setup (once)

1. Sign up at <https://maptiler.com>, copy API key.
2. Install Flutter via fvm: `fvm install stable && fvm global stable`.
3. Verify toolchain: `flutter doctor` (Android toolchain must be ✓; iOS needs full Xcode).
4. `flutter pub get`

## Run

Ensure `secrets.json` exists at repo root with a real `MAPTILER_KEY` (see `README.md` setup) and that you have run `direnv allow` once. The `tool/flutter` wrapper appends `--dart-define-from-file=secrets.json` automatically. Then:

```sh
flutter run -d <device-id>
```

`flutter devices` lists attached devices. For an Android emulator: `emulator -list-avds && emulator -avd <name> &`.

Regenerate generated artifacts as needed:
- ARB localizations: `flutter gen-l10n`
- gtfs-realtime proto bindings: `./tool/gen_proto.sh`

## Walkthrough

- [ ] Map tiles load (no blank gray canvas).
- [ ] Within ~10 s, vehicle markers appear over Łódź. Trams are red, buses are blue, line numbers render in white.
- [ ] Tap the filter chip → bottom sheet opens.
- [ ] Switch tabs Tramwaje / Autobusy → chip list updates.
- [ ] Type a number into the search field → chip list narrows.
- [ ] Tap two chips → they fill. Tap **Zastosuj** → sheet closes, map shows only those lines.
- [ ] **Wyczyść** empties selection without closing the sheet.
- [ ] Locate FAB → permission prompt. Granted → camera flies to user. Denied → no crash, camera unchanged.
- [ ] Bottom-left "aktualizacja: Xs temu" hint counts up between polls.
- [ ] Background the app for 30 s, foreground it → vehicles refresh immediately, no crash.
- [ ] System dark mode → app theme follows.

## Polish character sanity

After any locale-related edit:

```sh
grep -E '(Łódź|ż|ć|ś)' lib/l10n/app_pl.arb android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
```

All occurrences must display correctly (no mojibake).

## Repeat on Android + iOS

Android first (works without Xcode). iOS requires full Xcode + `pod install` in `ios/`.

## Nearby stops sheet

Run with `flutter run --dart-define=MAPTILER_KEY=<key>` on a real device or emulator with location enabled.

1. **Peek state:** On launch, sheet sits at the bottom showing "X przystanków w pobliżu" with the nearest count.
2. **Expand:** Drag handle up — sheet snaps to ~70 %. List of up to 20 stops appears, sorted by distance. Each row shows name, line chips, walk time, distance.
3. **Map dots:** While expanded, small cyan circles appear on the map at each nearby stop. Collapsing the sheet removes them.
4. **Pan map:** Pan the map far away from the device. List does NOT change (Q2=A).
5. **Walk:** Move the device (or simulate) 100 m. After the next position update, the list re-sorts.
6. **Tap row:** Tap a stop row. Sheet content swaps to the detail view — back arrow, stop name, last-update timestamp, list of upcoming departures.
7. **Tap dot:** Tap a cyan dot on the map. Same detail view opens with that stop selected. (Currently a TODO: tap-on-dot is not yet wired pending a maplibre_gl binding API; verify by tapping a row instead.)
8. **Departures refresh:** Detail view auto-refreshes every 5 s. The "ostatnia aktualizacja" timestamp ticks. Closing detail returns to list and stops the 5 s polling.
9. **Delay:** A trip with >60 s delay shows `+N min` in red; an early trip shows `−N min` in green.
10. **Empty state:** If a stop has no upcoming departures (off-hours), detail shows "Brak nadchodzących odjazdów".
11. **Filter:** Toggle off a line in the filter sheet. Departures using that line disappear from the detail view; the nearby list itself is unchanged.
12. **Permission denied:** Revoke location permission in OS settings. Sheet auto-snaps to expanded and shows the CTA. Tap "Otwórz ustawienia" → opens system settings.
13. **No GPS fix:** Toggle airplane mode + location off and back; sheet shows "Czekam na sygnał GPS…" until a fix arrives. If a `lastFix` was previously persisted, it is used immediately instead of the waiting state.
14. **Background/foreground:** Background the app for >10 s during detail polling. Resume — detail refreshes immediately and timestamp updates. The map's 10 s tick also resumes. (Both pause and resume together via `AppLifecycleNotifier`.)
15. **Tab switch:** Switch to Lines, then back to Map. Sheet remounts; nearby list reappears; selected stop is NOT preserved.

### Known limitations (v1)

- Tap-on-dot to open stop detail is not yet wired (maplibre_gl binding limitation; tap a list row instead).
- Camera padding when sheet is expanded uses a lat-degree shift approximation (`CameraUpdate.padding` not exposed in current binding).
- `linesByStopId` is empty in v1 — list rows show no chips because we don't load `stop_times.txt`. Only the stop name + walk time + distance render.

# Manual smoke test — Flutter

## Setup (once)

1. Sign up at <https://maptiler.com>, copy API key.
2. Install Flutter via fvm: `fvm install stable && fvm global stable`.
3. Verify toolchain: `flutter doctor` (Android toolchain must be ✓; iOS needs full Xcode).
4. `flutter pub get`

## Run

```sh
flutter run --dart-define=MAPTILER_KEY=<your_key> -d <device-id>
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

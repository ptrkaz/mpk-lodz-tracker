# Manual smoke test

## Setup (once)

1. Sign up at <https://maptiler.com>, copy API key.
2. `cp .env.example .env`, paste key into `EXPO_PUBLIC_MAPTILER_KEY`.
3. `npx expo prebuild --clean`
4. iOS: `npx expo run:ios --device`
   Android: `npx expo run:android --device`

## Walkthrough

- [ ] App opens to a map of Łódź at zoom ~12.
- [ ] Within ~10 s, vehicle dots appear with line numbers.
- [ ] Tram numbers are red; bus numbers are blue.
- [ ] Tap the filter chip → bottom sheet opens.
- [ ] Switch tabs Tramwaje / Autobusy → list updates.
- [ ] Type a number into search → list narrows.
- [ ] Tap two chips → they fill in. Tap "Zastosuj" → sheet closes, map shows only those lines.
- [ ] "Wyczyść" empties selection.
- [ ] Tap locate FAB → permission prompt. Granted → map centers on user. Denied → no crash, map stays put.
- [ ] "ostatnia aktualizacja: Xs temu" hint counts up; resets on each tick.
- [ ] Background the app for 30 s, foreground it → vehicles refresh immediately, no stale-pause crash.
- [ ] Toggle airplane mode → toast or silent retry; previous vehicles stay (dimmed). Restore network → vehicles update.
- [ ] Toggle system dark mode → app follows.

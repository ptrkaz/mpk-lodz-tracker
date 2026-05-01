# MPK Łódź Live Tracker — Design Spec

**Date:** 2026-05-01
**Status:** Approved (brainstorm)
**Owner:** piotr

## Goal

Mobile React Native app showing live positions of MPK Łódź vehicles (trams + buses) on a map, with the ability to filter by line number.

## Scope (MVP)

In scope:

- Map screen displaying all active vehicles in real time.
- Filter by one or many line numbers (multi-select bottom sheet, separate tabs for trams and buses).
- "Locate me" centering on user position.
- Markers show line number, colored by vehicle type.
- Tap on marker shows minimal callout (line number, last update age).
- Polish UI, dark mode follows system.
- iOS + Android.

Out of scope (v2+):

- Stops layer and ETA.
- Alerts feed (`alerts.bin`).
- Delays / trip updates (`trip_updates.bin`).
- Historical trail of a single vehicle.
- Push notifications.
- Web build.

## Data Sources

Open data published by Urząd Miasta Łodzi at `https://otwarte.miasto.lodz.pl/transport_komunikacja/`:

- `vehicle_positions.bin` — GTFS-Realtime FeedMessage (Protocol Buffers), live vehicle positions. Polled every 10 s in foreground.
- `GTFS.zip` — static GTFS bundle. Used to map `route_id` → human-readable line number and vehicle type.

Other GTFS-RT feeds (`trip_updates.bin`, `alerts.bin`) are out of scope for MVP.

No proxy. The app fetches both files directly. License on the source page is unspecified; contact `ocm@uml.lodz.pl` if licensing becomes a question.

## Architecture

### Stack

- Expo SDK (latest stable) with **dev client** (MapLibre is a native module → Expo Go won't work).
- TypeScript, strict mode.
- `@maplibre/maplibre-react-native` for the map.
- Tile source: MapTiler streets style (free tier 100k req/month, key in `.env`).
- Zustand for state.
- `protobufjs` with the compiled `gtfs-realtime.proto` for decoding the live feed.
- `jszip` + `papaparse` for parsing static GTFS (`routes.txt` only).
- `expo-location` for "locate me".
- `expo-file-system` for caching parsed GTFS lookup.
- `react-native-bottom-sheet` for the filter sheet.

### Module layout

```
src/
  api/
    gtfsRealtime.ts      // fetch vehicle_positions.bin → Vehicle[]
    gtfsStatic.ts        // download + parse GTFS.zip → RoutesIndex
    types.ts             // Vehicle, Line shared types
  store/
    vehicles.ts          // Zustand: vehicles, lastUpdate
    routes.ts            // Zustand: routesIndex (route_id → Line)
    filter.ts            // selected route_ids, current vehicle type tab
  hooks/
    useVehiclePolling.ts // 10s interval + AppState pause
    useGtfsBootstrap.ts  // ensure routesIndex available
  screens/
    MapScreen.tsx        // map + filter chip + locate FAB
    FilterSheet.tsx      // search + multi-select lines
  components/
    VehicleMarker.tsx    // line number badge, color by type
    LineChip.tsx
  app/
    _layout.tsx          // expo-router root
    index.tsx            // → MapScreen
```

Each `api/` function is pure (in: arguments, out: typed data, no React). Stores are reactive but contain no I/O. Screens consume hooks; hooks orchestrate store + api.

### Data flow

1. **Boot.** `useGtfsBootstrap` checks for cached routes JSON. If absent or older than 7 days, downloads `GTFS.zip`, extracts `routes.txt`, builds `RoutesIndex` (`route_id → { number, type }`), persists to file system, loads into `routes` store.
2. **Polling.** `useVehiclePolling` runs every 10 s while app is foreground. Polling starts as soon as the app boots — it does not wait for `useGtfsBootstrap`. Each tick: GET `vehicle_positions.bin` as `ArrayBuffer`, decode via `protobufjs` to `FeedMessage`, map entities with a `vehicle.position` to `Vehicle[]`, commit to `vehicles` store with `lastUpdate = now`. The join with `routesIndex` happens at render time in the screen, not at ingest, so vehicles can stream in before the static index has loaded — they render with `route_id` as a placeholder label until the index resolves. Decode errors are logged and the iteration is skipped; the store remains untouched.
3. **Background.** Listen to `AppState`; pause polling when app backgrounds, resume on foreground (immediate refresh on resume).
4. **Render.** `MapScreen` subscribes to `vehicles`, `routes`, and `filter` stores. The filter set is keyed by `route_id`. When `filter.selectedRouteIds` is empty, all vehicles are shown; otherwise only vehicles whose `routeId` is in the set. Markers are rendered via MapLibre `ShapeSource` + `SymbolLayer` (single GeoJSON FeatureCollection rebuilt on store change) for performance with ~100+ vehicles.
5. **Filter.** Bottom sheet reads `routesIndex` (grouped by tram/bus), supports text search and multi-select. Apply writes to `filter` store; map updates reactively.

### Data model

```ts
type VehicleType = 'tram' | 'bus';

type Vehicle = {
  id: string;            // entity.id from GTFS-RT
  routeId: string;       // trip.route_id
  lineNumber: string;    // resolved via routesIndex
  vehicleType: VehicleType;
  lat: number;
  lon: number;
  bearing?: number;
  speed?: number;        // m/s as published
  timestamp: number;     // unix seconds from feed
};

type Line = {
  routeId: string;
  number: string;        // "8", "46A"
  type: VehicleType;     // GTFS route_type: 0 → tram, 3 → bus
};

type RoutesIndex = Record<string, Line>;
```

## UI

### Map screen (default)

- Full-screen MapLibre map, default camera centered on Łódź (`51.7592, 19.4560`, zoom 12).
- Top: pill-shaped filter chip showing current selection ("Wszystkie linie" or "8, 12 …"). Tap → opens filter sheet.
- Bottom-right: locate-me FAB. Tap → request permission if needed, recenter on user.
- Bottom-left: small "ostatnia aktualizacja: Xs temu" hint (subtle).
- Markers: rounded badge with line number; tram = red background, bus = blue background. Bearing rotation only if `bearing` is present.
- Tap marker: small callout with `Tramwaj 8` (or `Autobus 46A`) and "X s temu". No more.

### Filter sheet (bottom sheet)

- Search input "Szukaj linii…".
- Two-tab segmented control: Tramwaje | Autobusy.
- Wrapping list of line chips (selected = filled, unselected = outline). Multi-select.
- Bottom row: "Wyczyść" (clear all) and "Zastosuj" (close sheet).
- "Zastosuj" with empty selection means "show all" (same as clear).

### Theming

- Follow system dark / light. Use one accent color (red for trams, blue for buses) consistent across themes. No custom theme picker in MVP.

### Localization

- Polish only in MVP. All strings collected in `src/i18n/pl.ts` (single object) so a future EN can be added without touching screens.

## Error handling

| Failure                          | Behavior                                                                                                  |
|----------------------------------|-----------------------------------------------------------------------------------------------------------|
| Network offline / 5xx on RT feed | Keep last known vehicles dimmed (50% opacity); show toast "Brak połączenia, ponawiam…" once per outage.   |
| Protobuf decode error            | Log to console; skip iteration; do not mutate store.                                                      |
| GTFS static download fails       | Fall back to showing `route_id` as line label; retry next app start.                                      |
| Location permission denied       | Hide "moja lokalizacja" affordance; map stays on Łódź center.                                             |
| MapTiler tile load failure       | MapLibre's built-in retry; no custom UI.                                                                  |

## Testing

- **Unit:**
  - `api/gtfsRealtime.ts` — decode a fixture `.bin` (committed in `__fixtures__/`), assert mapped `Vehicle[]`.
  - `api/gtfsStatic.ts` — parse a minimal hand-crafted `GTFS.zip` fixture, assert `RoutesIndex`.
  - Stores: pure reducer-style updates verified directly.
- **Integration:**
  - `useVehiclePolling` with `jest.useFakeTimers()` and a mocked fetch — assert store grows, AppState change pauses interval.
- **Manual:**
  - Run on real iOS + Android device through Expo dev client. Verify markers move, filter narrows set, locate-me works, dark mode flips, app survives a background → foreground cycle.
- No E2E framework in MVP.

## Configuration & secrets

- `EXPO_PUBLIC_MAPTILER_KEY` in `.env` (gitignored), surfaced via `expo-constants`.
- Endpoint URLs are constants in `src/api/endpoints.ts`.
- iOS location permission string (`NSLocationWhenInUseUsageDescription`) declared via `app.json` → `ios.infoPlist`. Android equivalent via Expo's location plugin config. Polish copy: "Pokażemy pojazdy MPK najbliżej Ciebie."
- `.gitignore` includes `.env`, `.superpowers/`, standard Expo/RN ignores.

## Open questions

None blocking implementation. The following are intentional MVP simplifications, not unknowns:

- No backend / proxy. Acceptable for hobby scale; revisit if device polling becomes a problem.
- No analytics / crash reporting in MVP.
- No CI/CD pipeline in MVP.

## Decisions log

- **B over A/C for scope** — filter is table-stakes; stops/ETA add too much surface for MVP.
- **Expo dev client over bare RN / managed** — managed can't host MapLibre; bare is overkill.
- **MapLibre over Google/Apple/Mapbox** — no Google Maps key, uniform iOS/Android visual, free tile tier.
- **No backend** — feed is public and small (~20 KB / 10 s), direct fetch is simpler.
- **GeoJSON `ShapeSource` over per-vehicle `<Marker>`** — performance with ~100+ markers.

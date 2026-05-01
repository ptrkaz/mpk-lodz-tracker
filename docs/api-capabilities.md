# MPK Łódź API — Capabilities Reference

Snapshot of what the public `otwarte.miasto.lodz.pl` GTFS feeds expose, captured 2026-05-01. Use as reference when scoping features beyond live positions.

## Endpoints

All under `https://otwarte.miasto.lodz.pl/wp-content/uploads/2025/06/`.

| File | Size | Status | Used? |
|---|---|---|---|
| `vehicle_positions.bin` | ~9 KB | live | yes |
| `trip_updates.bin` | ~9 KB | live, populated | no |
| `alerts.bin` | 15 B | empty header (no live alerts) | no |
| `GTFS.zip` | ~50 MB compressed | static | partial — `routes.txt` only |

`GTFS.zip` contents:

| File | Size | Notes |
|---|---|---|
| `agency.txt` | 258 B | |
| `routes.txt` | 3.9 KB | already parsed → `RoutesIndex` |
| `stops.txt` | 165 KB | stop_id → name + lat/lon |
| `trips.txt` | 8.5 MB | trip_id → route_id, headsign, shape_id |
| `stop_times.txt` | **153 MB** | scheduled arrival/departure per (trip, stop_sequence) |
| `shapes.txt` | 20 MB | route polylines |
| `calendar.txt` / `calendar_dates.txt` | <6 KB | service days |
| `feed_info.txt` | 252 B | |

## Capability — delay per vehicle

**Available.** Source: `trip_updates.bin` → `FeedMessage` of `TripUpdate` ([proto:156](../proto/gtfs-realtime.proto)).

Per trip:
- `trip.trip_id` — join key
- `delay` (int32 seconds, signed; positive = late, negative = early) — trip-level current deviation
- `timestamp` — when delay was measured
- `stop_time_update[]` — per-stop `StopTimeUpdate` with finer-grained `arrival.delay` / `departure.delay`

Match vehicle → trip update via `VehiclePosition.trip.trip_id` ↔ `TripUpdate.trip.trip_id`. Current decoder ([gtfs_rt_service.dart:36](../lib/data/services/gtfs_rt_service.dart)) reads only `routeId` and drops `trip_id` — must extend `Vehicle` model and decoder to keep it.

Live sample: trips like `trip_11392_18144` (route `N5A`), `trip_11392_18182` (route `N6`), with delay fields populated.

## Capability — ETA at stops

**Available, two paths.**

### Path A — next-stop only (no static schedule needed)

`VehiclePosition` already carries ([proto:459-481](../proto/gtfs-realtime.proto)):
- `stop_id` — current/next stop
- `current_stop_sequence` — index in trip
- `current_status` — `INCOMING_AT` / `STOPPED_AT` / `IN_TRANSIT_TO` (default)

Currently dropped at decode. Adding gives "next stop: X (incoming)" in marker callout. No time prediction.

### Path B — full upcoming-stops list with ETAs

Per `TripUpdate.stop_time_update[]`:
- `arrival.time` (absolute Unix seconds) — direct ETA, no schedule lookup needed
- or `arrival.delay` (seconds) + scheduled time from `stop_times.txt`
- `stop_id` → join `stops.txt` for name + lat/lon
- Delay propagation rule: stops without an explicit update inherit the previous update's delay until the next explicit one ([proto:340-353](../proto/gtfs-realtime.proto))

## Cost considerations

- `trip_updates.bin` (~9 KB) — same poll cadence as positions, cheap. Piggyback on existing 10 s tick or add a parallel timer.
- `stops.txt` (165 KB) — load + cache like `routes.txt` (extend `GtfsStaticService` + cache).
- `trips.txt` (8.5 MB) — needed for headsign / route-of-trip resolution if `vehicle.trip.route_id` is ever absent. Streamable (parse once, persist subset).
- `stop_times.txt` (**153 MB**) — too big to load naively on mobile. Options:
  1. Skip it. Use only `arrival.time` (absolute) from `trip_updates` — sufficient for ETAs the feed publishes.
  2. Lazy parse per `trip_id` on demand by streaming the zip and filtering rows.
  3. Pre-process server-side to a slimmer index (out of scope for this app — backend-free design).

Option 1 is the cheapest path and likely complete enough — Łódź feed appears to publish absolute `arrival.time` directly.

## Suggested minimal slice for v2

1. Add `TripUpdatesService` mirroring `GtfsRtService`.
2. Extend `Vehicle` with `tripId`, `nextStopId`, `currentStatus`.
3. New `domain/models/trip_update.dart` → `{ tripId, delay, stopUpdates: [{ stopId, etaUnix, delay }] }`.
4. Extend `GtfsStaticService` to also parse `stops.txt` → `StopsIndex` (stop_id → name, lat, lon).
5. Marker-tap callout: line + last-update age + delay (`+2 min` / `−30 s`) + next stop name + ETA.
6. Defer full upcoming-stops list and `stop_times.txt` join until absolute-time ETAs prove insufficient.

## Out-of-scope feeds

- `alerts.bin` is currently empty (15-byte header). Re-check periodically; spec ([Alert](../proto/gtfs-realtime.proto)) covers service disruptions, detours, stop closures.

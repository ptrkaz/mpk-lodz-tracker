import { transit_realtime } from 'gtfs-realtime-bindings';
import { VEHICLE_POSITIONS_URL } from './endpoints';
import type { Vehicle } from './types';

export function decodeVehiclePositions(buffer: ArrayBuffer | Uint8Array): Vehicle[] {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  const feed = transit_realtime.FeedMessage.decode(bytes);
  const out: Vehicle[] = [];
  for (const entity of feed.entity) {
    if (!entity.id) continue;
    const v = entity.vehicle;
    const pos = v?.position;
    if (!v || !pos || pos.latitude == null || pos.longitude == null) continue;
    const routeId = v.trip?.routeId;
    if (!routeId) continue;
    const ts = v.timestamp;
    const vehicle: Vehicle = {
      id: entity.id,
      routeId,
      lat: pos.latitude,
      lon: pos.longitude,
      timestamp: typeof ts === 'number' ? ts : Number(ts ?? 0),
    };
    if (pos.bearing != null) vehicle.bearing = pos.bearing;
    if (pos.speed != null) vehicle.speed = pos.speed;
    out.push(vehicle);
  }
  return out;
}

export async function fetchVehiclePositions(): Promise<Vehicle[]> {
  const res = await fetch(VEHICLE_POSITIONS_URL);
  if (!res.ok) throw new Error(`GTFS-RT fetch failed: ${res.status}`);
  const buf = await res.arrayBuffer();
  return decodeVehiclePositions(buf);
}

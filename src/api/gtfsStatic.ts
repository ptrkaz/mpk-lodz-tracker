import JSZip from 'jszip';
import Papa from 'papaparse';
import { GTFS_STATIC_URL } from './endpoints';
import type { Line, RoutesIndex, VehicleType } from './types';

function routeTypeToVehicleType(rt: string): VehicleType {
  // GTFS spec: 0=tram, 3=bus
  if (rt === '0') return 'tram';
  if (rt === '3') return 'bus';
  return 'unknown';
}

export async function parseRoutesFromZip(
  buffer: ArrayBuffer | Uint8Array | Buffer,
): Promise<RoutesIndex> {
  const zip = await JSZip.loadAsync(buffer);
  const file = zip.file('routes.txt');
  if (!file) throw new Error('routes.txt missing from GTFS zip');
  const csv = await file.async('string');
  const parsed = Papa.parse<Record<string, string>>(csv, {
    header: true,
    skipEmptyLines: true,
  });
  const idx: RoutesIndex = {};
  for (const row of parsed.data) {
    const routeId = row['route_id'];
    const number = row['route_short_name'];
    const rawType = row['route_type'] ?? '';
    if (!routeId || !number) continue;
    const line: Line = {
      routeId,
      number,
      type: routeTypeToVehicleType(rawType),
    };
    idx[routeId] = line;
  }
  return idx;
}

export async function fetchAndParseRoutes(): Promise<RoutesIndex> {
  const res = await fetch(GTFS_STATIC_URL);
  if (!res.ok) throw new Error(`GTFS static fetch failed: ${res.status}`);
  const buf = await res.arrayBuffer();
  return parseRoutesFromZip(buf);
}

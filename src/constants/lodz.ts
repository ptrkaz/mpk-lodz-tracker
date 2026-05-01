export const LODZ_CENTER = { latitude: 51.7592, longitude: 19.456 } as const;
export const DEFAULT_ZOOM = 12;
export const POLL_INTERVAL_MS = 10_000;
export const ROUTES_CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export const VEHICLE_COLORS: Record<'tram' | 'bus' | 'unknown', string> = {
  tram: '#e74c3c',
  bus: '#2e86de',
  unknown: '#7f8c8d',
};

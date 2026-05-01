export type VehicleType = 'tram' | 'bus' | 'unknown';

export type Vehicle = {
  id: string;
  routeId: string;
  lat: number;
  lon: number;
  bearing?: number;
  speed?: number;
  timestamp: number; // unix seconds
};

export type Line = {
  routeId: string;
  number: string;
  type: VehicleType;
};

export type RoutesIndex = Record<string, Line>;

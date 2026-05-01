import type { Line, RoutesIndex } from './types';

export function resolveLine(routeId: string, idx: RoutesIndex): Line {
  const found = idx[routeId];
  if (found) return found;
  return { routeId, number: routeId, type: 'unknown' };
}

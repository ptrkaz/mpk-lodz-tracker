import { resolveLine } from '../lineLabel';
import type { RoutesIndex } from '../types';

describe('resolveLine', () => {
  const idx: RoutesIndex = {
    R_TRAM_8: { routeId: 'R_TRAM_8', number: '8', type: 'tram' },
  };

  it('returns the matching Line when present', () => {
    expect(resolveLine('R_TRAM_8', idx)).toEqual({
      routeId: 'R_TRAM_8',
      number: '8',
      type: 'tram',
    });
  });

  it('falls back to routeId as number with unknown type', () => {
    expect(resolveLine('R_UNKNOWN', idx)).toEqual({
      routeId: 'R_UNKNOWN',
      number: 'R_UNKNOWN',
      type: 'unknown',
    });
  });
});

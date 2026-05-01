import * as fs from 'fs';
import * as path from 'path';
import { parseRoutesFromZip, fetchAndParseRoutes } from '../gtfsStatic';

describe('parseRoutesFromZip', () => {
  it('builds a RoutesIndex from a minimal GTFS zip', async () => {
    const zip = fs.readFileSync(
      path.resolve(__dirname, '../../../__fixtures__/GTFS-mini.zip'),
    );
    const idx = await parseRoutesFromZip(zip);
    expect(idx['R_TRAM_8']).toEqual({ routeId: 'R_TRAM_8', number: '8', type: 'tram' });
    expect(idx['R_TRAM_12']).toEqual({ routeId: 'R_TRAM_12', number: '12', type: 'tram' });
    expect(idx['R_BUS_46A']).toEqual({ routeId: 'R_BUS_46A', number: '46A', type: 'bus' });
  });

  it('throws when routes.txt is missing', async () => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const JSZip = require('jszip');
    const zip = new JSZip();
    zip.file('agency.txt', 'agency_id,agency_name\nMPK,MPK');
    const buf = await zip.generateAsync({ type: 'arraybuffer' });
    await expect(parseRoutesFromZip(buf)).rejects.toThrow(/routes\.txt/);
  });
});

describe('fetchAndParseRoutes', () => {
  it('fetches and parses', async () => {
    const fixture = fs.readFileSync(
      path.resolve(__dirname, '../../../__fixtures__/GTFS-mini.zip'),
    );
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => fixture.buffer.slice(
        fixture.byteOffset,
        fixture.byteOffset + fixture.byteLength,
      ),
    }) as unknown as typeof fetch;
    const idx = await fetchAndParseRoutes();
    expect(Object.keys(idx).length).toBe(3);
  });
});

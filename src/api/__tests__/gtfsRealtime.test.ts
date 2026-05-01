import * as fs from 'fs';
import * as path from 'path';
import { decodeVehiclePositions, fetchVehiclePositions } from '../gtfsRealtime';

describe('decodeVehiclePositions', () => {
  it('decodes a real GTFS-RT fixture into typed Vehicle[]', () => {
    const buffer = fs.readFileSync(
      path.resolve(__dirname, '../../../__fixtures__/vehicle_positions.bin'),
    );
    const vehicles = decodeVehiclePositions(buffer);
    expect(vehicles.length).toBeGreaterThan(0);
    const v = vehicles[0]!;
    expect(typeof v.id).toBe('string');
    expect(typeof v.routeId).toBe('string');
    expect(v.lat).toBeGreaterThan(51);
    expect(v.lat).toBeLessThan(52);
    expect(v.lon).toBeGreaterThan(19);
    expect(v.lon).toBeLessThan(20);
    expect(typeof v.timestamp).toBe('number');
  });

  it('skips entities without a position', () => {
    // synthesize a feed with one entity that has no position
    const { transit_realtime } = require('gtfs-realtime-bindings');
    const feed = transit_realtime.FeedMessage.create({
      header: { gtfsRealtimeVersion: '2.0', incrementality: 0, timestamp: 1 },
      entity: [
        { id: 'no-pos', vehicle: { trip: { routeId: 'R1' } } },
      ],
    });
    const buf = transit_realtime.FeedMessage.encode(feed).finish();
    expect(decodeVehiclePositions(Buffer.from(buf))).toHaveLength(0);
  });
});

describe('fetchVehiclePositions', () => {
  it('fetches as ArrayBuffer and decodes', async () => {
    const fixture = fs.readFileSync(
      path.resolve(__dirname, '../../../__fixtures__/vehicle_positions.bin'),
    );
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      arrayBuffer: async () => fixture.buffer.slice(
        fixture.byteOffset,
        fixture.byteOffset + fixture.byteLength,
      ),
    }) as unknown as typeof fetch;
    const vehicles = await fetchVehiclePositions();
    expect(vehicles.length).toBeGreaterThan(0);
  });

  it('throws on non-ok response', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 503 }) as unknown as typeof fetch;
    await expect(fetchVehiclePositions()).rejects.toThrow(/503/);
  });
});

import { useVehiclesStore } from '../vehicles';

describe('vehicles store', () => {
  beforeEach(() => {
    useVehiclesStore.setState({ vehicles: [], lastUpdate: null });
  });

  it('starts empty', () => {
    expect(useVehiclesStore.getState().vehicles).toEqual([]);
    expect(useVehiclesStore.getState().lastUpdate).toBeNull();
  });

  it('replaces vehicles and stamps lastUpdate', () => {
    const before = Date.now();
    useVehiclesStore.getState().replace([
      { id: 'v1', routeId: 'R1', lat: 51.7, lon: 19.4, timestamp: 1 },
    ]);
    const s = useVehiclesStore.getState();
    expect(s.vehicles).toHaveLength(1);
    expect(s.lastUpdate).not.toBeNull();
    expect(s.lastUpdate!).toBeGreaterThanOrEqual(before);
  });
});

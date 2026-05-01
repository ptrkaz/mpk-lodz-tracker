import { useFilterStore } from '../filter';

describe('filter store', () => {
  beforeEach(() => {
    useFilterStore.setState({ selectedRouteIds: new Set(), activeTab: 'tram' });
  });

  it('starts with empty selection on tram tab', () => {
    const s = useFilterStore.getState();
    expect(s.selectedRouteIds.size).toBe(0);
    expect(s.activeTab).toBe('tram');
  });

  it('toggles a route id', () => {
    useFilterStore.getState().toggle('R1');
    expect(useFilterStore.getState().selectedRouteIds.has('R1')).toBe(true);
    useFilterStore.getState().toggle('R1');
    expect(useFilterStore.getState().selectedRouteIds.has('R1')).toBe(false);
  });

  it('clear() empties the selection', () => {
    useFilterStore.getState().toggle('R1');
    useFilterStore.getState().toggle('R2');
    useFilterStore.getState().clear();
    expect(useFilterStore.getState().selectedRouteIds.size).toBe(0);
  });

  it('switches tab', () => {
    useFilterStore.getState().setTab('bus');
    expect(useFilterStore.getState().activeTab).toBe('bus');
  });
});

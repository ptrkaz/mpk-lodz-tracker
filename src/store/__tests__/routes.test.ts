import { useRoutesStore } from '../routes';

describe('routes store', () => {
  beforeEach(() => {
    useRoutesStore.setState({ index: {}, ready: false });
  });

  it('starts empty and not ready', () => {
    const s = useRoutesStore.getState();
    expect(s.index).toEqual({});
    expect(s.ready).toBe(false);
  });

  it('setIndex marks ready', () => {
    useRoutesStore.getState().setIndex({
      R1: { routeId: 'R1', number: '8', type: 'tram' },
    });
    const s = useRoutesStore.getState();
    expect(s.ready).toBe(true);
    expect(s.index['R1']!.number).toBe('8');
  });
});

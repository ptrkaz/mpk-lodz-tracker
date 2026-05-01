import { renderHook, act, waitFor } from '@testing-library/react-native';
import { AppState } from 'react-native';
import { useVehiclesStore } from '../../store/vehicles';

const mockFetchVehiclePositions = jest.fn();
jest.mock('../../api/gtfsRealtime', () => ({
  fetchVehiclePositions: () => mockFetchVehiclePositions(),
}));

import { useVehiclePolling } from '../useVehiclePolling';

describe('useVehiclePolling', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.clearAllMocks();
    useVehiclesStore.setState({ vehicles: [], lastUpdate: null });
    mockFetchVehiclePositions.mockResolvedValue([]);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('fetches immediately and writes to store', async () => {
    mockFetchVehiclePositions.mockResolvedValue([
      { id: 'v1', routeId: 'R1', lat: 51.7, lon: 19.4, timestamp: 1 },
    ]);
    renderHook(() => useVehiclePolling());
    await waitFor(() => expect(useVehiclesStore.getState().vehicles).toHaveLength(1));
  });

  it('repeats every 10 s', async () => {
    mockFetchVehiclePositions.mockResolvedValue([]);
    renderHook(() => useVehiclePolling());
    await waitFor(() => expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(1));
    await act(async () => {
      jest.advanceTimersByTime(10_000);
    });
    expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(2);
    await act(async () => {
      jest.advanceTimersByTime(10_000);
    });
    expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(3);
  });

  it('does not crash on fetch error', async () => {
    mockFetchVehiclePositions.mockRejectedValue(new Error('offline'));
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    renderHook(() => useVehiclePolling());
    await waitFor(() => expect(mockFetchVehiclePositions).toHaveBeenCalled());
    expect(useVehiclesStore.getState().vehicles).toEqual([]);
    spy.mockRestore();
  });

  it('pauses when app backgrounds', async () => {
    mockFetchVehiclePositions.mockResolvedValue([]);
    let listener: ((s: string) => void) | null = null;
    const sub = { remove: jest.fn() };
    jest.spyOn(AppState, 'addEventListener').mockImplementation((_event, cb) => {
      listener = cb as (s: string) => void;
      return sub as unknown as ReturnType<typeof AppState.addEventListener>;
    });

    renderHook(() => useVehiclePolling());
    await waitFor(() => expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(1));

    act(() => listener?.('background'));

    await act(async () => {
      jest.advanceTimersByTime(30_000);
    });
    expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(1);

    act(() => listener?.('active'));
    await waitFor(() => expect(mockFetchVehiclePositions).toHaveBeenCalledTimes(2));
  });
});

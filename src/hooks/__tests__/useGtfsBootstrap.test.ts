import { renderHook, waitFor } from '@testing-library/react-native';
import { useRoutesStore } from '../../store/routes';

const mockReadAsString = jest.fn();
const mockWriteAsString = jest.fn().mockResolvedValue(undefined);
const mockGetInfo = jest.fn();

jest.mock('expo-file-system/legacy', () => ({
  documentDirectory: '/doc/',
  readAsStringAsync: (...a: unknown[]) => mockReadAsString(...a),
  writeAsStringAsync: (...a: unknown[]) => mockWriteAsString(...a),
  getInfoAsync: (...a: unknown[]) => mockGetInfo(...a),
}));

const mockFetchAndParseRoutes = jest.fn();
jest.mock('../../api/gtfsStatic', () => ({
  fetchAndParseRoutes: () => mockFetchAndParseRoutes(),
}));

import { useGtfsBootstrap } from '../useGtfsBootstrap';

describe('useGtfsBootstrap', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    useRoutesStore.setState({ index: {}, ready: false });
  });

  it('uses fresh cache without downloading', async () => {
    mockGetInfo.mockResolvedValue({
      exists: true,
      modificationTime: Date.now() / 1000 - 60, // 1 min old
    });
    mockReadAsString.mockResolvedValue(
      JSON.stringify({ R1: { routeId: 'R1', number: '8', type: 'tram' } }),
    );

    renderHook(() => useGtfsBootstrap());

    await waitFor(() => expect(useRoutesStore.getState().ready).toBe(true));
    expect(useRoutesStore.getState().index['R1']!.number).toBe('8');
    expect(mockFetchAndParseRoutes).not.toHaveBeenCalled();
  });

  it('refreshes when cache is stale', async () => {
    mockGetInfo.mockResolvedValue({
      exists: true,
      modificationTime: Date.now() / 1000 - 8 * 24 * 60 * 60, // 8 days old
    });
    mockFetchAndParseRoutes.mockResolvedValue({
      R2: { routeId: 'R2', number: '12', type: 'tram' },
    });

    renderHook(() => useGtfsBootstrap());

    await waitFor(() => expect(useRoutesStore.getState().ready).toBe(true));
    expect(mockFetchAndParseRoutes).toHaveBeenCalledTimes(1);
    expect(mockWriteAsString).toHaveBeenCalled();
    expect(useRoutesStore.getState().index['R2']!.number).toBe('12');
  });

  it('downloads when cache is missing', async () => {
    mockGetInfo.mockResolvedValue({ exists: false });
    mockFetchAndParseRoutes.mockResolvedValue({
      R3: { routeId: 'R3', number: '46A', type: 'bus' },
    });

    renderHook(() => useGtfsBootstrap());

    await waitFor(() => expect(useRoutesStore.getState().ready).toBe(true));
    expect(mockFetchAndParseRoutes).toHaveBeenCalledTimes(1);
  });

  it('leaves store empty if download fails (does not throw)', async () => {
    mockGetInfo.mockResolvedValue({ exists: false });
    mockFetchAndParseRoutes.mockRejectedValue(new Error('boom'));
    const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    renderHook(() => useGtfsBootstrap());

    await waitFor(() => expect(mockFetchAndParseRoutes).toHaveBeenCalled());
    expect(useRoutesStore.getState().ready).toBe(false);
    consoleSpy.mockRestore();
  });
});

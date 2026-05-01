import { useEffect, useRef } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { fetchVehiclePositions } from '../api/gtfsRealtime';
import { useVehiclesStore } from '../store/vehicles';
import { POLL_INTERVAL_MS } from '../constants/lodz';

export function useVehiclePolling(): void {
  const replace = useVehiclesStore((s) => s.replace);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const cancelledRef = useRef(false);

  useEffect(() => {
    cancelledRef.current = false;

    const tick = async () => {
      try {
        const v = await fetchVehiclePositions();
        if (!cancelledRef.current) replace(v);
      } catch (err) {
        console.error('[useVehiclePolling]', err);
      }
    };

    const start = () => {
      if (intervalRef.current != null) return;
      void tick();
      intervalRef.current = setInterval(tick, POLL_INTERVAL_MS);
    };

    const stop = () => {
      if (intervalRef.current != null) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };

    start();

    const onAppStateChange = (state: AppStateStatus) => {
      if (state === 'active') start();
      else stop();
    };
    const sub = AppState.addEventListener('change', onAppStateChange);

    return () => {
      cancelledRef.current = true;
      stop();
      sub.remove();
    };
  }, [replace]);
}

import { useEffect } from 'react';
import * as FileSystem from 'expo-file-system/legacy';
import { fetchAndParseRoutes } from '../api/gtfsStatic';
import { useRoutesStore } from '../store/routes';
import { ROUTES_CACHE_TTL_MS } from '../constants/lodz';
import type { RoutesIndex } from '../api/types';

const CACHE_FILE = `${FileSystem.documentDirectory}routes.json`;

async function loadFreshCache(): Promise<RoutesIndex | null> {
  const info = await FileSystem.getInfoAsync(CACHE_FILE);
  if (!info.exists) return null;
  const ageMs = Date.now() - (info.modificationTime ?? 0) * 1000;
  if (ageMs > ROUTES_CACHE_TTL_MS) return null;
  const json = await FileSystem.readAsStringAsync(CACHE_FILE);
  return JSON.parse(json) as RoutesIndex;
}

async function refresh(): Promise<RoutesIndex> {
  const idx = await fetchAndParseRoutes();
  await FileSystem.writeAsStringAsync(CACHE_FILE, JSON.stringify(idx));
  return idx;
}

export function useGtfsBootstrap(): void {
  const setIndex = useRoutesStore((s) => s.setIndex);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const cached = await loadFreshCache();
        if (cancelled) return;
        if (cached) {
          setIndex(cached);
          return;
        }
        const fresh = await refresh();
        if (cancelled) return;
        setIndex(fresh);
      } catch (err) {
        console.error('[useGtfsBootstrap]', err);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [setIndex]);
}

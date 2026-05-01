import React, { useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as Location from 'expo-location';
import Constants from 'expo-constants';
import { Map, Camera, type CameraRef } from '@maplibre/maplibre-react-native';
import { useGtfsBootstrap } from '../hooks/useGtfsBootstrap';
import { useVehiclePolling } from '../hooks/useVehiclePolling';
import { useVehiclesStore } from '../store/vehicles';
import { useRoutesStore } from '../store/routes';
import { useFilterStore } from '../store/filter';
import { VehicleMarkers } from '../components/VehicleMarkers';
import { LastUpdateHint } from '../components/LastUpdateHint';
import { FilterSheet, type FilterSheetHandle } from './FilterSheet';
import { LODZ_CENTER, DEFAULT_ZOOM } from '../constants/lodz';
import { pl } from '../i18n/pl';

const maptilerKey =
  (Constants.expoConfig?.extra as { maptilerKey?: string } | undefined)?.maptilerKey ?? '';
const STYLE_URL = `https://api.maptiler.com/maps/streets/style.json?key=${maptilerKey}`;

export function MapScreen(): React.JSX.Element {
  useGtfsBootstrap();
  useVehiclePolling();

  const vehicles = useVehiclesStore((s) => s.vehicles);
  const routes = useRoutesStore((s) => s.index);
  const selected = useFilterStore((s) => s.selectedRouteIds);
  const sheetRef = useRef<FilterSheetHandle>(null);
  const cameraRef = useRef<CameraRef>(null);
  const [_locating, setLocating] = useState(false);

  const visible = useMemo(
    () => (selected.size === 0 ? vehicles : vehicles.filter((v) => selected.has(v.routeId))),
    [vehicles, selected],
  );

  const chipLabel =
    selected.size === 0 ? pl.filter.chipAll : pl.filter.chipSome(selected.size);

  const handleLocate = async () => {
    setLocating(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;
      const pos = await Location.getCurrentPositionAsync({});
      cameraRef.current?.flyTo({
        center: [pos.coords.longitude, pos.coords.latitude],
        zoom: 14,
        duration: 600,
      });
    } finally {
      setLocating(false);
    }
  };

  return (
    <View style={styles.root}>
      <Map style={styles.map} mapStyle={STYLE_URL}>
        <Camera
          ref={cameraRef}
          initialViewState={{
            center: [LODZ_CENTER.longitude, LODZ_CENTER.latitude],
            zoom: DEFAULT_ZOOM,
          }}
        />
        <VehicleMarkers vehicles={visible} routes={routes} />
      </Map>

      <Pressable style={styles.chip} onPress={() => sheetRef.current?.open()}>
        <Text style={styles.chipText}>{chipLabel}</Text>
      </Pressable>

      <Pressable style={styles.fab} onPress={handleLocate}>
        <Text style={styles.fabIcon}>📍</Text>
      </Pressable>

      <LastUpdateHint />
      <FilterSheet ref={sheetRef} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  map: { flex: 1 },
  chip: {
    position: 'absolute',
    top: 60,
    left: 12,
    right: 12,
    backgroundColor: '#fff',
    borderRadius: 22,
    paddingHorizontal: 14,
    paddingVertical: 10,
    shadowColor: '#000',
    shadowOpacity: 0.15,
    shadowOffset: { width: 0, height: 1 },
    shadowRadius: 3,
    elevation: 2,
  },
  chipText: { fontSize: 13, color: '#222', fontWeight: '600' },
  fab: {
    position: 'absolute',
    bottom: 16,
    right: 12,
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowOffset: { width: 0, height: 1 },
    shadowRadius: 3,
    elevation: 3,
  },
  fabIcon: { fontSize: 20 },
});

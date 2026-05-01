import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useVehiclesStore } from '../store/vehicles';
import { pl } from '../i18n/pl';

export function LastUpdateHint(): React.JSX.Element | null {
  const lastUpdate = useVehiclesStore((s) => s.lastUpdate);
  const [, force] = useState(0);

  useEffect(() => {
    const id = setInterval(() => force((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, []);

  if (lastUpdate == null) return null;
  const ageSec = Math.max(0, Math.round((Date.now() - lastUpdate) / 1000));
  return (
    <View style={styles.box} pointerEvents="none">
      <Text style={styles.text}>{pl.map.lastUpdate(ageSec)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    position: 'absolute',
    bottom: 16,
    left: 12,
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 4,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  text: { fontSize: 11, color: '#444' },
});

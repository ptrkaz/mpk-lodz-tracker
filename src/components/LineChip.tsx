import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { VEHICLE_COLORS } from '../constants/lodz';
import type { VehicleType } from '../api/types';

type Props = {
  number: string;
  type: VehicleType;
  selected: boolean;
  onPress: () => void;
};

export function LineChip({ number, type, selected, onPress }: Props): React.JSX.Element {
  const color = VEHICLE_COLORS[type];
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.chip,
        { borderColor: color },
        selected && { backgroundColor: color },
      ]}
    >
      <Text style={[styles.text, selected && { color: '#fff' }]}>{number}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderRadius: 16,
    marginRight: 6,
    marginBottom: 6,
    backgroundColor: '#fff',
  },
  text: { fontSize: 13, color: '#222', fontWeight: '600' },
});

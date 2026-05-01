import React, { forwardRef, useImperativeHandle, useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, TextInput, View, Pressable, ScrollView } from 'react-native';
import BottomSheet, { BottomSheetView } from '@gorhom/bottom-sheet';
import { useRoutesStore } from '../store/routes';
import { useFilterStore } from '../store/filter';
import { LineChip } from '../components/LineChip';
import { pl } from '../i18n/pl';
import type { Line } from '../api/types';

export type FilterSheetHandle = {
  open: () => void;
  close: () => void;
};

export const FilterSheet = forwardRef<FilterSheetHandle>((_props, ref) => {
  const sheetRef = useRef<BottomSheet>(null);
  const index = useRoutesStore((s) => s.index);
  const activeTab = useFilterStore((s) => s.activeTab);
  const setTab = useFilterStore((s) => s.setTab);
  const selected = useFilterStore((s) => s.selectedRouteIds);
  const toggle = useFilterStore((s) => s.toggle);
  const clear = useFilterStore((s) => s.clear);
  const [query, setQuery] = useState('');

  useImperativeHandle(ref, () => ({
    open: () => sheetRef.current?.expand(),
    close: () => sheetRef.current?.close(),
  }));

  const lines: Line[] = useMemo(() => {
    const all = Object.values(index).filter((l) => l.type === activeTab);
    const q = query.trim().toLowerCase();
    const filtered = q ? all.filter((l) => l.number.toLowerCase().includes(q)) : all;
    return filtered.sort((a, b) =>
      a.number.localeCompare(b.number, undefined, { numeric: true }),
    );
  }, [index, activeTab, query]);

  return (
    <BottomSheet
      ref={sheetRef}
      index={-1}
      snapPoints={['60%']}
      enablePanDownToClose
    >
      <BottomSheetView style={styles.body}>
        <Text style={styles.title}>{pl.filter.title}</Text>

        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder={pl.filter.searchPlaceholder}
          style={styles.input}
        />

        <View style={styles.tabs}>
          <Pressable
            onPress={() => setTab('tram')}
            style={[styles.tab, activeTab === 'tram' && styles.tabActive]}
          >
            <Text style={[styles.tabText, activeTab === 'tram' && styles.tabTextActive]}>
              {pl.filter.tabTram}
            </Text>
          </Pressable>
          <Pressable
            onPress={() => setTab('bus')}
            style={[styles.tab, activeTab === 'bus' && styles.tabActive]}
          >
            <Text style={[styles.tabText, activeTab === 'bus' && styles.tabTextActive]}>
              {pl.filter.tabBus}
            </Text>
          </Pressable>
        </View>

        <ScrollView contentContainerStyle={styles.chips}>
          {lines.map((l) => (
            <LineChip
              key={l.routeId}
              number={l.number}
              type={l.type}
              selected={selected.has(l.routeId)}
              onPress={() => toggle(l.routeId)}
            />
          ))}
        </ScrollView>

        <View style={styles.actions}>
          <Pressable onPress={clear} style={[styles.btn, styles.btnSecondary]}>
            <Text style={styles.btnSecondaryText}>{pl.filter.clear}</Text>
          </Pressable>
          <Pressable
            onPress={() => sheetRef.current?.close()}
            style={[styles.btn, styles.btnPrimary]}
          >
            <Text style={styles.btnPrimaryText}>{pl.filter.apply}</Text>
          </Pressable>
        </View>
      </BottomSheetView>
    </BottomSheet>
  );
});
FilterSheet.displayName = 'FilterSheet';

const styles = StyleSheet.create({
  body: { flex: 1, padding: 16 },
  title: { fontSize: 16, fontWeight: '700', marginBottom: 10, color: '#222' },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
    marginBottom: 10,
  },
  tabs: { flexDirection: 'row', marginBottom: 10 },
  tab: {
    flex: 1,
    paddingVertical: 8,
    alignItems: 'center',
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
  tabActive: { borderBottomColor: '#4a90e2' },
  tabText: { color: '#666' },
  tabTextActive: { color: '#222', fontWeight: '700' },
  chips: { flexDirection: 'row', flexWrap: 'wrap', paddingBottom: 16 },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 10 },
  btn: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  btnPrimary: { backgroundColor: '#4a90e2' },
  btnPrimaryText: { color: '#fff', fontWeight: '700' },
  btnSecondary: { backgroundColor: '#eee' },
  btnSecondaryText: { color: '#333' },
});

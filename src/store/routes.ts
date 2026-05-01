import { create } from 'zustand';
import type { RoutesIndex } from '../api/types';

type RoutesState = {
  index: RoutesIndex;
  ready: boolean;
  setIndex: (idx: RoutesIndex) => void;
};

export const useRoutesStore = create<RoutesState>((set) => ({
  index: {},
  ready: false,
  setIndex: (idx) => set({ index: idx, ready: true }),
}));

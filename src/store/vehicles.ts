import { create } from 'zustand';
import type { Vehicle } from '../api/types';

type VehiclesState = {
  vehicles: Vehicle[];
  lastUpdate: number | null;
  replace: (next: Vehicle[]) => void;
};

export const useVehiclesStore = create<VehiclesState>((set) => ({
  vehicles: [],
  lastUpdate: null,
  replace: (next) => set({ vehicles: next, lastUpdate: Date.now() }),
}));

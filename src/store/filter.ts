import { create } from 'zustand';

type Tab = 'tram' | 'bus';

type FilterState = {
  selectedRouteIds: Set<string>;
  activeTab: Tab;
  toggle: (routeId: string) => void;
  clear: () => void;
  setTab: (tab: Tab) => void;
};

export const useFilterStore = create<FilterState>((set) => ({
  selectedRouteIds: new Set<string>(),
  activeTab: 'tram',
  toggle: (routeId) =>
    set((s) => {
      const next = new Set(s.selectedRouteIds);
      if (next.has(routeId)) next.delete(routeId);
      else next.add(routeId);
      return { selectedRouteIds: next };
    }),
  clear: () => set({ selectedRouteIds: new Set<string>() }),
  setTab: (tab) => set({ activeTab: tab }),
}));

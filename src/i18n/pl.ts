export const pl = {
  filter: {
    chipAll: 'Wszystkie linie',
    chipSome: (n: number) => `${n} ${n === 1 ? 'linia' : 'linie'}`,
    title: 'Filtruj linie',
    searchPlaceholder: 'Szukaj linii…',
    tabTram: 'Tramwaje',
    tabBus: 'Autobusy',
    apply: 'Zastosuj',
    clear: 'Wyczyść',
  },
  map: {
    lastUpdate: (sec: number) => `aktualizacja: ${sec}s temu`,
    loading: 'Ładowanie pozycji…',
    offline: 'Brak połączenia, ponawiam…',
  },
  marker: {
    tram: (n: string) => `Tramwaj ${n}`,
    bus: (n: string) => `Autobus ${n}`,
    unknown: (n: string) => `Linia ${n}`,
    ago: (sec: number) => `${sec}s temu`,
  },
  permissions: {
    locationDenied: 'Brak dostępu do lokalizacji',
  },
} as const;

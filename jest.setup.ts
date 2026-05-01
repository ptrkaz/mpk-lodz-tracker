/// <reference types="jest" />
import '@testing-library/jest-native/extend-expect';

// expo/src/winter/runtime.native.ts installs multiple lazy enumerable getters on
// globalThis (TextDecoder, URL, structuredClone, __ExpoImportMetaRegistry, etc.).
// During jest teardown, resetModules() clears the module registry then iterates
// Object.keys(global), triggering these getters. At that point the module registry
// is empty and isInsideTestCode=false, so jest-runtime throws
// "You are trying to import a file outside of the scope of the test code."
//
// Fix: redefine all getter-based properties on globalThis as non-enumerable so
// they are skipped by Object.keys() during teardown.
for (const name of Object.getOwnPropertyNames(globalThis)) {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, name);
  if (descriptor && typeof descriptor.get === 'function' && descriptor.enumerable) {
    Object.defineProperty(globalThis, name, { ...descriptor, enumerable: false });
  }
}

jest.mock('react-native-reanimated', () =>
  require('react-native-reanimated/mock'),
);

jest.mock('@maplibre/maplibre-react-native', () => ({
  __esModule: true,
  default: {},
  MapView: 'MapView',
  Camera: 'Camera',
  ShapeSource: 'ShapeSource',
  SymbolLayer: 'SymbolLayer',
  setAccessToken: jest.fn(),
}));

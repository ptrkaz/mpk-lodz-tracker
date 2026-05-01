/// <reference types="jest" />
import '@testing-library/jest-native/extend-expect';

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

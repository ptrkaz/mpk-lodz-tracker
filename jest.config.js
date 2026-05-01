module.exports = {
  preset: 'jest-expo',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  transformIgnorePatterns: [
    '/node_modules/(?!(.pnpm|react-native|@react-native|@react-native-community|expo|@expo|@expo-google-fonts|react-navigation|@react-navigation|@sentry/react-native|native-base|@gorhom|@maplibre))',
    // Exclude reanimated babel plugin to avoid missing react-native-worklets peer dep
    '/node_modules/react-native-reanimated/plugin/',
  ],
  moduleNameMapper: {
    // Prevent expo's lazy ImportMetaRegistry getter from calling require()
    // during jest teardown (when isInsideTestCode=false), which causes
    // "import outside scope" errors. The getter is enumerable and triggered
    // by Object.keys(global) in Runtime.resetModules.
    'expo/src/winter/ImportMetaRegistry$': '<rootDir>/__mocks__/expo-import-meta-registry.js',
    '.*/expo/src/winter/ImportMetaRegistry$': '<rootDir>/__mocks__/expo-import-meta-registry.js',
  },
};

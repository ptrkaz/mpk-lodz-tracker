// Mock for expo/src/winter/ImportMetaRegistry.
// The real module uses static `import` and is lazily required during jest teardown
// (triggered by Object.keys(global) enumerating the __ExpoImportMetaRegistry getter).
// At teardown isInsideTestCode=false, causing jest-runtime to throw.
module.exports = {
  ImportMetaRegistry: { url: '' },
};

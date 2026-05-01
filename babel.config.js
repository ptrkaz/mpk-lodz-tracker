module.exports = function (api) {
  api.cache(true);
  const isTest = process.env.NODE_ENV === 'test';
  return {
    presets: [
      [
        'expo/node_modules/babel-preset-expo',
        // Disable reanimated plugin in test env: react-native-worklets peer dep is not installed
        ...(isTest ? [{ reanimated: false }] : []),
      ],
    ],
    plugins: isTest ? [] : ['react-native-reanimated/plugin'], // must be last
  };
};

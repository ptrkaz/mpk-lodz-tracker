const { withAndroidManifest, withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

const ASSETS = path.join(__dirname, 'assets');

const withCertumNetworkSecurity = (config) => {
  config = withAndroidManifest(config, (cfg) => {
    const app = cfg.modResults.manifest.application?.[0];
    if (app) app.$['android:networkSecurityConfig'] = '@xml/network_security_config';
    return cfg;
  });

  config = withDangerousMod(config, [
    'android',
    async (cfg) => {
      const platformRoot = cfg.modRequest.platformProjectRoot;
      const rawDir = path.join(platformRoot, 'app/src/main/res/raw');
      const xmlDir = path.join(platformRoot, 'app/src/main/res/xml');
      fs.mkdirSync(rawDir, { recursive: true });
      fs.mkdirSync(xmlDir, { recursive: true });
      fs.copyFileSync(
        path.join(ASSETS, 'certum_root_ca.pem'),
        path.join(rawDir, 'certum_root_ca.pem'),
      );
      fs.copyFileSync(
        path.join(ASSETS, 'network_security_config.xml'),
        path.join(xmlDir, 'network_security_config.xml'),
      );
      return cfg;
    },
  ]);

  return config;
};

module.exports = withCertumNetworkSecurity;

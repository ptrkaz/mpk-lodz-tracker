import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network security config trusts MapTiler chain explicitly', () {
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    final cert = File('android/app/src/main/res/raw/gts_root_r4.pem');

    expect(
      config,
      contains('<domain includeSubdomains="true">maptiler.com</domain>'),
    );
    expect(config, contains('<certificates src="@raw/gts_root_r4"/>'));
    expect(cert.existsSync(), isTrue);
  });
}

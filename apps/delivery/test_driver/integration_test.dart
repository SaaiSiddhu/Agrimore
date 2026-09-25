import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every screenshot the on-device tour takes into the operational run
/// directory (/Users/saai_siddharth/.agrimore/run/delivery-ui-redesign/screenshots/android/).
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final home = Platform.environment['HOME'] ?? '/Users/saai_siddharth';
    final file = File(
      '$home/.agrimore/run/delivery-ui-redesign/screenshots/android/$name.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);

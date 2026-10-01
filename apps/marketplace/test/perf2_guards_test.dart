// PERF-2 home/GPS source-shape guard retains the location timeout regression.
// Shared authentication now has native behavioral request/role checks instead.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PERF-2 source-shape guards', () {
    test(
      'home_app_bar.dart: no 10-second location-fix wait left anywhere '
      '(the "minimum 10 seconds" bug)',
      () async {
        final source = await File(
          '${Directory.current.path}/lib/screens/user/home/widgets/home_app_bar.dart',
        ).readAsString();

        expect(
          source.contains('Duration(seconds: 10)'),
          isFalse,
          reason: 'A 10-second Duration literal is back in home_app_bar.dart '
              '— this is what produced "minimum 10 seconds" on every Home '
              'load whenever there was no cached GPS fix (PERF-2 '
              'regression). Use the shared _kLocationFixTimeout constant.',
        );
        expect(
          source.contains('_kLocationFixTimeout'),
          isTrue,
          reason: 'the shared timeout constant is missing — has the '
              'location-fetch method been restructured?',
        );
      },
    );

    // The old auth parallel-read guard was retired in F2.11: profile reads
    // no longer fetch email hints or mutate roles. Actual native request-count
    // and role controls live in foundation_shared_auth_session_test.dart.
  });
}

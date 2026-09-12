// PERF-2 source-shape regression guards. Same rationale as PERF-1's own
// guards in product_provider_test.dart: a timing-based behavioral proof
// would need either a real GPS/platform-channel mock (Geolocator) or
// Firestore mocking (fake_cloud_firestore, not a dependency here) to
// reliably distinguish the fixed shape from the pre-fix one — deliberately
// not added just for this. These assert the committed source directly, so
// they fail loudly if either regression comes back, which a written PR
// description alone would not catch.
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

    test(
      'auth_service.dart: getUserData starts the admin-allowlist read '
      'before awaiting the user-doc read (must stay concurrent, not '
      'sequential)',
      () async {
        final source = await File(
          '${Directory.current.path}/../../packages/agrimore_services/lib/auth/auth_service.dart',
        ).readAsString();

        final getUserDataIndex =
            source.indexOf('Future<UserModel> getUserData(String uid) async {');
        expect(getUserDataIndex, greaterThan(-1),
            reason: 'getUserData not found — has it moved/renamed?');

        // Scope the search to this method's own body only (up to the next
        // top-level method, checkUserExists) so a match elsewhere in the
        // file can't produce a false pass.
        final nextMethodIndex =
            source.indexOf('Future<bool> checkUserExists(', getUserDataIndex);
        expect(nextMethodIndex, greaterThan(getUserDataIndex));
        final methodBody =
            source.substring(getUserDataIndex, nextMethodIndex);

        final allowFutureIndex = methodBody.indexOf('_adminAllowlistEmailsLower()');
        final awaitDocIndex = methodBody.indexOf('await docFuture');

        expect(allowFutureIndex, greaterThan(-1),
            reason: 'the admin-allowlist read is no longer started inside '
                'getUserData — has _syncRoleWithAdminPolicy gone back to '
                'fetching it internally?');
        expect(awaitDocIndex, greaterThan(-1),
            reason: 'the user-doc read no longer goes through a named '
                '"docFuture" — has getUserData been restructured?');
        expect(
          allowFutureIndex,
          lessThan(awaitDocIndex),
          reason: 'the admin-allowlist read now starts AFTER the user-doc '
              'read is awaited — the two Firestore round trips are '
              'sequential again instead of concurrent (PERF-2 regression). '
              'Every logged-in app launch goes through this method while '
              'AuthWrapper shows a blocking spinner.',
        );
      },
    );
  });
}

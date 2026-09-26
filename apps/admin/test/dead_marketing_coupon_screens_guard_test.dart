// ADMR-10 — dead marketing coupon screens removed.
//
// apps/admin/lib/screens/admin/ had two complete, independent coupon
// management implementations: coupon/ (374 lines, the active one — every
// real navigation entry point in app_router.dart, admin_dashboard.dart and
// admin_main_screen.dart imports and instantiates it) and marketing/ (1,730
// lines across 6 files, both defining a class literally named
// CouponManagementScreen). Confirmed by exhaustive grep in both directions
// that nothing anywhere — no import, no named route, no string reference —
// ever pointed at marketing/ or any of its 4 widget files; it compiled
// cleanly (flutter analyze: 0 errors) despite being fully unreachable,
// meaning it was very likely a superseded rewrite's predecessor that was
// never deleted, not a still-wiring-up feature.
//
// This guard is a plain file-existence check, not a source-grep — the
// simplest, most direct assertion for "this code no longer exists at all".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-10 dead marketing coupon screens removed', () {
    test('the entire unreachable marketing/ screen directory is gone', () {
      final dir = Directory('${Directory.current.path}/lib/screens/admin/marketing');
      expect(
        dir.existsSync(),
        isFalse,
        reason:
            'apps/admin/lib/screens/admin/marketing/ is back — this was a '
            'confirmed-dead duplicate of coupon/coupon_management_screen.dart '
            '(same class name, zero navigation entry points anywhere in the '
            'app). If a real marketing feature is being added here, this '
            'guard should be removed deliberately, not silently defeated by '
            're-creating a same-named directory.',
      );
    });

    test('the active coupon management screen is untouched and still the '
        'only one wired into navigation', () {
      final active = File(
        '${Directory.current.path}/lib/screens/admin/coupon/coupon_management_screen.dart',
      );
      expect(active.existsSync(), isTrue,
          reason: 'the ACTIVE coupon_management_screen.dart is missing — '
              'this phase must not have removed the wrong one.');

      final router = File(
        '${Directory.current.path}/lib/app/app_router.dart',
      ).readAsStringSync();
      expect(
        router.contains("coupon/coupon_management_screen.dart"),
        isTrue,
        reason: 'app_router.dart no longer imports the active coupon '
            'management screen — has coupon routing been restructured?',
      );
    });
  });
}

// ADMR-14 — dead admin seller panel removed.
//
// apps/admin/lib/screens/seller/ (NOT screens/admin/sellers/, the real,
// active seller-management area) held three files -- seller_apply_screen
// .dart, seller_dashboard_screen.dart, seller_panel_screen.dart, 1,421
// lines total -- with zero reachability from app_router.dart,
// admin_main_screen.dart, admin_dashboard.dart, admin_shell.dart or
// main.dart, confirmed by exhaustive grep in both directions. It compiled
// cleanly (flutter analyze: 0 errors) despite being fully unreachable,
// consistent with legacy code from before apps/seller existed as its own
// standalone app, never deleted.
//
// This guard is a plain file-existence check, matching ADMR-10's own
// precedent for exactly this class of finding.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-14 dead admin seller panel removed', () {
    test('the entire unreachable screens/seller/ directory is gone', () {
      final dir = Directory('${Directory.current.path}/lib/screens/seller');
      expect(
        dir.existsSync(),
        isFalse,
        reason:
            'apps/admin/lib/screens/seller/ is back — this was confirmed-dead '
            'code (seller_apply_screen.dart, seller_dashboard_screen.dart, '
            'seller_panel_screen.dart) with zero navigation entry points '
            'anywhere in the app. If a real in-admin seller panel is being '
            'added, this guard should be removed deliberately, not silently '
            'defeated by re-creating a same-named directory.',
      );
    });

    test('the real seller-management area and the live SellerProvider are '
        'untouched', () {
      final activeScreen = File(
        '${Directory.current.path}/lib/screens/admin/sellers/manage_sellers_screen.dart',
      );
      expect(activeScreen.existsSync(), isTrue,
          reason: 'the ACTIVE seller-management screen '
              '(screens/admin/sellers/) is missing — this phase must not '
              'have removed the wrong directory.');

      final provider = File(
        '${Directory.current.path}/lib/providers/seller_provider.dart',
      );
      expect(provider.existsSync(), isTrue,
          reason: 'seller_provider.dart is missing — it has real, live '
              'consumers elsewhere (main.dart, bestseller screens) and must '
              'never be removed by this guard\'s own finding.');
    });
  });
}

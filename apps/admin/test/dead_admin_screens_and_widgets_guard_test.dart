// ADMR-55 — dead admin screens and widgets removed.
//
// Seven files, 2,017 lines total, confirmed genuinely unreachable from
// anywhere in apps/admin by three independent methods per file (a
// bare-string class-name grep across the whole app, an import-statement
// grep across the whole app, and an app_router.dart-specific route-table
// grep):
//   - admin_main_screen.dart (941 lines): an older bottom-nav-style shell,
//     superseded by AdminShell's own ShellRoute-based architecture in
//     app_router.dart. ADMR-10's own comment once credited this file with
//     being a real navigation entry point for CouponManagementScreen —
//     confirmed stale, not still true: that screen is independently still
//     reachable via app_router.dart directly, so nothing regressed.
//   - products/add_product_screen.dart (339) and products/
//     edit_product_screen.dart (375): superseded by the unified
//     ProductFormScreen, which app_router.dart's productNew/productEdit
//     routes both already build.
//   - users/widgets/user_stats_card.dart (106), users/widgets/
//     user_filter_chip.dart (86), orders/widgets/order_stats.dart (87),
//     orders/widgets/order_filter.dart (83): zero importers anywhere,
//     confirmed no barrel/re-export file exists in either widgets/
//     directory that could be hiding an indirect usage.
//
// flutter analyze: 0 errors with all seven gone. This guard is a plain
// file-existence check, matching ADMR-10's/ADMR-14's own established
// precedent for exactly this class of finding.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-55 dead admin screens and widgets removed', () {
    test('the seven confirmed-dead files are gone', () {
      final deadPaths = [
        'lib/screens/admin/admin_main_screen.dart',
        'lib/screens/admin/products/add_product_screen.dart',
        'lib/screens/admin/products/edit_product_screen.dart',
        'lib/screens/admin/users/widgets/user_stats_card.dart',
        'lib/screens/admin/users/widgets/user_filter_chip.dart',
        'lib/screens/admin/orders/widgets/order_stats.dart',
        'lib/screens/admin/orders/widgets/order_filter.dart',
      ];
      for (final path in deadPaths) {
        final file = File('${Directory.current.path}/$path');
        expect(
          file.existsSync(),
          isFalse,
          reason:
              '$path is back — this was confirmed-dead code (zero '
              'importers, zero navigation entry points anywhere in the '
              'app, confirmed by three independent grep methods). If a '
              'real feature is being added under this same path, this '
              'guard should be removed deliberately, not silently '
              'defeated by re-creating a same-named file.',
        );
      }
    });

    test('the real replacements these dead files were superseded by are untouched', () {
      final liveReplacements = [
        'lib/screens/admin/admin_shell.dart',
        'lib/screens/admin/products/product_form_screen.dart',
        'lib/app/app_router.dart',
      ];
      for (final path in liveReplacements) {
        final file = File('${Directory.current.path}/$path');
        expect(file.existsSync(), isTrue,
            reason: '$path is missing — this phase must not have removed '
                'the wrong file.');
      }
    });
  });
}

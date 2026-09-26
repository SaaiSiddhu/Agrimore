// ADMR-16 — dead, empty (0-byte) scaffold files removed.
//
// A repo-wide `find ... -size 0` swept every .dart/.ts file across every app
// and package and turned up 28 confirmed-empty source files with zero
// references anywhere, checked individually by grep in each case:
//
// - 10 in packages/agrimore_ui/lib/widgets/common/, still `export`ed from
//   the package's own barrel file (agrimore_ui.dart) -- the shared
//   package's public API advertised ten widgets that exported nothing.
//   Each has a differently-named, non-empty, genuinely-used sibling still
//   in the same barrel (error_view.dart, loading_overlay.dart, etc.).
// - 17 in apps/admin/lib/ (widgets/admin/, screens/auth/widgets/,
//   screens/admin/analytics/widgets/, screens/admin/settings/ and its
//   widgets/ subfolder).
// - 1 in apps/marketplace/lib/screens/user/shop/search_screen.dart -- a
//   third, distinct search_screen.dart path; the two REAL ones
//   (screens/user/home/search/ and screens/user/search/) are untouched.
//
// This guard checks the admin-side deletions and the barrel file directly
// (the ones this test file can reach); the marketplace and package
// deletions are proven by this phase's own five-app `flutter analyze`
// (0 errors everywhere) and full test-suite run recorded in the ledger,
// since a file-existence check from within apps/admin/test cannot reach
// another app's or package's directory tree.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ADMR-16 dead empty scaffold files removed', () {
    test('none of the 17 confirmed-empty admin files exist any more', () {
      final removed = [
        'lib/widgets/admin/data_table_widget.dart',
        'lib/widgets/admin/admin_drawer.dart',
        'lib/widgets/admin/stat_card.dart',
        'lib/widgets/admin/admin_button.dart',
        'lib/widgets/admin/admin_app_bar.dart',
        'lib/screens/auth/widgets/auth_text_field.dart',
        'lib/screens/auth/widgets/auth_header.dart',
        'lib/screens/auth/widgets/social_login_button.dart',
        'lib/screens/admin/analytics/widgets/top_products_list.dart',
        'lib/screens/admin/analytics/widgets/analytics_card.dart',
        'lib/screens/admin/analytics/widgets/orders_chart.dart',
        'lib/screens/admin/analytics/widgets/revenue_chart.dart',
        'lib/screens/admin/settings/delivery_settings_screen.dart',
        'lib/screens/admin/settings/payment_settings_screen.dart',
        'lib/screens/admin/settings/widgets/settings_section.dart',
        'lib/screens/admin/settings/widgets/settings_toggle.dart',
        'lib/screens/admin/settings/widgets/settings_form_field.dart',
      ];
      for (final relPath in removed) {
        final file = File('${Directory.current.path}/$relPath');
        expect(
          file.existsSync(),
          isFalse,
          reason:
              '$relPath is back — this was a confirmed-empty (0-byte), '
              'zero-reference file. If real content is being added under '
              'this same path, this guard should be removed deliberately, '
              'not silently defeated by re-creating an empty placeholder.',
        );
      }
    });

    test('the real, non-empty settings screens the empty ones lived '
        'alongside are untouched', () {
      for (final relPath in [
        'lib/screens/admin/settings/location_settings_screen.dart',
        'lib/screens/admin/settings/wallet_config_screen.dart',
        'lib/screens/admin/settings/admin_settings_screen.dart',
      ]) {
        final file = File('${Directory.current.path}/$relPath');
        expect(file.existsSync(), isTrue,
            reason: '$relPath is missing — this phase must not have '
                'deleted a real, non-empty settings screen.');
      }
    });
  });

  group('ADMR-16 agrimore_ui barrel file no longer exports deleted files',
      () {
    late String barrel;

    setUpAll(() async {
      barrel = await File(
        '${Directory.current.path}/../../packages/agrimore_ui/lib/agrimore_ui.dart',
      ).readAsString();
    });

    test('no export line references any of the 10 deleted common widgets',
        () {
      for (final needle in [
        "'widgets/common/custom_app_bar.dart'",
        "'widgets/common/custom_drawer.dart'",
        "'widgets/common/loading_indicator.dart'",
        "'widgets/common/shimmer_loading.dart'",
        "'widgets/common/error_widget.dart'",
        "'widgets/common/rating_widget.dart'",
        "'widgets/common/badge_widget.dart'",
        "'widgets/common/search_bar_widget.dart'",
        "'widgets/common/network_image_widget.dart'",
        "'widgets/common/confirmation_dialog.dart'",
      ]) {
        expect(
          barrel.contains(needle),
          isFalse,
          reason: '$needle is still exported from agrimore_ui.dart but the '
              'file it points to was deleted as confirmed-empty and '
              'zero-reference — this export would break the package\'s own '
              'compile the moment anyone re-adds real content elsewhere '
              'and forgets this line, or is simply dangling now.',
        );
      }
    });

    test('the real, non-empty sibling exports in the same block are '
        'untouched', () {
      for (final needle in [
        "'widgets/common/custom_button.dart'",
        "'widgets/common/custom_text_field.dart'",
        "'widgets/common/custom_bottom_nav.dart'",
        "'widgets/common/loading_overlay.dart'",
        "'widgets/common/empty_state_widget.dart'",
        "'widgets/common/error_view.dart'",
        "'widgets/common/sticky_photo_header.dart'",
      ]) {
        expect(barrel.contains(needle), isTrue,
            reason: '$needle is missing from agrimore_ui.dart — this phase '
                'must only remove the 10 confirmed-dead export lines, not '
                'any of the real, working ones in the same block.');
      }
    });
  });
}

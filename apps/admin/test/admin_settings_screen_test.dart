// ADMR-46 — admin settings screen honesty.
//
// PROBLEM: admin_settings_screen.dart had six controls that either claimed
// an effect nothing in the system actually produces (an enforced maintenance
// mode, a saved payment/shipping config, a triggered backup export, enrolled
// 2FA) or silently no-op'd while claiming success (Change Password never
// called Firebase Auth at all, despite AuthProvider.changePassword already
// existing and already working for the marketplace app's own screen).
//
// FIX: Change Password now calls the existing AuthProvider.changePassword.
// Maintenance Mode persists to settings/platform_status for real. The other
// four dialogs' copy was rewritten to disclose the true (unimplemented)
// state instead of claiming one that isn't real. changePasswordFormError
// and maintenanceModeConfirmationMessage are plain, Firebase-free functions
// pulled out of the State class (which cannot be constructed outside a real
// Firebase app, matching this project's other Firebase-free guard tests);
// the four disclosure strings are asserted directly so a future edit can't
// silently reintroduce one of the old false claims.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/settings/admin_settings_screen.dart';

void main() {
  group('changePasswordFormError', () {
    test('requires the current password', () {
      expect(
        changePasswordFormError(
          currentPassword: '',
          newPassword: 'newpass123',
          confirmPassword: 'newpass123',
        ),
        'Enter your current password',
      );
    });

    test('requires a new password', () {
      expect(
        changePasswordFormError(
          currentPassword: 'oldpass123',
          newPassword: '',
          confirmPassword: '',
        ),
        'Enter a new password',
      );
    });

    test('rejects a new password shorter than 6 characters', () {
      expect(
        changePasswordFormError(
          currentPassword: 'oldpass123',
          newPassword: 'ab1',
          confirmPassword: 'ab1',
        ),
        'New password must be at least 6 characters',
      );
    });

    test('rejects a new password identical to the current one', () {
      expect(
        changePasswordFormError(
          currentPassword: 'samepass123',
          newPassword: 'samepass123',
          confirmPassword: 'samepass123',
        ),
        'New password must be different from the current password',
      );
    });

    test('rejects a confirmation that does not match', () {
      expect(
        changePasswordFormError(
          currentPassword: 'oldpass123',
          newPassword: 'newpass123',
          confirmPassword: 'newpass124',
        ),
        'Passwords do not match',
      );
    });

    test('accepts a genuinely valid change', () {
      expect(
        changePasswordFormError(
          currentPassword: 'oldpass123',
          newPassword: 'newpass456',
          confirmPassword: 'newpass456',
        ),
        isNull,
      );
    });
  });

  group('maintenanceModeConfirmationMessage', () {
    test('enabling discloses that no app enforces the flag yet', () {
      final message = maintenanceModeConfirmationMessage(true);
      expect(message, isNot(contains('Only admins will be able to access')));
      expect(message, contains('No app currently reads this flag'));
      expect(message, contains('will not actually'));
    });

    test('disabling is a plain, low-stakes statement', () {
      final message = maintenanceModeConfirmationMessage(false);
      expect(message, contains('no longer under maintenance'));
      expect(message, isNot(contains('Only admins will be able to access')));
    });
  });

  group('settings disclosure copy — regression guards against old false claims', () {
    test('shipping settings disclosure admits it is not yet editable here', () {
      expect(shippingSettingsDisclosure, contains('not yet'));
      expect(shippingSettingsDisclosure, isNot(contains('saved')));
    });

    test('payment settings disclosure admits it is not yet editable here', () {
      expect(paymentSettingsDisclosure, contains('not yet'));
      expect(paymentSettingsDisclosure, isNot(contains('saved')));
    });

    test('two-factor disclosure no longer claims 2FA is active', () {
      expect(twoFactorDisclosure, isNot(contains('is active')));
      expect(twoFactorDisclosure, contains('no'));
      expect(twoFactorDisclosure, contains('enrolled'));
    });

    test('backup export disclosure no longer claims an export was initiated', () {
      expect(backupExportDisclosure, isNot(contains('initiated')));
      expect(backupExportDisclosure, contains('cannot trigger'));
    });
  });
}

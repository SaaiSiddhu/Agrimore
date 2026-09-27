// ADMR-12 — user role escalation confirmation guard.
//
// PROBLEM: edit_user_screen.dart offers exactly two roles, 'user' and
// 'admin' — so any role change here is always a grant or revocation of
// full platform access (per every isAdmin() check in firestore.rules).
// updateUserRole (AdminService, packages/agrimore_services) was a bare
// client Firestore write with no server-side validation and no audit
// trail; firestore.rules correctly requires the caller to already be an
// admin (no privilege-escalation vulnerability for an outside attacker),
// but granted that admin unrestricted access to any user's role field. The
// screen's own "Update" button used to call updateUserRole unconditionally
// on every save, with zero confirmation — a single mis-tap could grant (or
// revoke) full admin access to an arbitrary account.
//
// FIX: isRoleChanging (edit_user_screen.dart) flags exactly the case that
// matters — the selected role actually differing from the user's current
// one — and a confirmation dialog naming the concrete consequence is shown
// before _handleUpdate proceeds. Routine edits (name/phone/active-status
// with the role left alone) are unaffected.
//
// isRoleChanging is plain Dart with no Firebase dependency, so it gets a
// real, direct unit test — unlike AdminProvider/AdminService, whose
// FirebaseFirestore.instance field initializers mean even constructing
// them crashes outside a real Firebase app (matching this project's other
// established Firebase-free guard tests).
//
// ADMR-44 additions below: the deeper gap this header used to describe as
// still-open — updateUserRole being a bare, unaudited client write — is
// now closed. It routes through the already-existing, already-deployed
// setUserRole.ts callable (self-demotion refusal, last-admin protection,
// audit-bearing transaction) instead of writing users/{uid}.role
// directly. apiRoleForStoredRole is the one piece of that wiring pure
// enough to unit-test directly: the callable's own API vocabulary uses
// 'customer' where the rest of this app persists/reads 'user'.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/users/edit_user_screen.dart';
import 'package:agrimore_services/agrimore_services.dart';

void main() {
  group('isRoleChanging', () {
    test('flags user -> admin — a grant of full platform access', () {
      expect(isRoleChanging('user', 'admin'), isTrue);
    });

    test('flags admin -> user — a revocation of admin access', () {
      expect(isRoleChanging('admin', 'user'), isTrue);
    });

    test('does not flag re-selecting the same role — not an actual change', () {
      expect(isRoleChanging('user', 'user'), isFalse);
      expect(isRoleChanging('admin', 'admin'), isFalse);
    });
  });

  group('apiRoleForStoredRole', () {
    test('maps the stored "user" to setUserRole.ts\'s own "customer" API value', () {
      expect(apiRoleForStoredRole('user'), 'customer');
    });

    test('passes every other stored role through unchanged', () {
      expect(apiRoleForStoredRole('admin'), 'admin');
      expect(apiRoleForStoredRole('seller'), 'seller');
      expect(apiRoleForStoredRole('delivery_partner'), 'delivery_partner');
      expect(apiRoleForStoredRole('employee'), 'employee');
    });
  });
}

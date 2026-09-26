// ADMR-12 — user role escalation confirmation guard.
//
// PROBLEM: edit_user_screen.dart offers exactly two roles, 'user' and
// 'admin' — so any role change here is always a grant or revocation of
// full platform access (per every isAdmin() check in firestore.rules).
// updateUserRole (AdminService, packages/agrimore_services) is a bare
// client Firestore write with no server-side validation and no audit
// trail; firestore.rules correctly requires the caller to already be an
// admin (no privilege-escalation vulnerability for an outside attacker),
// but grants that admin unrestricted access to any user's role field. The
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
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/users/edit_user_screen.dart';

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
}

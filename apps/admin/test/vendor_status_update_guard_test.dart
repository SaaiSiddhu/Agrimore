// ADMR-13 — vendor status update dialog.
//
// PROBLEM: vendors_list_screen.dart's vendor ListTile had onTap: () {
// // Update Status Dialog } -- an empty comment placeholder. Tapping a
// vendor did structurally nothing: no dialog, no navigation, no feedback.
// VendorProvider.updateVendor()/VendorService.updateVendor() were already
// fully implemented and correctly wired to Firestore, with zero callers
// anywhere in the app -- the write path was built and never connected to
// any UI.
//
// FIX: a real "Update Status" dialog offering the three existing
// VendorStatus values (active/inactive/blocked), gated by
// isVendorStatusChanging so re-selecting the current status does not fire
// a write, calling the already-existing, already-correct
// VendorProvider.updateVendor.
//
// isVendorStatusChanging is plain Dart with no Firebase dependency, so it
// gets a real, direct unit test -- unlike VendorProvider/VendorService,
// whose FirebaseFirestore.instance field initializer means even
// constructing them crashes outside a real Firebase app (matching this
// project's other established Firebase-free guard tests).
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_core/agrimore_core.dart';

import 'package:agrimore_admin/screens/admin/vendors/vendors_list_screen.dart';

void main() {
  group('isVendorStatusChanging', () {
    test('flags active -> inactive', () {
      expect(isVendorStatusChanging(VendorStatus.active, VendorStatus.inactive), isTrue);
    });

    test('flags active -> blocked', () {
      expect(isVendorStatusChanging(VendorStatus.active, VendorStatus.blocked), isTrue);
    });

    test('flags inactive -> blocked', () {
      expect(isVendorStatusChanging(VendorStatus.inactive, VendorStatus.blocked), isTrue);
    });

    test('does not flag re-selecting the current status — not an actual '
        'change, must not fire a write', () {
      for (final status in VendorStatus.values) {
        expect(isVendorStatusChanging(status, status), isFalse,
            reason: '$status -> $status should not be flagged');
      }
    });
  });
}

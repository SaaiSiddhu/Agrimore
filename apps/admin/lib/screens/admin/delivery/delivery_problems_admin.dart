// lib/screens/admin/delivery/delivery_problems_admin.dart
//
// Phase DLV-E1 — pure helpers for the admin Delivery Problems queue over
// delivery_exceptions (functions/src/delivery/riderExceptions.ts). Covered by
// test/delivery_problems_admin_test.dart.

const openProblemStatuses = ['reported', 'acknowledged'];

/// Rider-reported reasons, as admins read them.
String problemReasonLabel(String? reason) => switch (reason) {
      'customer_unreachable' => 'Customer not reachable',
      'customer_refused' => 'Customer refused the order',
      'wrong_address' => 'Wrong address',
      'address_not_found' => "Rider can't find the address",
      'payment_issue' => 'Cash payment problem',
      'damaged_goods' => 'Goods damaged or missing',
      'vehicle_issue' => 'Rider vehicle problem',
      'safety' => 'Safety concern',
      _ => 'Other',
    };

String problemStatusLabel(String? status) => switch (status) {
      'reported' => 'New — not acknowledged',
      'acknowledged' => 'Acknowledged',
      'resolved' => 'Resolved',
      _ => 'Unknown',
    };

/// Who holds the goods now.
String custodyLabel(String? custody) => switch (custody) {
      'seller' => 'Goods with the seller',
      'rider' => 'Goods with the rider',
      _ => 'Custody unknown',
    };

/// Resolutions an admin can record. Neither changes the order's money: a
/// refund, a cancelled order or rider pay for the attempt is decided and
/// done in the order tools (open owner policy decision).
const problemDispositions = <(String, String)>[
  ('reattempt', 'Rider will try the delivery again'),
  ('returned_to_seller', 'Goods returned to the seller'),
];

String? problemResolutionError(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Write what was decided (at least 3 characters)';
  if (t.length > 500) return 'Keep it under 500 characters';
  return null;
}

String problemRefusal(String code, String? reason) => switch (reason) {
      'already_resolved' => 'Someone already resolved this problem.',
      'resolution_required' => 'Write what was decided (3–500 characters).',
      'not_found' => 'This problem no longer exists.',
      'bad_request' => 'Choose what happened to the goods.',
      _ => code == 'permission-denied' ? 'Only admins can update problems.' : 'Could not update the problem. Try again.',
    };

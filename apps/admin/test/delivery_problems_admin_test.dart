// DLV-E1 — admin Delivery Problems helpers.
import 'package:agrimore_admin/screens/admin/delivery/delivery_problems_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reasons, statuses and custody read plainly', () {
    expect(problemReasonLabel('damaged_goods'), 'Goods damaged or missing');
    expect(problemReasonLabel('zzz'), 'Other');
    expect(problemStatusLabel('reported'), 'New — not acknowledged');
    expect(custodyLabel('seller'), 'Goods with the seller');
    expect(custodyLabel(null), 'Custody unknown');
  });

  test('only the two policy-free dispositions exist (no refund or pay action)', () {
    expect(problemDispositions.map((d) => d.$1), ['reattempt', 'returned_to_seller']);
  });

  test('resolution bounds match the server', () {
    expect(problemResolutionError('ok'), isNotNull);
    expect(problemResolutionError('Customer home now'), isNull);
    expect(problemResolutionError('x' * 501), isNotNull);
    expect(problemRefusal('failed-precondition', 'already_resolved'), contains('already resolved'));
  });
}

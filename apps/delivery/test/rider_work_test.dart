// Phase DLV-C1 — active work is read the way the server reads it: only this
// rider's open legs, both status fields weighed, several reported as several.
import 'package:delivery/data/rider_work.dart';
import 'package:flutter_test/flutter_test.dart';

OrderDoc doc(String id, {String rider = 'r1', String? orderStatus, String? status, DateTime? acceptedAt}) => (
      id: id,
      data: {
        'deliveryPartnerId': rider,
        if (orderStatus != null) 'orderStatus': orderStatus,
        if (status != null) 'status': status,
        if (acceptedAt != null) 'deliveryAcceptedAt': acceptedAt,
      },
    );

void main() {
  test('only this rider\'s open legs count', () {
    expect(openLegOf(doc('a', orderStatus: 'picked_up'), 'r1'), isNotNull);
    expect(openLegOf(doc('b', rider: 'r2', orderStatus: 'picked_up'), 'r1'), isNull, reason: 'reassigned');
    expect(openLegOf(doc('c', orderStatus: 'out_for_delivery', status: 'delivered'), 'r1'), isNull,
        reason: 'an admin delivered it in `status`');
    expect(openLegOf(doc('d', orderStatus: 'delivery_accepted', status: 'cancelled'), 'r1'), isNull);
    expect(openLegOf(doc('e', orderStatus: 'outForDelivery'), 'r1'), isNotNull, reason: 'legacy spelling');
    expect(openLegOf(doc('f', orderStatus: 'something_new'), 'r1'), isNull, reason: 'unknown is not active');
  });

  test('several active orders stay several, oldest assignment first', () {
    final t0 = DateTime(2026, 9, 24, 10);
    final docs = activeDocsFor([
      doc('late', orderStatus: 'delivery_accepted', acceptedAt: t0.add(const Duration(minutes: 5))),
      doc('gone', orderStatus: 'picked_up', status: 'delivered'),
      doc('early', orderStatus: 'picked_up', acceptedAt: t0),
    ], 'r1');
    expect(docs.map((d) => d.id), ['early', 'late']);
  });

  test('ActiveWork never picks one of several', () {
    expect(const ActiveWork.ready([]).isEmpty, isTrue);
    expect(const ActiveWork.loading().loaded, isFalse);
  });

  test('error codes', () {
    expect(riderDataErrorOf('permission-denied'), RiderDataError.permission);
    expect(riderDataErrorOf('unavailable'), RiderDataError.offline);
    expect(riderDataErrorOf('internal'), RiderDataError.unknown);
    expect(riderDataErrorOf(null), RiderDataError.unknown);
  });

  test('today starts at local midnight', () {
    expect(startOfLocalDay(DateTime(2026, 9, 24, 23, 59)), DateTime(2026, 9, 24));
    expect(startOfLocalDay(DateTime(2026, 9, 25, 0, 0, 1)), DateTime(2026, 9, 25));
  });

  test('DLVDASH2: this week starts at the Monday on or before now, never a Sunday-start week', () {
    // Sep 24 2026 is a Thursday; Sep 21 2026 is the Monday of that same week.
    expect(startOfLocalWeek(DateTime(2026, 9, 24, 15, 30)), DateTime(2026, 9, 21));
    // Monday itself: the week already started today.
    expect(startOfLocalWeek(DateTime(2026, 9, 21, 0, 0, 1)), DateTime(2026, 9, 21));
    // Sunday: the LAST day of the week that started the PRECEDING Monday,
    // not the first day of a new one -- a naive Sunday-start week would
    // wrongly return Sep 27 here instead of Sep 21.
    expect(startOfLocalWeek(DateTime(2026, 9, 27, 23, 59)), DateTime(2026, 9, 21));
  });
}

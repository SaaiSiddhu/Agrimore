// Phase DLV-3C — admin reading of the server's rider location record
// (lib/screens/admin/delivery/delivery_flags.dart).
import 'package:agrimore_admin/screens/admin/delivery/delivery_flags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DateTime.utc(2026, 9, 23, 12);

  test('reads each step in delivery order, flags and all', () {
    final checks = StepCheck.fromOrder({
      'deliveryStepChecks': {
        'delivered': {'at': Timestamp.fromDate(t), 'distanceMeters': 40, 'isMocked': false, 'flags': <String>[]},
        'picked_up': {'at': Timestamp.fromDate(t), 'distanceMeters': 1500.4, 'isMocked': false, 'flags': ['far_from_store']},
        'arrived_at_store': {'at': Timestamp.fromDate(t), 'distanceMeters': 35, 'flags': <String>[]},
        'junk': 'not a map',
      },
    });
    expect(checks.map((c) => c.step), ['arrived_at_store', 'picked_up', 'delivered']);
    expect(checks[1].flagged, isTrue);
    expect(checks[1].distanceMeters, 1500);
    expect(checks[0].flagged, isFalse);
    expect(checks[0].at!.isAtSameMomentAs(t), isTrue);
  });

  test('an order the new rider app never touched shows nothing', () {
    expect(StepCheck.fromOrder(null), isEmpty);
    expect(StepCheck.fromOrder({'orderStatus': 'delivered'}), isEmpty);
    expect(orderHasDeliveryFlags({'orderStatus': 'delivered'}), isFalse);
  });

  test('flagged when the server said so', () {
    expect(orderHasDeliveryFlags({'deliveryFlagged': true}), isTrue);
    expect(orderHasDeliveryFlags({'deliveryFlags': [{'step': 'picked_up'}]}), isTrue);
    expect(orderHasDeliveryFlags({'deliveryFlags': []}), isFalse);
  });

  test('wording', () {
    expect(flagLabel('far_from_store'), 'far from the store');
    expect(flagLabel('mocked_location'), contains('fake-GPS'));
    expect(flagLabel('no_location'), 'no location sent');
    expect(stepLabel('delivered'), 'Delivered (code entered)');
    expect(distanceText(1500), '1.5 km away');
    expect(distanceText(84), '80 m away');
    expect(distanceText(null), 'distance unknown');
  });
}

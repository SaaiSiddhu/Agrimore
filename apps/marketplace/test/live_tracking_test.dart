// Phase DLV-3B — what the customer is told while an order is on its way.
import 'package:agrimore_marketplace/services/delivery_tracking_service.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trackable orders', () {
    test('the rider-leg statuses keep the banner and Track Live', () {
      for (final s in [
        'confirmed', 'processing', 'ready_for_pickup', 'delivery_accepted',
        'arrived_at_store', 'picked_up', 'out_for_delivery', 'Out_For_Delivery',
      ]) {
        expect(DeliveryTrackingService.isTrackable(s), isTrue, reason: s);
      }
    });

    test('nothing to track before confirmation or after the end', () {
      for (final s in ['pending', 'delivered', 'cancelled', 'returned', 'refunded', '']) {
        expect(DeliveryTrackingService.isTrackable(s), isFalse, reason: s);
      }
    });
  });

  group('stage message', () {
    test('the rider leg wins over the order status', () {
      expect(DeliveryTrackingService.stageMessage(DeliveryTaskStatus.atPickup, 'delivery_accepted'),
          contains('at the store'));
      expect(DeliveryTrackingService.stageMessage(DeliveryTaskStatus.enRoute, 'picked_up'),
          'On the way to you');
    });

    test('every rider-leg state has its own sentence', () {
      final seen = <String>{};
      for (final s in DeliveryTaskStatus.values) {
        final m = DeliveryTrackingService.stageMessage(s, 'processing');
        expect(m, isNot(startsWith('Order status:')), reason: s.name);
        seen.add(m);
      }
      expect(seen.length, greaterThanOrEqualTo(8));
    });

    test('order statuses read as sentences, including the rider-leg ones', () {
      // Before DLV-3B 'pending' said 'Looking for a delivery partner…' and
      // delivery_accepted fell through to 'Order status: delivery_accepted'.
      expect(DeliveryTrackingService.stageMessage(null, 'pending'), contains('waiting for the store'));
      expect(DeliveryTrackingService.stageMessage(null, 'delivery_accepted'), contains('on the way to the store'));
      for (final s in ['ready_for_pickup', 'arrived_at_store', 'picked_up', 'something_new']) {
        expect(DeliveryTrackingService.stageMessage(null, s), isNot(contains(s)), reason: s);
      }
    });
  });

  test('location age note', () {
    expect(locationAgeMessage(null), contains('Waiting'));
    expect(locationAgeMessage(const Duration(seconds: 30)), 'Location updated just now');
    expect(locationAgeMessage(const Duration(minutes: 4)), 'Location updated 4 min ago');
    expect(locationAgeMessage(const Duration(hours: 2)), 'Location updated over an hour ago');
  });
}

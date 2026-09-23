// Phase DLV-3B — what the customer is told while an order is on its way.
import 'package:agrimore_marketplace/services/delivery_tracking_service.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/screens/user/orders/live_tracking_screen.dart' show fitZoom;
import 'package:agrimore_marketplace/screens/user/orders/widgets/tracking_sections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  group('camera fit (web left it at a broken zoom before)', () {
    LatLngBounds b(double s, double w, double n, double e) =>
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));

    test('a 2-3 km city trip fits at street level', () {
      final z = fitZoom(b(9.898, 78.115, 9.943, 78.124), widthPx: 279, heightPx: 175);
      expect(z, inInclusiveRange(12.0, 14.0));
    });

    test('a smaller band or a longer trip zooms out', () {
      final big = fitZoom(b(9.90, 78.11, 9.92, 78.13), widthPx: 300, heightPx: 400);
      final small = fitZoom(b(9.90, 78.11, 9.92, 78.13), widthPx: 300, heightPx: 150);
      final longer = fitZoom(b(9.80, 78.11, 9.92, 78.13), widthPx: 300, heightPx: 400);
      expect(small, lessThan(big));
      expect(longer, lessThan(big));
    });

    test('degenerate or silly input stays in 3-17', () {
      expect(fitZoom(b(9.9, 78.1, 9.9, 78.1), widthPx: 300, heightPx: 300), 17);
      expect(fitZoom(b(-80, -170, 80, 170), widthPx: 300, heightPx: 300), 3);
      expect(fitZoom(b(9.9, 78.1, 9.95, 78.2), widthPx: -5, heightPx: 0), inInclusiveRange(3.0, 17.0));
    });
  });

  test('stepper stage from the rider leg, else the order status', () {
    expect(TrackingStepper.currentStep(null, 'pending'), 0);
    expect(TrackingStepper.currentStep(DeliveryTaskStatus.searching, 'ready_for_pickup'), 1);
    expect(TrackingStepper.currentStep(DeliveryTaskStatus.atPickup, 'arrived_at_store'), 1);
    expect(TrackingStepper.currentStep(DeliveryTaskStatus.enRoute, 'picked_up'), 2);
    expect(TrackingStepper.currentStep(DeliveryTaskStatus.delivered, 'delivered'), 3);
    expect(TrackingStepper.currentStep(null, 'out_for_delivery'), 2);
  });

  test('cash on delivery and money labels', () {
    expect(isCashOnDelivery('COD'), isTrue);
    expect(isCashOnDelivery('razorpay'), isFalse);
    expect(rupees(480), '₹480');
    expect(rupees(99.5), '₹99.50');
  });
}

// Phase DLV-3C — the rider app's side of the server-checked steps
// (lib/delivery/rider_steps.dart): what is sent, when a far tap is asked
// about, and what a refusal says.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/delivery/rider_steps.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const store = DeliveryPoint(lat: 9.9252, lng: 78.1198);
  const m = 1 / 111320;

  test('payload: a position, or an explicit "unavailable" the server flags', () {
    expect(fixPayload(lat: 9.9, lng: 78.1, accuracy: 7.5, isMocked: true),
        {'lat': 9.9, 'lng': 78.1, 'accuracy': 7.5, 'isMocked': true, 'locationStatus': 'ok'});
    expect(fixPayload(), {'locationStatus': 'unavailable'});
    expect(fixPayload(lat: 9.9), {'locationStatus': 'unavailable'});
    expect(fixPayload(lat: 9.9, lng: 78.1, accuracy: -1).containsKey('accuracy'), isFalse);
  });

  test('far tap: asked beyond 300 m, not within, not when unknown', () {
    final near = metersTo(store.lat + 250 * m, store.lng, store)!;
    expect(near, closeTo(250, 1));
    expect(farTapQuestion(l, near, atStore: true, action: FarTapAction.arrived), isNull);
    final far = metersTo(store.lat + 1200 * m, store.lng, store);
    expect(farTapQuestion(l, far, atStore: true, action: FarTapAction.arrived),
        "You're 1.2 km from the store. Mark arrived anyway? The delivery team will be told.");
    expect(farTapQuestion(l, 460, atStore: false, action: FarTapAction.complete),
        "You're 460 m from the customer's address. Complete the delivery anyway? The delivery team will be told.");
    expect(farTapQuestion(l, null, atStore: true, action: FarTapAction.pickedUp), isNull);
    expect(metersTo(null, 78.1, store), isNull);
    expect(metersTo(9.9, 78.1, null), isNull);
    expect(distanceLabel(l, 999.6), '1.0 km');
  });

  test('refusals read as something a rider can act on', () {
    expect(stepErrorMessage(l, 'failed-precondition', 'bad_transition'), contains('not possible right now'));
    expect(stepErrorMessage(l, 'permission-denied', 'not_assigned'), 'This order is no longer assigned to you.');
    expect(stepErrorMessage(l, 'failed-precondition', 'after_pickup'), contains('already picked up'));
    expect(stepErrorMessage(l, 'unavailable', null), contains('No internet'));
    expect(stepErrorMessage(l, 'deadline-exceeded', null), contains('No internet'));
    expect(stepErrorMessage(l, 'internal', null), 'Could not update the order. Please try again.');
    // Never the raw provider text.
    expect(stepErrorMessage(l, 'internal', 'something_new'), isNot(contains('something_new')));
  });

  // DLV-P1: moved out of active_order_screen.dart, same wording as before.
  test('confirmDelivery refusals', () {
    expect(deliveryConfirmError(l, 'permission-denied'), 'Incorrect code. Please try again.');
    expect(deliveryConfirmError(l, 'not-found'), 'This order could not be found.');
    expect(deliveryConfirmError(l, 'failed-precondition', reason: 'not_deliverable'), contains('no longer active'));
    expect(deliveryConfirmError(l, 'failed-precondition'), contains('contact support'));
    expect(deliveryConfirmError(l, 'resource-exhausted', retryAfterSec: 61), endsWith('in 2 min.'));
    expect(deliveryConfirmError(l, 'resource-exhausted'), endsWith('in 15 min.'));
    expect(deliveryConfirmError(l, 'resource-exhausted', retryAfterSec: 30), endsWith('in 1 min.'));
    expect(deliveryConfirmError(l, 'internal'), 'Could not confirm delivery. Please try again.');
  });

  test('order status to screen step, and the server COD rule', () {
    expect(deliveryStepOf('outForDelivery'), DeliveryStep.outForDelivery);
    expect(deliveryStepOf('arrived_at_store'), DeliveryStep.arrivedAtStore);
    expect(deliveryStepOf('delivered'), DeliveryStep.delivered);
    expect(deliveryStepOf('ready_for_pickup'), DeliveryStep.accepted);
    for (final m in ['cod', 'COD', 'cash_on_delivery', 'Cash']) {
      expect(isCashOnDeliveryMethod(m), isTrue, reason: m);
    }
    expect(isCashOnDeliveryMethod('razorpay'), isFalse);
    expect(deliveryStepAction(l, DeliveryStep.delivered), 'Complete delivery');
  });
}

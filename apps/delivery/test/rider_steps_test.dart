// Phase DLV-3C — the rider app's side of the server-checked steps
// (lib/delivery/rider_steps.dart): what is sent, when a far tap is asked
// about, and what a refusal says.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:delivery/delivery/rider_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(farTapQuestion(near, atStore: true, action: 'Mark arrived'), isNull);
    final far = metersTo(store.lat + 1200 * m, store.lng, store);
    expect(farTapQuestion(far, atStore: true, action: 'Mark arrived'),
        "You're 1.2 km from the store. Mark arrived anyway? The delivery team will be told.");
    expect(farTapQuestion(460, atStore: false, action: 'Complete the delivery'),
        "You're 460 m from the customer's address. Complete the delivery anyway? The delivery team will be told.");
    expect(farTapQuestion(null, atStore: true, action: 'x'), isNull);
    expect(metersTo(null, 78.1, store), isNull);
    expect(metersTo(9.9, 78.1, null), isNull);
    expect(distanceLabel(999.6), '1.0 km');
  });

  test('refusals read as something a rider can act on', () {
    expect(stepErrorMessage('failed-precondition', 'bad_transition'), contains('not possible right now'));
    expect(stepErrorMessage('permission-denied', 'not_assigned'), 'This order is no longer assigned to you.');
    expect(stepErrorMessage('failed-precondition', 'after_pickup'), contains('already picked up'));
    expect(stepErrorMessage('unavailable', null), contains('No internet'));
    expect(stepErrorMessage('deadline-exceeded', null), contains('No internet'));
    expect(stepErrorMessage('internal', null), 'Could not update the order. Please try again.');
    // Never the raw provider text.
    expect(stepErrorMessage('internal', 'something_new'), isNot(contains('something_new')));
  });
}

// lib/delivery/rider_steps.dart
//
// Phase DLV-3C — every rider step goes through the server
// (functions/src/delivery/riderSteps.ts): advanceDeliveryStep for arrived /
// picked up / out for delivery, releaseDeliveryOrder for "Seller not ready",
// and the rider's position rides along with confirmDelivery. The server checks
// the step against the delivery state table and records how far the rider
// was from the store or the customer — more than 300 m is flagged for admin,
// never refused (D-DLV-GEOFENCE). Before a far tap the app asks, the way
// Zomato/Swiggy riders are asked "You're not at the restaurant — continue?".
//
// The pure parts (payload, distance wording, error wording) are covered by
// test/rider_steps_test.dart.
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Same threshold as the server's GEOFENCE_METERS.
const double kGeofenceMeters = 300;

/// The position fields a step call carries. `locationStatus` tells the server
/// this app sends positions, so a missing one is a real "no location".
Map<String, dynamic> fixPayload({double? lat, double? lng, double? accuracy, bool isMocked = false}) {
  if (lat == null || lng == null) return {'locationStatus': 'unavailable'};
  return {
    'lat': lat,
    'lng': lng,
    if (accuracy != null && accuracy >= 0) 'accuracy': accuracy,
    'isMocked': isMocked,
    'locationStatus': 'ok',
  };
}

/// Straight-line metres between the rider and a place, or null if either is unknown.
double? metersTo(double? lat, double? lng, DeliveryPoint? place) {
  if (lat == null || lng == null || place == null) return null;
  return DeliveryEtaCalculator.straightLineKm(lat, lng, place.lat, place.lng) * 1000;
}

/// "350 m" / "1.2 km".
String distanceLabel(double meters) {
  final tens = (meters / 10).round() * 10;
  return tens < 1000 ? '$tens m' : '${(meters / 1000).toStringAsFixed(1)} km';
}

/// The question to ask before a far tap, or null when the rider is close
/// enough (or the distance is unknown — then the server simply records it).
String? farTapQuestion(double? meters, {required bool atStore, required String action}) {
  if (meters == null || meters <= kGeofenceMeters) return null;
  final place = atStore ? 'the store' : "the customer's address";
  return "You're ${distanceLabel(meters)} from $place. $action anyway? "
      'The delivery team will be told.';
}

/// A sentence a rider can act on, for a refusal from the step callables
/// (feedback.md: never the raw provider message).
String stepErrorMessage(String code, String? reason) {
  switch (reason) {
    case 'bad_transition':
      return 'This step is not possible right now — the order may have changed. Go back and open it again.';
    case 'not_assigned':
      return 'This order is no longer assigned to you.';
    case 'after_pickup':
      return 'The order is already picked up, so it can no longer be released. Contact support if there is a problem.';
    case 'not_found':
      return 'This order could not be found.';
  }
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
      return 'No internet connection. Check your network and try again.';
    case 'unauthenticated':
      return 'Your session has expired. Please sign in again.';
    case 'permission-denied':
      return 'This order is no longer assigned to you.';
    default:
      return 'Could not update the order. Please try again.';
  }
}

/// A refusal the screen shows as-is.
class RiderStepException implements Exception {
  final String message;
  const RiderStepException(this.message);
  @override
  String toString() => message;
}

/// The rider's position right now, or null (no permission, no signal).
/// Short timeout: the rider is standing at a door; a last-known fix younger
/// than two minutes is good enough.
Future<Position?> currentRiderFix() async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: DeliveryTiming.stepFixTimeout),
    );
  } catch (e) {
    debugPrint('Step fix failed: $e');
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 2)) return last;
    } catch (_) {}
    return null;
  }
}

Map<String, dynamic> positionPayload(Position? p) => fixPayload(
      lat: p?.latitude,
      lng: p?.longitude,
      accuracy: p?.accuracy,
      isMocked: p?.isMocked ?? false,
    );

/// The store and the customer for [orderId], from the server-written task
/// (the rider can read their own task), with the order's address as fallback.
Future<({DeliveryPoint? store, DeliveryPoint? customer})> stepPlaces(String orderId, OrderModel order) async {
  DeliveryTaskModel? task;
  try {
    final snap = await FirebaseFirestore.instance.collection('delivery_tasks').doc(orderId).get();
    if (snap.exists) task = DeliveryTaskModel.fromFirestore(snap);
  } catch (e) {
    debugPrint('Step places: $e');
  }
  final a = order.deliveryAddress;
  final fallback = a.latitude != null && a.longitude != null ? DeliveryPoint(lat: a.latitude!, lng: a.longitude!) : null;
  return (store: task?.pickup, customer: task?.drop ?? fallback);
}

Never _rethrow(FirebaseFunctionsException e) {
  final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
  debugPrint('Rider step refused: ${e.code} $reason ${e.message}');
  throw RiderStepException(stepErrorMessage(e.code, reason));
}

/// advanceDeliveryStep. [status]: arrived_at_store, picked_up or out_for_delivery.
Future<void> advanceDeliveryStep(String orderId, String status, Map<String, dynamic> fix) async {
  try {
    await FirebaseFunctions.instance
        .httpsCallable('advanceDeliveryStep')
        .call<Map<String, dynamic>>({'orderId': orderId, 'step': status, ...fix});
  } on FirebaseFunctionsException catch (e) {
    _rethrow(e);
  } catch (e) {
    debugPrint('advanceDeliveryStep error: $e');
    throw const RiderStepException('Could not update the order. Please try again.');
  }
}

/// releaseDeliveryOrder ("Seller not ready"), before pickup only.
Future<void> releaseDeliveryOrder(String orderId, {String reason = 'seller_not_ready'}) async {
  try {
    await FirebaseFunctions.instance
        .httpsCallable('releaseDeliveryOrder')
        .call<Map<String, dynamic>>({'orderId': orderId, 'reason': reason});
  } on FirebaseFunctionsException catch (e) {
    _rethrow(e);
  } catch (e) {
    debugPrint('releaseDeliveryOrder error: $e');
    throw const RiderStepException('Could not release the order. Please try again.');
  }
}

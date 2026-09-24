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
import '../l10n/app_localizations.dart';
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
String distanceLabel(AppLocalizations l, double meters) {
  final tens = (meters / 10).round() * 10;
  return tens < 1000 ? l.distanceMeters(tens) : l.distanceKm((meters / 1000).toStringAsFixed(1));
}

/// What the rider is about to do when asked about a far tap.
enum FarTapAction { arrived, pickedUp, complete }

/// The question to ask before a far tap, or null when the rider is close
/// enough (or the distance is unknown — then the server simply records it).
String? farTapQuestion(AppLocalizations l, double? meters, {required bool atStore, required FarTapAction action}) {
  if (meters == null || meters <= kGeofenceMeters) return null;
  final verb = switch (action) {
    FarTapAction.arrived => l.stepActionArrived,
    FarTapAction.pickedUp => l.stepActionPickedUp,
    FarTapAction.complete => l.stepActionComplete,
  };
  final distance = distanceLabel(l, meters);
  return atStore ? l.stepFarStore(distance, verb) : l.stepFarCustomer(distance, verb);
}

/// A sentence a rider can act on, for a refusal from the step callables
/// (feedback.md: never the raw provider message).
String stepErrorMessage(AppLocalizations l, String code, String? reason) {
  switch (reason) {
    case 'bad_transition':
      return l.stepErrBadTransition;
    case 'not_assigned':
      return l.stepErrNotAssigned;
    case 'after_pickup':
      return l.stepErrAfterPickup;
    case 'not_found':
      return l.stepErrNotFound;
  }
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
      return l.stepErrNetwork;
    case 'unauthenticated':
      return l.stepErrSession;
    case 'permission-denied':
      return l.stepErrNotAssigned;
    default:
      return l.stepErrUpdate;
  }
}

/// A sentence for a confirmDelivery refusal (feedback.md §2: never the raw
/// provider message). [retryAfterSec] is details.retryAfterSec on a lockout —
/// DLV-0: five wrong codes lock the order for 15 minutes on the server.
String deliveryConfirmError(AppLocalizations l, String code, {String? reason, Object? retryAfterSec}) {
  switch (code) {
    case 'permission-denied':
      return l.deliverWrongCode;
    case 'not-found':
      return l.stepErrNotFound;
    case 'failed-precondition':
      // Two situations, two things to do; the callable tags which.
      return reason == 'not_deliverable' ? l.deliverNotActive : l.deliverNoVerification;
    case 'resource-exhausted':
      final minutes = retryAfterSec is num ? (retryAfterSec / 60).ceil().clamp(1, 60) : 15;
      return l.deliverLocked(minutes);
    default:
      return l.deliverFailed;
  }
}

/// A refused step or release: the callable's code and details.reason
/// ('unknown' when the call itself failed), worded by [message].
class RiderStepException implements Exception {
  final String code;
  final String? reason;

  /// A release ("Seller not ready") rather than a step.
  final bool release;
  const RiderStepException(this.code, [this.reason, this.release = false]);

  String message(AppLocalizations l) =>
      release && code == 'unknown' ? l.stepErrRelease : stepErrorMessage(l, code, reason);

  @override
  String toString() => 'RiderStepException($code, $reason)';
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
  throw RiderStepException(e.code, reason);
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
    throw const RiderStepException('unknown');
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
    throw const RiderStepException('unknown', null, true);
  }
}

// lib/delivery/delivery_problems.dart
//
// Phase DLV-E1 — the rider side of delivery exceptions and proof of delivery
// (functions/src/delivery/riderExceptions.ts).
//
// Proof: the photo goes to ONE fixed object, delivery_proofs/{orderId}_proof,
// then attachDeliveryProof records it on the order. This runs only AFTER
// confirmDelivery succeeded, and it never throws: a photo that does not save
// is reported as exactly that — the delivery still counts.
//
// Exceptions: after pickup the rider reports what went wrong; the record's
// state (reported → seen → resolved with a disposition) is what the rider is
// shown, never a promise of what Agrimore will do.
// Covered by test/delivery_problems_test.dart.
import 'dart:math';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Reasons a rider may report after pickup (server EXCEPTION_REASONS).
const List<DeliveryFailureReason> afterPickupReasons = [
  DeliveryFailureReason.customerUnreachable,
  DeliveryFailureReason.customerRefused,
  DeliveryFailureReason.wrongAddress,
  DeliveryFailureReason.addressNotFound,
  DeliveryFailureReason.paymentIssue,
  DeliveryFailureReason.damagedGoods,
  DeliveryFailureReason.vehicleIssue,
  DeliveryFailureReason.safety,
  DeliveryFailureReason.other,
];

/// Whether the rider holds the goods (a problem can be reported).
bool isAfterPickup(String orderStatus) {
  final s = DeliveryTaskStatus.fromOrderStatus(orderStatus: orderStatus, status: null, hasPartner: true);
  return s == DeliveryTaskStatus.pickedUp || s == DeliveryTaskStatus.enRoute || s == DeliveryTaskStatus.atDrop;
}

/// The record's state as the rider sees it.
enum ProblemState { reported, seen, reattempt, returnedToSeller }

ProblemState problemStateOf(Map<String, dynamic>? d) {
  if (d?['status'] == 'resolved') {
    return d?['disposition'] == 'returned_to_seller' ? ProblemState.returnedToSeller : ProblemState.reattempt;
  }
  return d?['status'] == 'acknowledged' ? ProblemState.seen : ProblemState.reported;
}

/// Why a problem report or a proof did not go through.
enum ProblemFailure { notAfterPickup, alreadyOpen, network, unknown }

ProblemFailure problemFailureOf(String code, String? reason) => switch (reason) {
      'not_after_pickup' => ProblemFailure.notAfterPickup,
      'open_exception' => ProblemFailure.alreadyOpen,
      _ => code == 'unavailable' || code == 'deadline-exceeded' ? ProblemFailure.network : ProblemFailure.unknown,
    };

class ProblemException implements Exception {
  const ProblemException(this.failure);
  final ProblemFailure failure;
}

const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
String newProblemRequestId([Random? r]) {
  final rnd = r ?? Random.secure();
  return List.generate(20, (_) => _idChars[rnd.nextInt(_idChars.length)]).join();
}

/// The Firebase side (fakes in tests).
abstract class DeliveryProblemBackend {
  Future<String> report(Map<String, dynamic> payload);
  Future<void> uploadProof(String orderId, Uint8List bytes, String contentType);
  Future<void> attachProof(String orderId);
}

class FirebaseDeliveryProblemBackend implements DeliveryProblemBackend {
  @override
  Future<String> report(Map<String, dynamic> payload) async {
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable('reportDeliveryException')
          .call<Map<String, dynamic>>(payload);
      return r.data['exceptionId'] as String;
    } on FirebaseFunctionsException catch (e) {
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      debugPrint('reportDeliveryException refused: ${e.code} $reason');
      throw ProblemException(problemFailureOf(e.code, reason));
    }
  }

  @override
  Future<void> uploadProof(String orderId, Uint8List bytes, String contentType) =>
      FirebaseStorage.instance.ref('delivery_proofs/${orderId}_proof').putData(bytes, SettableMetadata(contentType: contentType));

  @override
  Future<void> attachProof(String orderId) =>
      FirebaseFunctions.instance.httpsCallable('attachDeliveryProof').call<Map<String, dynamic>>({'orderId': orderId});
}

/// Uploads and attaches the proof photo, retrying once. True when it is on
/// the order; false when it did not save — never throws (the delivery has
/// already been confirmed by then).
Future<bool> saveDeliveryProof(DeliveryProblemBackend backend, String orderId, Uint8List bytes, String contentType) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      await backend.uploadProof(orderId, bytes, contentType);
      await backend.attachProof(orderId);
      return true;
    } catch (e) {
      debugPrint('Proof not saved (attempt ${attempt + 1}): $e');
    }
  }
  return false;
}

/// The open exception id on an order, as the order document carries it.
String? openExceptionIdOf(Map<String, dynamic>? order) {
  final m = order?['openDeliveryException'];
  return m is Map && m['id'] is String ? m['id'] as String : null;
}

Stream<Map<String, dynamic>?> watchOrder(String orderId) => FirebaseFirestore.instance
    .collection('orders')
    .doc(orderId)
    .snapshots()
    .where((s) => s.exists || !s.metadata.isFromCache)
    .map((s) => s.data());

Stream<Map<String, dynamic>?> watchException(String id) => FirebaseFirestore.instance
    .collection('delivery_exceptions')
    .doc(id)
    .snapshots()
    .where((s) => s.exists || !s.metadata.isFromCache)
    .map((s) => s.data());

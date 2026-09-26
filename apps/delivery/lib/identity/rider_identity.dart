// lib/identity/rider_identity.dart
//
// Phase DLVID1 — a rider's own requests to change a locked identity field
// (name only; see functions/src/delivery/riderIdentity.ts for why "date of
// birth" is not offered). Mirrors rider_account.dart's own shape
// (backend interface + real callable-backed default) and rider_money.dart's
// BankChangeRequest (same pending/approved/rejected + rejectionReason shape,
// server-managed, firestore.rules lets only the owner or admin read it).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// The only change type this phase offers. `delivery_partners` has no
/// dateOfBirth field to change at all -- adding one is a product/schema
/// decision out of scope here, not a small gap.
const String kIdentityChangeTypeName = 'name';

enum IdentityChangeStatus { pending, approved, rejected }

class IdentityChangeRequest {
  const IdentityChangeRequest({
    required this.id,
    required this.changeType,
    required this.proposedValue,
    required this.reason,
    required this.status,
    this.currentValue,
    this.rejectionReason,
    this.createdAt,
  });
  final String id;
  final String changeType;
  final String? currentValue;
  final String proposedValue;
  final String reason;
  final IdentityChangeStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;

  factory IdentityChangeRequest.fromMap(String id, Map<String, dynamic> m) =>
      IdentityChangeRequest(
        id: id,
        changeType: (m['changeType'] as String?) ?? '',
        currentValue: m['currentValue'] as String?,
        proposedValue: (m['proposedValue'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? '',
        status: switch (m['status'] as String?) {
          'approved' => IdentityChangeStatus.approved,
          'rejected' => IdentityChangeStatus.rejected,
          _ => IdentityChangeStatus.pending,
        },
        rejectionReason: m['rejectionReason'] as String?,
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : null,
      );
}

/// Why a submission was refused. Worded by the screen.
enum IdentityRequestFailure { alreadyPending, invalid, network, unknown }

class IdentityRequestException implements Exception {
  const IdentityRequestException(this.failure, [this.field]);
  final IdentityRequestFailure failure;

  /// Which field was invalid ('proposedValue' or 'reason'), when
  /// [failure] is [IdentityRequestFailure.invalid] and the server named
  /// one -- lets the form show the error inline, matching
  /// ContactEditSheet's own established convention, rather than one
  /// generic toast for every kind of invalid input.
  final String? field;
}

IdentityRequestException identityRequestExceptionOf(String code, String? reason) {
  if (reason == 'already_pending') {
    return const IdentityRequestException(IdentityRequestFailure.alreadyPending);
  }
  if (reason != null && reason.startsWith('invalid_')) {
    return IdentityRequestException(IdentityRequestFailure.invalid, reason.substring(8));
  }
  return switch (code) {
    'invalid-argument' || 'failed-precondition' =>
      const IdentityRequestException(IdentityRequestFailure.invalid),
    'unavailable' || 'deadline-exceeded' =>
      const IdentityRequestException(IdentityRequestFailure.network),
    _ => const IdentityRequestException(IdentityRequestFailure.unknown),
  };
}

abstract class RiderIdentityBackend {
  /// Returns the new request's id.
  Future<String> requestChange({
    required String changeType,
    required String proposedValue,
    required String reason,
  });

  /// This rider's most recent request (of any status), or null if they have
  /// never made one.
  Stream<IdentityChangeRequest?> latestRequest(String riderId);
}

class CallableRiderIdentityBackend implements RiderIdentityBackend {
  CallableRiderIdentityBackend({FirebaseFirestore? db}) : _dbOverride = db;
  final FirebaseFirestore? _dbOverride;

  /// Deferred to first actual use (same reasoning as RiderMoneyService._db):
  /// bare construction must not touch FirebaseFirestore.instance.
  late final FirebaseFirestore _db = _dbOverride ?? FirebaseFirestore.instance;

  @override
  Future<String> requestChange({
    required String changeType,
    required String proposedValue,
    required String reason,
  }) async {
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable('requestRiderIdentityChange')
          .call<dynamic>({
        'changeType': changeType,
        'proposedValue': proposedValue,
        'reason': reason,
      });
      return (r.data as Map)['requestId'] as String;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      debugPrint('requestRiderIdentityChange refused: ${e.code} ${details['reason']}');
      throw identityRequestExceptionOf(e.code, details['reason'] as String?);
    }
  }

  @override
  Stream<IdentityChangeRequest?> latestRequest(String riderId) =>
      Stream.multi((controller) {
        try {
          controller.addStream(_db
              .collection('rider_identity_change_requests')
              .where('riderId', isEqualTo: riderId)
              .snapshots()
              .map((s) {
            final all = s.docs
                .map((d) => IdentityChangeRequest.fromMap(d.id, d.data()))
                .toList()
              ..sort((a, b) =>
                  (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
            return all.isEmpty ? null : all.first;
          }));
        } catch (e, st) {
          controller.addError(e, st);
          controller.close();
        }
      });
}

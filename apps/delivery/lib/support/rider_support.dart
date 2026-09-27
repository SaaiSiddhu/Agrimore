// lib/support/rider_support.dart
//
// Phase DLVSUP1 -- a rider's own support tickets (functions/src/delivery/
// riderSupport.ts). Modelled on delivery_problems.dart's own shape (a typed
// backend interface, client-generated request-id idempotency, a typed
// failure enum) rather than rider_identity.dart's: a ticket has no
// singleton pending gate -- several may be open on a rider at once.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

const String kSupportCategoryDeliveryIssue = 'delivery_issue';
const String kSupportCategoryEarningsPayouts = 'earnings_payouts';
const String kSupportCategoryAccountDocuments = 'account_documents';
const List<String> kSupportCategories = [
  kSupportCategoryDeliveryIssue,
  kSupportCategoryEarningsPayouts,
  kSupportCategoryAccountDocuments,
];

enum SupportTicketStatus { submitted, seen, closed }

/// A specific order or statement the ticket is about. Stored so a picker UI
/// can be added later without another reshape; no picker ships this phase.
class RelatedTo {
  const RelatedTo({required this.type, required this.id});
  final String type;
  final String id;

  factory RelatedTo.fromMap(Map<String, dynamic> m) => RelatedTo(
        type: (m['type'] as String?) ?? '',
        id: (m['id'] as String?) ?? '',
      );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.message,
    required this.status,
    this.relatedTo,
    this.attachmentPath,
    this.resolutionNote,
    this.createdAt,
    this.seenAt,
    this.closedAt,
  });
  final String id;
  final String category;
  final RelatedTo? relatedTo;
  final String message;
  final String? attachmentPath;
  final SupportTicketStatus status;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? seenAt;
  final DateTime? closedAt;

  factory SupportTicket.fromMap(String id, Map<String, dynamic> m) => SupportTicket(
        id: id,
        category: (m['category'] as String?) ?? '',
        relatedTo: m['relatedTo'] is Map
            ? RelatedTo.fromMap(Map<String, dynamic>.from(m['relatedTo'] as Map))
            : null,
        message: (m['message'] as String?) ?? '',
        attachmentPath: m['attachmentPath'] as String?,
        status: switch (m['status'] as String?) {
          'seen' => SupportTicketStatus.seen,
          'closed' => SupportTicketStatus.closed,
          _ => SupportTicketStatus.submitted,
        },
        resolutionNote: m['resolutionNote'] as String?,
        createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
        seenAt: m['seenAt'] is Timestamp ? (m['seenAt'] as Timestamp).toDate() : null,
        closedAt: m['closedAt'] is Timestamp ? (m['closedAt'] as Timestamp).toDate() : null,
      );
}

enum SupportRequestFailure { invalid, network, unknown }

class SupportRequestException implements Exception {
  const SupportRequestException(this.failure);
  final SupportRequestFailure failure;
}

SupportRequestException supportRequestExceptionOf(String code, String? reason) => switch (code) {
      'invalid-argument' || 'failed-precondition' => const SupportRequestException(SupportRequestFailure.invalid),
      'unavailable' || 'deadline-exceeded' => const SupportRequestException(SupportRequestFailure.network),
      _ => const SupportRequestException(SupportRequestFailure.unknown),
    };

const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Mirrors newProblemRequestId (delivery_problems.dart): a client-generated
/// idempotency key, so a retried submit after a lost response returns the
/// same ticket instead of filing a second one.
String newSupportRequestId([Random? r]) {
  final rnd = r ?? Random.secure();
  return List.generate(20, (_) => _idChars[rnd.nextInt(_idChars.length)]).join();
}

abstract class RiderSupportBackend {
  /// Null only when signed out (this screen is never reached then).
  String? get currentUid;

  /// Returns the ticket's id (== `${riderId}_$requestId` server-side).
  Future<String> submit({
    required String requestId,
    required String category,
    required String message,
    RelatedTo? relatedTo,
    String? attachmentPath,
  });

  /// One specific ticket's live status, or null if it does not exist.
  Stream<SupportTicket?> ticket(String ticketId);

  /// DLVSUP2: every ticket this rider has ever filed, newest first. An
  /// equality-only query (`riderId ==`); sorted client-side rather than via
  /// `orderBy` so no composite index (and no deploy) is needed.
  Stream<List<SupportTicket>> tickets(String riderId);

  /// Uploads to support_attachments/{uid}/{requestId}.jpg, returning that
  /// path for [submit]'s attachmentPath. Mirrors delivery_problems.dart's
  /// own uploadProof: one fixed object per request id, never a client-
  /// guessed filename.
  Future<String> uploadAttachment(String requestId, Uint8List bytes, String contentType);
}

class CallableRiderSupportBackend implements RiderSupportBackend {
  CallableRiderSupportBackend({FirebaseFirestore? db}) : _dbOverride = db;
  final FirebaseFirestore? _dbOverride;

  /// Deferred to first actual use (same reasoning as RiderMoneyService._db).
  late final FirebaseFirestore _db = _dbOverride ?? FirebaseFirestore.instance;

  @override
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<String> uploadAttachment(String requestId, Uint8List bytes, String contentType) async {
    final uid = currentUid;
    if (uid == null) throw StateError('uploadAttachment requires a signed-in rider');
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final path = 'support_attachments/$uid/$requestId.$ext';
    await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  @override
  Future<String> submit({
    required String requestId,
    required String category,
    required String message,
    RelatedTo? relatedTo,
    String? attachmentPath,
  }) async {
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('submitSupportRequest').call<dynamic>({
        'requestId': requestId,
        'category': category,
        'message': message,
        if (relatedTo != null) 'relatedTo': {'type': relatedTo.type, 'id': relatedTo.id},
        if (attachmentPath != null) 'attachmentPath': attachmentPath,
      });
      return (r.data as Map)['ticketId'] as String;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      debugPrint('submitSupportRequest refused: ${e.code} ${details['reason']}');
      throw supportRequestExceptionOf(e.code, details['reason'] as String?);
    }
  }

  @override
  Stream<SupportTicket?> ticket(String ticketId) => Stream.multi((controller) {
        try {
          controller.addStream(_db
              .collection('rider_support_tickets')
              .doc(ticketId)
              .snapshots()
              .map((d) => d.exists ? SupportTicket.fromMap(d.id, d.data()!) : null));
        } catch (e, st) {
          controller.addError(e, st);
          controller.close();
        }
      });

  @override
  Stream<List<SupportTicket>> tickets(String riderId) => Stream.multi((controller) {
        try {
          controller.addStream(_db
              .collection('rider_support_tickets')
              .where('riderId', isEqualTo: riderId)
              .snapshots()
              .map((s) {
            final list = s.docs.map((d) => SupportTicket.fromMap(d.id, d.data())).toList();
            list.sort((a, b) {
              final at = a.createdAt;
              final bt = b.createdAt;
              if (at == null || bt == null) return 0;
              return bt.compareTo(at);
            });
            return list;
          }));
        } catch (e, st) {
          controller.addError(e, st);
          controller.close();
        }
      });
}

/// The category's display label (shared by the submit form and the request
/// list, so both read the same wording).
String supportCategoryLabel(AppLocalizations l, String category) => switch (category) {
      kSupportCategoryEarningsPayouts => l.helpTopicEarningsPayouts,
      kSupportCategoryAccountDocuments => l.helpTopicAccountDocuments,
      _ => l.helpTopicDeliveryIssue,
    };

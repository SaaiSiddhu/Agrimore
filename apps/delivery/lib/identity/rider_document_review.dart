// lib/identity/rider_document_review.dart
//
// Phase DLVDOC3 — a rider replacing one KYC document photo after their
// application was already decided, independent of the whole-application
// status and independent of identity/vehicle field changes
// (rider_identity.dart). Mirrors that file's own
// RiderIdentityBackend/CallableRiderIdentityBackend shape. Backend:
// functions/src/delivery/riderDocumentReview.ts (DLVDOC2).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

enum DocumentReviewStatus { none, pending, approved, rejected }

class DocumentReview {
  const DocumentReview({required this.status, this.rejectionReason});
  final DocumentReviewStatus status;
  final String? rejectionReason;

  static const DocumentReview none = DocumentReview(status: DocumentReviewStatus.none);

  factory DocumentReview.fromMap(Object? m) {
    if (m is! Map) return none;
    return DocumentReview(
      status: switch (m['status'] as String?) {
        'pending' => DocumentReviewStatus.pending,
        'approved' => DocumentReviewStatus.approved,
        'rejected' => DocumentReviewStatus.rejected,
        _ => DocumentReviewStatus.none,
      },
      rejectionReason: m['rejectionReason'] as String?,
    );
  }
}

/// Why a submission was refused. Worded by the screen.
enum DocumentReplacementFailure { alreadyPending, invalid, network, unknown }

class DocumentReplacementException implements Exception {
  const DocumentReplacementException(this.failure);
  final DocumentReplacementFailure failure;
}

DocumentReplacementException documentReplacementExceptionOf(String code, String? reason) {
  if (reason == 'already_pending') {
    return const DocumentReplacementException(DocumentReplacementFailure.alreadyPending);
  }
  return switch (code) {
    'invalid-argument' || 'failed-precondition' =>
      const DocumentReplacementException(DocumentReplacementFailure.invalid),
    'unavailable' || 'deadline-exceeded' =>
      const DocumentReplacementException(DocumentReplacementFailure.network),
    _ => const DocumentReplacementException(DocumentReplacementFailure.unknown),
  };
}

String documentStagingPath(String uid, String submissionId) =>
    'delivery_document_submissions/$uid/$submissionId';

/// DLVC3: one exact, historical `document_review_submissions/{id}` record --
/// distinct from [DocumentReview] (the denormalized, CURRENT-only status per
/// docType on `delivery_partners`), this is what a notification's own
/// `submissionId` names: the specific submission that notification was
/// about, whatever the rider's CURRENT status for that docType has since
/// become (a later resubmission may already be pending again by the time
/// this is opened).
class DocumentSubmission {
  const DocumentSubmission({
    required this.id,
    required this.docType,
    required this.status,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });
  final String id;
  final String docType;
  final DocumentReviewStatus status;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory DocumentSubmission.fromDoc(String id, Map<String, dynamic> m) => DocumentSubmission(
        id: id,
        docType: (m['docType'] as String?) ?? '',
        status: switch (m['status'] as String?) {
          'approved' => DocumentReviewStatus.approved,
          'rejected' => DocumentReviewStatus.rejected,
          _ => DocumentReviewStatus.pending,
        },
        rejectionReason: m['rejectionReason'] as String?,
        submittedAt: (m['submittedAt'] as Timestamp?)?.toDate(),
        reviewedAt: (m['reviewedAt'] as Timestamp?)?.toDate(),
      );
}

abstract class RiderDocumentReviewBackend {
  /// This rider's live review-status map, keyed by docType -- reads the
  /// same denormalized delivery_partners.documentReview field
  /// submitDocumentReplacement/reviewDocumentSubmission already maintain.
  Stream<Map<String, DocumentReview>> reviewsFor(String riderId);

  /// Uploads [bytes] to a fresh staging path, then registers the submission.
  /// Returns the new submission id.
  Future<String> submitReplacement({
    required String docType,
    required Uint8List bytes,
    required String contentType,
  });

  /// DLVC3: the ONE exact submission [submissionId] names -- live, so a
  /// decision made while this is open updates in place. `null` once
  /// settled means the document genuinely does not exist under this
  /// reader's own access (deleted, a bad/legacy id, or -- enforced by
  /// `firestore.rules` itself, not this method -- it belongs to a
  /// different rider entirely); this method never distinguishes those
  /// from each other, matching `IdentityChangeScreen`'s own established
  /// by-id precedent (a permission-denied read surfaces as a thrown
  /// `FirebaseException`, a missing document surfaces as `null` -- the
  /// screen shows the same honest "not available" card either way).
  Stream<DocumentSubmission?> submissionById(String submissionId);
}

class CallableRiderDocumentReviewBackend implements RiderDocumentReviewBackend {
  CallableRiderDocumentReviewBackend({FirebaseFirestore? db}) : _dbOverride = db;
  final FirebaseFirestore? _dbOverride;

  /// Deferred to first actual use (same reasoning as RiderMoneyService._db):
  /// bare construction must not touch FirebaseFirestore.instance.
  late final FirebaseFirestore _db = _dbOverride ?? FirebaseFirestore.instance;

  /// `Stream.multi` (not a plain `=>`/`.snapshots()` expression) so `_db` --
  /// and so `FirebaseFirestore.instance` -- is only touched once something
  /// actually subscribes, matching `RiderMoneyService`'s own established
  /// reasoning: a widget that builds this eagerly (every `_DocumentPreviewTile`
  /// does) must not crash in a test with no Firebase app just for having
  /// been built.
  @override
  Stream<Map<String, DocumentReview>> reviewsFor(String riderId) => Stream.multi((controller) {
        try {
          controller.addStream(_db.collection('delivery_partners').doc(riderId).snapshots().map((doc) {
            final raw = doc.data()?['documentReview'];
            if (raw is! Map) return const {};
            return raw.map((k, v) => MapEntry(k.toString(), DocumentReview.fromMap(v)));
          }));
        } catch (e, st) {
          controller.addError(e, st);
          controller.close();
        }
      });

  @override
  Stream<DocumentSubmission?> submissionById(String submissionId) => Stream.multi((controller) {
        try {
          controller.addStream(
            _db.collection('document_review_submissions').doc(submissionId).snapshots().map(
                  (doc) => doc.exists ? DocumentSubmission.fromDoc(doc.id, doc.data()!) : null,
                ),
          );
        } catch (e, st) {
          controller.addError(e, st);
          controller.close();
        }
      });

  @override
  Future<String> submitReplacement({
    required String docType,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final submissionId = _db.collection('document_review_submissions').doc().id;
    final path = documentStagingPath(uid, submissionId);
    try {
      await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
      final r = await FirebaseFunctions.instance
          .httpsCallable('submitDocumentReplacement')
          .call<dynamic>({'docType': docType, 'submissionId': submissionId});
      return (r.data as Map)['submissionId'] as String;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      debugPrint('submitDocumentReplacement refused: ${e.code} ${details['reason']}');
      throw documentReplacementExceptionOf(e.code, details['reason'] as String?);
    } on FirebaseException catch (e) {
      debugPrint('Document staging upload failed: ${e.code}');
      throw const DocumentReplacementException(DocumentReplacementFailure.network);
    }
  }
}

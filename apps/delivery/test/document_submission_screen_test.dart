// Phase DLVC3 — DocumentSubmissionScreen: the rider-facing destination a
// document-review notification actually names (the EXACT submission, never
// "whichever is currently pending"). Covers the states the owner's own
// brief named explicitly: correct document type, pending/approved/rejected,
// rejection reason, a reviewed timestamp, a correction action, and a
// missing/deleted/unauthorized submission -- plus the two-distinct-
// submissions scenario proving a notification for an OLDER submission
// still shows that submission's own exact outcome, not a newer one for the
// same document.
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/identity/rider_document_review.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/profile/document_submission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements RiderDocumentReviewBackend {
  _FakeBackend(this.submissions);
  final Map<String, DocumentSubmission> submissions;
  final submitted = <String>[];

  @override
  Stream<Map<String, DocumentReview>> reviewsFor(String riderId) => const Stream.empty();

  @override
  Stream<DocumentSubmission?> submissionById(String submissionId) => Stream.value(submissions[submissionId]);

  @override
  Future<String> submitReplacement({
    required String docType,
    required Uint8List bytes,
    required String contentType,
  }) async {
    submitted.add(docType);
    return 'sub-new';
  }
}

Future<({Uint8List bytes, String contentType})?> _fakePick(String docType) async =>
    (bytes: Uint8List.fromList(const [1, 2, 3]), contentType: 'image/jpeg');

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('a pending submission shows the correct document type and a pending message', (t) async {
    final backend = _FakeBackend({
      'sub-1': const DocumentSubmission(id: 'sub-1', docType: 'aadhaarFront', status: DocumentReviewStatus.pending),
    });
    await t.pumpWidget(host(DocumentSubmissionScreen(submissionId: 'sub-1', backend: backend)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Aadhaar — front'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Agrimore is reviewing this document.'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-submission-replace')), findsNothing,
        reason: 'no correction action while still pending -- nothing to correct yet');
  });

  testWidgets('an approved submission shows the reviewed date, no correction action', (t) async {
    final reviewedAt = DateTime(2026, 9, 20, 14, 30);
    final backend = _FakeBackend({
      'sub-1': DocumentSubmission(
        id: 'sub-1',
        docType: 'selfie',
        status: DocumentReviewStatus.approved,
        reviewedAt: reviewedAt,
      ),
    });
    await t.pumpWidget(host(DocumentSubmissionScreen(submissionId: 'sub-1', backend: backend)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Selfie'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.textContaining('Reviewed on'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-submission-replace')), findsNothing);
  });

  testWidgets('a rejected submission shows the exact reason and a working correction action', (t) async {
    final backend = _FakeBackend({
      'sub-1': const DocumentSubmission(
        id: 'sub-1',
        docType: 'license',
        status: DocumentReviewStatus.rejected,
        rejectionReason: 'Photo is blurry',
      ),
    });
    await t.pumpWidget(host(DocumentSubmissionScreen(
      submissionId: 'sub-1',
      backend: backend,
      pickReplacementPhoto: _fakePick,
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Driving licence'), findsOneWidget);
    expect(find.text('Not approved'), findsOneWidget);
    expect(find.text('Photo is blurry'), findsOneWidget);
    final replaceButton = find.byKey(const ValueKey('document-submission-replace'));
    expect(replaceButton, findsOneWidget);
    await t.tap(replaceButton);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'a real correction submit must not throw');
    expect(backend.submitted, ['license']);
  });

  testWidgets('a missing/deleted submission shows an honest not-available card, not a crash', (t) async {
    final backend = _FakeBackend(const {}); // no 'sub-gone' entry at all
    await t.pumpWidget(host(DocumentSubmissionScreen(submissionId: 'sub-gone', backend: backend)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('This submission is no longer available.'), findsOneWidget);
  });

  testWidgets('an unauthorized read (permission-denied) shows the SAME honest not-available card', (t) async {
    // Mirrors what firestore.rules itself enforces: a submission that is
    // not this rider's own surfaces as a thrown FirebaseException from the
    // real backend, never as this rider's real data. This screen must not
    // try to guess or distinguish a reason it cannot actually confirm.
    final backend = _ThrowingBackend();
    await t.pumpWidget(host(DocumentSubmissionScreen(submissionId: 'sub-other-rider', backend: backend)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'a permission-denied read must degrade to a message, never crash');
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('two distinct submissions for the same document: opening the OLDER one shows ITS exact outcome',
      (t) async {
    // The exact scenario the owner's brief names: review submission A,
    // THEN create submission B for the same document -- opening A's own
    // notification must still show A's own outcome, never B's (which a
    // naive "latest submission for this docType" lookup would show
    // instead).
    final backend = _FakeBackend({
      'sub-A': const DocumentSubmission(
        id: 'sub-A',
        docType: 'aadhaarFront',
        status: DocumentReviewStatus.rejected,
        rejectionReason: 'Glare on the photo',
      ),
      'sub-B': const DocumentSubmission(id: 'sub-B', docType: 'aadhaarFront', status: DocumentReviewStatus.pending),
    });
    await t.pumpWidget(host(DocumentSubmissionScreen(submissionId: 'sub-A', backend: backend)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Not approved'), findsOneWidget, reason: "A's own outcome, not B's still-pending one");
    expect(find.text('Glare on the photo'), findsOneWidget);
    expect(find.text('Pending review'), findsNothing, reason: "B's state must never leak into A's own screen");
  });
}

class _ThrowingBackend implements RiderDocumentReviewBackend {
  @override
  Stream<Map<String, DocumentReview>> reviewsFor(String riderId) => const Stream.empty();

  @override
  Stream<DocumentSubmission?> submissionById(String submissionId) =>
      Stream<DocumentSubmission?>.error(FirebaseException(plugin: 'firestore', code: 'permission-denied'));

  @override
  Future<String> submitReplacement({
    required String docType,
    required Uint8List bytes,
    required String contentType,
  }) async =>
      'unused';
}

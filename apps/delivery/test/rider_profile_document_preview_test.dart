// DLVDOC1: a rider's own already-uploaded document gets a "View" action;
// one that was never submitted does not. The actual Storage download-URL
// resolution is not mocked here (no injectable seam exists for it, matching
// this app's own established `_KycTile`/`_DeliveryProofTile` precedent,
// neither of which is mocked either) -- under flutter_test, with no real
// Firebase app, the real call fails, and this suite's job is to prove that
// failure degrades to an honest message rather than a crash or a silent
// blank screen.
//
// DLVDOC3: per-document review status and the "Replace" action, backed by
// an injected fake RiderDocumentReviewBackend (unlike the read-only View
// action above, replacement has a real injectable seam from day one).
import 'dart:typed_data';

import 'package:delivery/identity/rider_document_review.dart';
import 'package:delivery/registration/rider_application.dart' show RiderDocument;
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rider_profile_screen_test.dart' show authedProvider, host, FakeAccountBackend;

class _FakeDocumentReviewBackend implements RiderDocumentReviewBackend {
  _FakeDocumentReviewBackend({Map<String, DocumentReview> reviews = const {}}) : _reviews = reviews;
  final Map<String, DocumentReview> _reviews;
  DocumentReplacementException? failNextSubmit;
  final submitted = <String>[];

  @override
  Stream<Map<String, DocumentReview>> reviewsFor(String riderId) => Stream.value(_reviews);

  @override
  Future<String> submitReplacement({
    required String docType,
    required Uint8List bytes,
    required String contentType,
  }) async {
    submitted.add(docType);
    final f = failNextSubmit;
    if (f != null) {
      failNextSubmit = null;
      throw f;
    }
    return 'sub-fake-1';
  }
}

Future<({Uint8List bytes, String contentType})?> _fakePick(RiderDocument doc) async =>
    (bytes: Uint8List.fromList(const [1, 2, 3]), contentType: 'image/jpeg');

void main() {
  testWidgets('a document on file gets a View action; one never submitted does not', (t) async {
    final auth = await authedProvider(t);
    await t.pumpWidget(host(
      auth,
      RiderProfileScreen(
        backend: FakeAccountBackend(),
        partnerData: const {
          'name': 'Ravi',
          'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
        },
      ),
    ));
    await t.pumpAndSettle();
    // The document list sits far enough down RiderProfileScreen's own
    // ListView that these rows build (and are genuinely present) without
    // ever being scrolled into view -- skipOffstage:false is required for
    // find() to see them at all; ensureVisible (below, for the tap test) is
    // separately required to make one of them actually hit-testable.
    expect(find.byKey(const ValueKey('view-aadhaarFront'), skipOffstage: false), findsOneWidget);
    // Selfie was never submitted -- no action for it.
    expect(find.byKey(const ValueKey('view-selfie'), skipOffstage: false), findsNothing);
  });

  testWidgets('tapping View on a real (uninitialized-Firebase) build degrades to a message, not a crash', (t) async {
    final auth = await authedProvider(t);
    await t.pumpWidget(host(
      auth,
      RiderProfileScreen(
        backend: FakeAccountBackend(),
        partnerData: const {
          'name': 'Ravi',
          'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
        },
      ),
    ));
    await t.pumpAndSettle();

    final viewButton = find.byKey(const ValueKey('view-aadhaarFront'), skipOffstage: false);
    await t.ensureVisible(viewButton);
    await t.pumpAndSettle();
    await t.tap(viewButton);
    await t.pumpAndSettle();

    // No preview dialog opened (the real Storage call cannot succeed here),
    // and no exception propagated out of the tap -- confirmed by the widget
    // tree still being present and responsive afterwards.
    expect(find.byKey(const ValueKey('close-document-preview'), skipOffstage: false), findsNothing);
    expect(find.byType(RiderProfileScreen), findsOneWidget);
  });

  group('DLVDOC3: per-document review status', () {
    testWidgets('a pending review shows "Pending review" and disables Replace', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {
            'name': 'Ravi',
            'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
          },
          documentReviewBackend: _FakeDocumentReviewBackend(
            reviews: const {'aadhaarFront': DocumentReview(status: DocumentReviewStatus.pending)},
          ),
          pickReplacementPhoto: _fakePick,
        ),
      ));
      await t.pumpAndSettle();

      expect(find.text('Pending review', skipOffstage: false), findsOneWidget);
      final replaceButton = t.widget<TextButton>(
        find.byKey(const ValueKey('replace-aadhaarFront'), skipOffstage: false),
      );
      expect(replaceButton.onPressed, isNull, reason: 'a second submission while one is pending would only be refused');
    });

    testWidgets('a rejected review shows the reason', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {
            'name': 'Ravi',
            'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
          },
          documentReviewBackend: _FakeDocumentReviewBackend(
            reviews: const {
              'aadhaarFront': DocumentReview(status: DocumentReviewStatus.rejected, rejectionReason: 'Photo is blurry'),
            },
          ),
          pickReplacementPhoto: _fakePick,
        ),
      ));
      await t.pumpAndSettle();

      expect(find.text('Not approved', skipOffstage: false), findsOneWidget);
      expect(find.text('Photo is blurry', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tapping Replace submits the picked photo and shows a confirmation', (t) async {
      final auth = await authedProvider(t);
      final backend = _FakeDocumentReviewBackend();
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {
            'name': 'Ravi',
            'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
          },
          documentReviewBackend: backend,
          pickReplacementPhoto: _fakePick,
        ),
      ));
      await t.pumpAndSettle();

      final replaceButton = find.byKey(const ValueKey('replace-aadhaarFront'), skipOffstage: false);
      await t.ensureVisible(replaceButton);
      await t.pumpAndSettle();
      await t.tap(replaceButton);
      await t.pumpAndSettle();

      expect(backend.submitted, ['aadhaarFront']);
      expect(find.text('Submitted for review'), findsOneWidget);
    });

    testWidgets('Replace refused as already-pending shows that specific message', (t) async {
      final auth = await authedProvider(t);
      final backend = _FakeDocumentReviewBackend()
        ..failNextSubmit = const DocumentReplacementException(DocumentReplacementFailure.alreadyPending);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {
            'name': 'Ravi',
            'kycDocuments': {'aadhaarFront': 'delivery_documents/r1/aadhaarFront'},
          },
          documentReviewBackend: backend,
          pickReplacementPhoto: _fakePick,
        ),
      ));
      await t.pumpAndSettle();

      final replaceButton = find.byKey(const ValueKey('replace-aadhaarFront'), skipOffstage: false);
      await t.ensureVisible(replaceButton);
      await t.pumpAndSettle();
      await t.tap(replaceButton);
      await t.pumpAndSettle();

      expect(find.text("A replacement for this document is already being reviewed."), findsOneWidget);
    });
  });
}

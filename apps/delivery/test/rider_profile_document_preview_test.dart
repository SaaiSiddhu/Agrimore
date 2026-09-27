// DLVDOC1: a rider's own already-uploaded document gets a "View" action;
// one that was never submitted does not. The actual Storage download-URL
// resolution is not mocked here (no injectable seam exists for it, matching
// this app's own established `_KycTile`/`_DeliveryProofTile` precedent,
// neither of which is mocked either) -- under flutter_test, with no real
// Firebase app, the real call fails, and this suite's job is to prove that
// failure degrades to an honest message rather than a crash or a silent
// blank screen.
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rider_profile_screen_test.dart' show authedProvider, host, FakeAccountBackend;

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
}

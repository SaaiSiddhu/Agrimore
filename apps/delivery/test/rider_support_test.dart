// Phase DLVSUP1 — the Help & support topic list, the submit-a-request form
// (category, message, optional attachment), and the request-status timeline.
import 'dart:async';
import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cross_file/cross_file.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/support/help_support_screen.dart';
import 'package:delivery/screens/support/submit_support_request_screen.dart';
import 'package:delivery/screens/support/support_request_status_screen.dart';
import 'package:delivery/support/rider_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSupportBackend implements RiderSupportBackend {
  final submissions = <Map<String, Object?>>[];
  final uploads = <String>[];
  SupportRequestException? failWith;
  Object? uploadFailWith;
  SupportTicket? current;
  final _ticket = StreamController<SupportTicket?>.broadcast();

  /// DLVC4: pushes a listener error through the SAME `ticket()` stream a
  /// real Firestore permission-denied or dropped-listener failure would
  /// surface as -- lets a test simulate the stream erroring AFTER it has
  /// already delivered real data, the case `hasError` must not let the
  /// screen keep showing as a stale, no-longer-updating timeline.
  void failTicketStream(Object error) => _ticket.addError(error);

  /// DLVSUP2: drives [tickets]. Null means "still loading" (never emits);
  /// set to a list (possibly empty) to resolve it, or set [ticketsFailWith]
  /// to make it error instead. [tickets] is re-evaluated on every call (not
  /// cached), so a test can mutate these fields and call it again to
  /// simulate a retry resolving differently.
  List<SupportTicket>? ticketsList;
  Object? ticketsFailWith;
  final _neverEmits = StreamController<List<SupportTicket>>.broadcast();

  @override
  String? get currentUid => 'r1';

  @override
  Future<String> uploadAttachment(String requestId, Uint8List bytes, String contentType) async {
    if (uploadFailWith != null) throw uploadFailWith!;
    final path = 'support_attachments/r1/$requestId.jpg';
    uploads.add(path);
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
    if (failWith != null) throw failWith!;
    submissions.add({
      'category': category,
      'message': message,
      'attachmentPath': attachmentPath,
    });
    return 'r1_$requestId';
  }

  @override
  Stream<SupportTicket?> ticket(String ticketId) async* {
    yield current;
    yield* _ticket.stream;
  }

  @override
  Stream<List<SupportTicket>> tickets(String riderId) {
    if (ticketsFailWith != null) return Stream<List<SupportTicket>>.error(ticketsFailWith!);
    final list = ticketsList;
    if (list == null) return _neverEmits.stream; // still "loading": never emits, never completes
    return Stream.value(list);
  }
}

SupportTicket _ticket({
  required SupportTicketStatus status,
  String category = kSupportCategoryDeliveryIssue,
  String message = 'The customer was not reachable.',
  String? resolutionNote,
  DateTime? seenAt,
  DateTime? closedAt,
}) =>
    SupportTicket(
      id: 'r1_req1',
      category: category,
      message: message,
      status: status,
      resolutionNote: resolutionNote,
      createdAt: DateTime(2026, 9, 27),
      seenAt: seenAt,
      closedAt: closedAt,
    );

Widget host(Widget child) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('Help & support topic list (DLVSUP1)', () {
    testWidgets('tapping a topic opens the submit form with that category pre-selected', (t) async {
      await t.pumpWidget(host(const HelpSupportScreen()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('help-topic-earnings-payouts')));
      await t.pumpAndSettle();
      expect(find.byType(SubmitSupportRequestScreen), findsOneWidget);
      final screen = t.widget<SubmitSupportRequestScreen>(find.byType(SubmitSupportRequestScreen));
      expect(screen.category, kSupportCategoryEarningsPayouts);
    });

    testWidgets('all three topics and the call/emergency rows are present', (t) async {
      await t.pumpWidget(host(const HelpSupportScreen()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-topic-delivery-issue')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-topic-earnings-payouts')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-topic-account-documents')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-call-support')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-emergency')), findsOneWidget);
    });
  });

  group('submit a support request (DLVSUP1)', () {
    testWidgets('submitting a valid message calls the backend and opens the status screen', (t) async {
      final backend = FakeSupportBackend();
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('support-message')), 'The customer was not reachable at the address.');
      await t.tap(find.byKey(const ValueKey('support-submit')));
      await t.pumpAndSettle();
      expect(backend.submissions, [
        {
          'category': 'delivery_issue',
          'message': 'The customer was not reachable at the address.',
          'attachmentPath': null,
        }
      ]);
      expect(find.byType(SupportRequestStatusScreen), findsOneWidget);
    });

    testWidgets('a message that is too short shows an inline error, not a toast', (t) async {
      final backend = FakeSupportBackend();
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('support-message')), 'hi');
      await t.tap(find.byKey(const ValueKey('support-submit')));
      await t.pumpAndSettle();
      expect(find.text('Write at least 3 characters (up to 500).'), findsOneWidget);
      expect(backend.submissions, isEmpty);
    });

    testWidgets('changing the category dropdown changes what is submitted', (t) async {
      final backend = FakeSupportBackend();
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
      )));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-category')));
      await t.pumpAndSettle();
      await t.tap(find.text('Account & documents').last);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('support-message')), 'Need help updating my licence file.');
      await t.tap(find.byKey(const ValueKey('support-submit')));
      await t.pumpAndSettle();
      expect(backend.submissions.single['category'], kSupportCategoryAccountDocuments);
    });

    testWidgets('adding a photo uploads it and shows a removable chip; submitting sends its path', (t) async {
      final backend = FakeSupportBackend();
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
        pickImage: () async => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-add-attachment')));
      await t.pumpAndSettle();
      expect(backend.uploads, hasLength(1));
      expect(backend.uploads.single, startsWith('support_attachments/r1/'));
      expect(backend.uploads.single, endsWith('.jpg'));
      expect(find.byKey(const ValueKey('support-remove-attachment')), findsOneWidget);
      expect(find.byKey(const ValueKey('support-add-attachment')), findsNothing);

      await t.enterText(find.byKey(const ValueKey('support-message')), 'Please see the attached screenshot.');
      await t.tap(find.byKey(const ValueKey('support-submit')));
      await t.pumpAndSettle();
      expect(backend.submissions.single['attachmentPath'], backend.uploads.first);
    });

    testWidgets('removing an attachment before submitting sends no attachmentPath', (t) async {
      final backend = FakeSupportBackend();
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
        pickImage: () async => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-add-attachment')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-remove-attachment')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-add-attachment')), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('support-message')), 'No attachment this time.');
      await t.tap(find.byKey(const ValueKey('support-submit')));
      await t.pumpAndSettle();
      expect(backend.submissions.single['attachmentPath'], null);
    });

    testWidgets('a failed upload shows a toast and still allows submitting without it', (t) async {
      final backend = FakeSupportBackend()..uploadFailWith = Exception('network down');
      await t.pumpWidget(host(SubmitSupportRequestScreen(
        category: kSupportCategoryDeliveryIssue,
        backend: backend,
        pickImage: () async => XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      )));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-add-attachment')));
      await t.pumpAndSettle();
      expect(find.text('Could not attach that file. You can still submit without it.'), findsOneWidget);
      expect(find.byKey(const ValueKey('support-add-attachment')), findsOneWidget);
    });
  });

  group('support request status (DLVSUP1)', () {
    testWidgets('a submitted ticket shows only the Submitted step as done', (t) async {
      final backend = FakeSupportBackend()..current = _ticket(status: SupportTicketStatus.submitted);
      await t.pumpWidget(host(SupportRequestStatusScreen(ticketId: 'r1_req1', backend: backend)));
      await t.pumpAndSettle();
      expect(find.text('Your request has been recorded.'), findsOneWidget);
      expect(find.text('Your request has been viewed.'), findsNothing);
    });

    testWidgets('a seen ticket shows both Submitted and Seen as done', (t) async {
      final backend = FakeSupportBackend()
        ..current = _ticket(status: SupportTicketStatus.seen, seenAt: DateTime(2026, 9, 27, 11));
      await t.pumpWidget(host(SupportRequestStatusScreen(ticketId: 'r1_req1', backend: backend)));
      await t.pumpAndSettle();
      expect(find.text('Your request has been recorded.'), findsOneWidget);
      expect(find.text('Your request has been viewed.'), findsOneWidget);
      expect(find.text('Request closed. View the outcome below.'), findsNothing);
    });

    testWidgets('a closed ticket shows the outcome text', (t) async {
      final backend = FakeSupportBackend()
        ..current = _ticket(
          status: SupportTicketStatus.closed,
          seenAt: DateTime(2026, 9, 27, 11),
          closedAt: DateTime(2026, 9, 27, 15),
          resolutionNote: 'Reassigned to a different rider; delivered successfully.',
        );
      await t.pumpWidget(host(SupportRequestStatusScreen(ticketId: 'r1_req1', backend: backend)));
      await t.pumpAndSettle();
      expect(find.text('Request closed. View the outcome below.'), findsOneWidget);
      expect(find.text('Reassigned to a different rider; delivered successfully.'), findsOneWidget);
    });

    testWidgets('New request pops back to the previous screen', (t) async {
      final backend = FakeSupportBackend()..current = _ticket(status: SupportTicketStatus.submitted);
      await t.pumpWidget(host(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SupportRequestStatusScreen(ticketId: 'r1_req1', backend: backend),
              )),
              child: const Text('open status'),
            ),
          ),
        ),
      )));
      await t.pumpAndSettle();
      await t.tap(find.text('open status'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('support-new-request')));
      await t.pumpAndSettle();
      expect(find.text('open status'), findsOneWidget);
    });

    testWidgets('a nonexistent ticket shows the unavailable card, not a bare identity-flow string (DLVC4)', (t) async {
      final backend = FakeSupportBackend(); // current stays null; _ticket never emits
      await t.pumpWidget(host(SupportRequestStatusScreen(ticketId: 'no-such-ticket', backend: backend)));
      await t.pumpAndSettle();
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('This request is no longer available.'), findsOneWidget);
      expect(find.text('Check your details and try again.'), findsNothing);
    });

    testWidgets('a ticket stream that errors after loading falls back to unavailable, not a stale timeline (DLVC4)', (t) async {
      final backend = FakeSupportBackend()..current = _ticket(status: SupportTicketStatus.submitted);
      await t.pumpWidget(host(SupportRequestStatusScreen(ticketId: 'r1_req1', backend: backend)));
      await t.pumpAndSettle();
      expect(find.text('Your request has been recorded.'), findsOneWidget);
      backend.failTicketStream(Exception('permission-denied'));
      await t.pumpAndSettle();
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Your request has been recorded.'), findsNothing);
    });
  });
}

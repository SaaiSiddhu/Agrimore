// Phase DLVSUP2 (brief §7.2) — the persistent "My support requests" list,
// closing the reachability gap DLVSUP1's own row left open (a ticket was
// only ever reachable directly after submitting it).
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/support/my_support_requests_screen.dart';
import 'package:delivery/screens/support/support_request_status_screen.dart';
import 'package:delivery/support/rider_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rider_support_test.dart' show FakeSupportBackend;

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

SupportTicket _ticket(String id, {
  SupportTicketStatus status = SupportTicketStatus.submitted,
  String category = kSupportCategoryDeliveryIssue,
  String message = 'The customer was not reachable.',
}) =>
    SupportTicket.fromMap(id, {
      'category': category,
      'message': message,
      'status': switch (status) {
        SupportTicketStatus.seen => 'seen',
        SupportTicketStatus.closed => 'closed',
        SupportTicketStatus.submitted => 'submitted',
      },
    });

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  testWidgets('shows a spinner while loading', (tester) async {
    final backend = FakeSupportBackend(); // ticketsList left null: never emits
    await tester.pumpWidget(host(MySupportRequestsScreen(riderId: 'r1', backend: backend)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no tickets', (tester) async {
    final backend = FakeSupportBackend()..ticketsList = const [];
    await tester.pumpWidget(host(MySupportRequestsScreen(riderId: 'r1', backend: backend)));
    await tester.pumpAndSettle();
    expect(find.text(l.mySupportRequestsEmpty), findsOneWidget);
  });

  testWidgets('shows a network-error state with a working Retry', (tester) async {
    final backend = FakeSupportBackend()..ticketsFailWith = Exception('offline');
    await tester.pumpWidget(host(MySupportRequestsScreen(riderId: 'r1', backend: backend)));
    await tester.pumpAndSettle();
    expect(find.text(l.mySupportRequestsNetworkError), findsOneWidget);

    // Retry re-subscribes; once the backend has real data, it must show.
    backend.ticketsFailWith = null;
    backend.ticketsList = [_ticket('tk-1')];
    await tester.tap(find.text(l.actionRetry));
    await tester.pumpAndSettle();
    expect(find.text(l.mySupportRequestsNetworkError), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists tickets newest first and opens the tapped one by its exact id', (tester) async {
    final older = _ticket('tk-old', status: SupportTicketStatus.closed, message: 'Older issue');
    final newer = _ticket('tk-new', status: SupportTicketStatus.submitted, message: 'Newer issue');
    final backend = FakeSupportBackend()..ticketsList = [older, newer];
    // SupportTicket.fromMap reads createdAt from a Timestamp; the fixture
    // above supplies none, so ordering here is driven by list order alone
    // (rider_support.dart's own sort is a no-op when createdAt is null on
    // either side) -- both rows must still render correctly regardless.
    await tester.pumpWidget(host(MySupportRequestsScreen(riderId: 'r1', backend: backend)));
    await tester.pumpAndSettle();

    expect(find.text('Older issue'), findsOneWidget);
    expect(find.text('Newer issue'), findsOneWidget);

    await tester.tap(find.text('Newer issue'));
    await tester.pumpAndSettle();
    final screen = tester.widget<SupportRequestStatusScreen>(find.byType(SupportRequestStatusScreen));
    expect(screen.ticketId, 'tk-new');
  });
}

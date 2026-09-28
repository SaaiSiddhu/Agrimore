// ADMR-89 — FinanceReconciliationScreen's own request-robustness contract,
// provable now that FinanceReconciliationRepository is injectable (mirrors
// FinancialRecordDetailScreen's own established FirebaseFirestore-injection
// convention). A real Cloud Functions call is never invoked here — that
// path is what the real-emulator Node suite already proves
// (phaseADMR80_finance_reconciliation_test.js, 46/46, including the
// multi-group cursor round-trip regression ADMR-88 fixed). What a fake
// repository CAN prove honestly, and could not be proven at all before this
// phase: that a slow, superseded request's response is discarded instead of
// corrupting state a newer request already produced, and that the widget
// renders the typed model correctly end to end.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/finance/finance_reconciliation_models.dart';
import 'package:agrimore_admin/screens/admin/finance/finance_reconciliation_screen.dart';

class _FakeRepo implements FinanceReconciliationRepository {
  final List<Completer<ScanPage>> pending = [];
  final List<Map<String, dynamic>?> callCursors = [];

  @override
  Future<ScanPage> scan({Map<String, dynamic>? cursor}) {
    callCursors.add(cursor);
    final c = Completer<ScanPage>();
    pending.add(c);
    return c.future;
  }

  void resolve(int callIndex, ScanPage page) => pending[callIndex].complete(page);
  void fail(int callIndex, Object error) => pending[callIndex].completeError(error);
}

FinanceFinding _finding(String id, {String kind = 'paid_missing_reference', String actorType = 'seller'}) => FinanceFinding(
      id: id,
      kind: kind,
      actorType: actorType,
      recordId: id,
      actorId: 'actor_1',
      amountRupees: 50.0,
      summary: 'summary for $id',
      detail: const {},
      confirmation: 'confirmed',
    );

ScanPage _page({
  required List<FinanceFinding> findings,
  bool hasMore = false,
  Map<String, dynamic>? nextCursor,
  bool incomplete = false,
}) =>
    ScanPage(
      findings: findings,
      coverage: ScanCoverage.empty,
      incomplete: incomplete,
      incompleteReasons: incomplete ? const ['a reason'] : const [],
      observedAt: DateTime.utc(2026, 9, 28),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );

Future<void> _pump(WidgetTester tester, FinanceReconciliationRepository repo) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: FinanceReconciliationScreen(repository: repo)));
}

void main() {
  testWidgets('renders findings from the typed repository response', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    repo.resolve(0, _page(findings: [_finding('f1')]));
    await tester.pumpAndSettle();

    expect(find.text('Paid with no reference on file'), findsOneWidget);
    expect(find.textContaining('record: f1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a malformed/erroring response shows honest operator language, not an empty "no findings" state', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    repo.fail(0, MalformedScanResponseException("The server's response could not be read."));
    await tester.pumpAndSettle();

    expect(find.textContaining("server's response could not be read"), findsOneWidget);
    expect(find.text('No findings'), findsNothing);
  });

  testWidgets('load more appends the second page under the first, in order', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    repo.resolve(0, _page(findings: [_finding('f1')], hasMore: true, nextCursor: {'state': 'continue'}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load older records'));
    await tester.pump();
    expect(repo.callCursors.length, 2);
    expect(repo.callCursors[1], {'state': 'continue'});
    repo.resolve(1, _page(findings: [_finding('f2')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('record: f1'), findsOneWidget);
    expect(find.textContaining('record: f2'), findsOneWidget);
  });

  testWidgets(
    'a stale in-flight load-more response is discarded, not applied, once a newer re-scan has already reset the list',
    (tester) async {
      final repo = _FakeRepo();
      await _pump(tester, repo);
      // Call 0: the initial scan.
      repo.resolve(0, _page(findings: [_finding('f1')], hasMore: true, nextCursor: {'state': 'continue'}));
      await tester.pumpAndSettle();

      // Call 1: "load more" — started, but deliberately left UNRESOLVED to simulate a slow response.
      await tester.tap(find.text('Load older records'));
      await tester.pump();
      expect(repo.pending.length, 2);

      // Call 2: a fresh re-scan fired WHILE call 1 is still in flight — this is the request that
      // should win, resetting the list to whatever IT returns.
      await tester.tap(find.byTooltip('Re-scan'));
      await tester.pump();
      expect(repo.pending.length, 3);
      repo.resolve(2, _page(findings: [_finding('fresh1')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('record: fresh1'), findsOneWidget);
      expect(find.textContaining('record: f1'), findsNothing);

      // NOW the stale call 1 finally resolves, with older-page data that must NOT be applied —
      // if the generation guard failed, this would corrupt the fresh list with "f1" and "old2".
      repo.resolve(1, _page(findings: [_finding('f1'), _finding('old2')]));
      await tester.pumpAndSettle();

      expect(find.textContaining('record: fresh1'), findsOneWidget, reason: 'the fresh rescan result must survive');
      expect(find.textContaining('record: old2'), findsNothing, reason: 'the stale load-more result must be discarded');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a finding id repeated across pages overwrites in place rather than rendering a visible duplicate', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    repo.resolve(0, _page(findings: [_finding('f1'), _finding('f2')], hasMore: true, nextCursor: {'state': 'continue'}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load older records'));
    await tester.pump();
    // A defensive scenario: the second page repeats "f1" (should not happen after ADMR-88's own
    // fix, but this proves the client-side safety net independently of that).
    repo.resolve(1, _page(findings: [_finding('f1'), _finding('f3')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('record: f1'), findsOneWidget, reason: 'must not appear twice');
    expect(find.textContaining('record: f2'), findsOneWidget);
    expect(find.textContaining('record: f3'), findsOneWidget);
  });

  testWidgets('an incomplete scan shows the banner and its reasons, never an unqualified all-clear', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    repo.resolve(0, _page(findings: const [], incomplete: true));
    await tester.pumpAndSettle();

    expect(find.text('This scan did not finish'), findsOneWidget);
    expect(find.text('a reason'), findsOneWidget);
    expect(find.text('No findings'), findsNothing);
    expect(find.textContaining('No findings in the scope'), findsOneWidget);
  });
}

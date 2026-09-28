// ADMR-86 — pure unit tests for the finding-to-record navigation mapping
// (finance_reconciliation_screen.dart's financeFindingNavigationTarget).
// This is the single most consequential piece of logic this phase adds: a
// wrong answer here silently sends an admin to the WRONG financial record
// while investigating real money. Exhaustive over every real finding kind
// financeReconciliation.ts can produce — no widget pump needed, this is a
// pure function of a Map.
import 'package:flutter_test/flutter_test.dart';

import 'package:agrimore_admin/screens/admin/finance/finance_reconciliation_screen.dart';

Map<String, dynamic> _finding({
  required String kind,
  required String actorType,
  required String recordId,
  Map<String, dynamic> detail = const {},
}) =>
    {
      'id': '$kind:$recordId',
      'kind': kind,
      'actorType': actorType,
      'recordId': recordId,
      'actorId': 'actor_1',
      'amountRupees': 100.0,
      'summary': 'summary',
      'detail': detail,
      'confirmation': 'confirmed',
    };

void main() {
  group('financeFindingNavigationTarget — seller withdrawal-level kinds go straight to the withdrawal', () {
    for (final kind in [
      'missing_destination_snapshot',
      'paid_missing_reference',
      'withdrawal_amount_mismatch',
      'withdrawal_payout_status_mismatch',
      'payout_status_drift',
    ]) {
      test(kind, () {
        final target = financeFindingNavigationTarget(_finding(kind: kind, actorType: 'seller', recordId: 'w1'));
        expect(target, (type: 'seller_withdrawal', id: 'w1'));
      });
    }
  });

  test('malformed_amount redirects to the PARENT withdrawal via detail.withdrawalId, not the child payout row', () {
    final f = _finding(
      kind: 'malformed_amount',
      actorType: 'seller',
      recordId: 'payout_child_1', // the finding's own recordId is the CHILD row
      detail: {'withdrawalId': 'w1'},
    );
    final target = financeFindingNavigationTarget(f);
    expect(target, (type: 'seller_withdrawal', id: 'w1'));
    expect(target!.id, isNot('payout_child_1'));
  });

  test('payout_ownership_mismatch redirects to the PARENT withdrawal via detail.expectedWithdrawalId', () {
    final f = _finding(
      kind: 'payout_ownership_mismatch',
      actorType: 'seller',
      recordId: 'payout_child_2',
      detail: {'expectedWithdrawalId': 'w2', 'actualWithdrawalId': 'w-other'},
    );
    final target = financeFindingNavigationTarget(f);
    expect(target, (type: 'seller_withdrawal', id: 'w2'));
  });

  test('malformed_amount with no withdrawalId in detail at all has nowhere sound to go — null, not a guess', () {
    final f = _finding(kind: 'malformed_amount', actorType: 'seller', recordId: 'payout_child_3', detail: const {});
    expect(financeFindingNavigationTarget(f), isNull);
  });

  test('rider paid_missing_reference goes to rider_payout', () {
    final target = financeFindingNavigationTarget(_finding(kind: 'paid_missing_reference', actorType: 'rider', recordId: 'rp1'));
    expect(target, (type: 'rider_payout', id: 'rp1'));
  });

  test('employee paid_missing_reference goes to employee_payout', () {
    final target = financeFindingNavigationTarget(_finding(kind: 'paid_missing_reference', actorType: 'employee', recordId: 'ep1'));
    expect(target, (type: 'employee_payout', id: 'ep1'));
  });

  test('an unrecognized actorType has nowhere sound to go', () {
    expect(financeFindingNavigationTarget(_finding(kind: 'paid_missing_reference', actorType: 'unknown', recordId: 'x')), isNull);
  });

  test('an empty recordId has nowhere sound to go, regardless of kind', () {
    expect(financeFindingNavigationTarget(_finding(kind: 'paid_missing_reference', actorType: 'seller', recordId: '')), isNull);
  });

  group('financeFindingKindLabel', () {
    test('every real kind has a real plain-language label, not its own raw enum string', () {
      const kinds = [
        'withdrawal_payout_status_mismatch',
        'paid_missing_reference',
        'withdrawal_amount_mismatch',
        'missing_destination_snapshot',
        'payout_status_drift',
        'malformed_amount',
        'payout_ownership_mismatch',
      ];
      for (final k in kinds) {
        expect(financeFindingKindLabel(k), isNot(k), reason: '$k must not fall through to the raw kind string');
      }
    });

    test('an unrecognized kind falls back to itself, not a crash', () {
      expect(financeFindingKindLabel('some_future_kind'), 'some_future_kind');
    });
  });
}

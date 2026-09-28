// lib/screens/admin/sellers/seller_wallet_admin.dart
//
// SELLER-WALLET-1 (owner 2026-09-24) — admin side of the seller wallet
// (functions/src/seller/sellerWallet.ts):
//  - Withdrawals: sellers ask to be paid their balance; admin sends the money
//    by bank/UPI and records the UTR (markSellerWithdrawalPaid), or rejects
//    with a reason the seller sees (rejectSellerWithdrawal) — the amount goes
//    back to the seller's balance.
//  - Bank/UPI changes: sellers add or change their payout account; admin
//    checks and approves (reviewSellerPayoutChange). While one is pending the
//    server refuses to pay that seller.
// Same shape as the rider screens (rider_payouts_screen.dart, DLV-M1).

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../delivery/rider_money_admin.dart' show paymentReferenceError;

final FirebaseFirestore _db = FirebaseFirestore.instance;

/// Refusals from the seller wallet callables, in admin words.
String sellerWalletRefusal(String code, String? reason) => switch (reason) {
      'payout_change_pending' => 'This seller has a bank/UPI change waiting. Review it in "Bank/UPI changes" first.',
      'no_destination' => 'The seller has no payout details for that method.',
      'not_requested' => 'This withdrawal is no longer waiting to be paid — it may already be settled.',
      'payout_mismatch' => 'The payouts in this withdrawal changed. Refresh and try again.',
      'bad_reference' => 'Enter the UTR / payment reference (4–64 characters).',
      'bad_method' => 'Choose bank or UPI.',
      'method_mismatch' => 'This withdrawal was requested for a different payment method. Refresh and try again.',
      'reason_required' => 'Give a reason (3–200 characters) — the seller sees it.',
      'not_pending' => 'This request has already been reviewed.',
      'not_found' => 'Not found — it may have been removed.',
      _ => code == 'permission-denied'
          ? 'Only admins can do this.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not complete that. Please try again.',
    };

/// The full payout destination for the admin who is about to send money.
/// `d` is `seller_payout_details`-shaped (payoutMethod/accountNumber/ifsc/…),
/// the same shape `destinationFull` is stored in (ADMR-77/78).
String sellerDestinationFull(Map<String, dynamic>? d) {
  if (d == null) return 'No payout account on file';
  if (d['payoutMethod'] == 'upi') {
    final holder = (d['accountHolder'] ?? '').toString();
    return 'UPI ${d['upiId'] ?? '—'}${holder.isEmpty ? '' : ' · $holder'}';
  }
  return '${d['accountHolder'] ?? ''}\n${d['bankName'] ?? 'Bank'} · A/c ${d['accountNumber'] ?? '—'} · IFSC ${d['ifsc'] ?? '—'}';
}

/// The MASKED destination — `d` is the withdrawal's own `destination` field
/// (method/accountLast4/ifsc/bankName/accountHolder, or method/upiId), the
/// shape every withdrawal has had since SELLER-WALLET-1's first version.
String sellerDestinationMasked(Map<String, dynamic>? d) {
  if (d == null) return 'No payout account on file';
  if (d['method'] == 'upi') return 'UPI ${d['upiId'] ?? '—'}';
  return '${d['accountHolder'] ?? ''}\n${d['bankName'] ?? 'Bank'} · A/c ending ${d['accountLast4'] ?? '—'} · IFSC ${d['ifsc'] ?? '—'}';
}

/// ADMR-78: whether a LIVE seller_payout_details read (`live`) is the exact
/// same account a withdrawal's own frozen masked `destination` (`masked`)
/// was requested against — the only condition under which live data is safe
/// to show/use for a withdrawal that predates `destinationFull` (ADMR-77).
bool destinationMatchesMasked(Map<String, dynamic>? live, Map<String, dynamic>? masked) {
  if (live == null || masked == null) return false;
  final liveMethod = live['payoutMethod'] == 'upi' ? 'upi' : 'bank';
  if (liveMethod != masked['method']) return false;
  if (liveMethod == 'upi') {
    final liveUpi = (live['upiId'] ?? '').toString().trim().toLowerCase();
    final maskedUpi = (masked['upiId'] ?? '').toString().trim().toLowerCase();
    return liveUpi.isNotEmpty && liveUpi == maskedUpi;
  }
  final liveAcct = (live['accountNumber'] ?? '').toString().replaceAll(RegExp(r'\s+'), '');
  final liveLast4 = liveAcct.length >= 4 ? liveAcct.substring(liveAcct.length - 4) : liveAcct;
  final liveIfsc = (live['ifsc'] ?? '').toString().trim().toUpperCase();
  final maskedLast4 = (masked['accountLast4'] ?? '').toString();
  final maskedIfsc = (masked['ifsc'] ?? '').toString().trim().toUpperCase();
  return liveLast4.isNotEmpty && liveLast4 == maskedLast4 && liveIfsc.isNotEmpty && liveIfsc == maskedIfsc;
}

/// ADMR-78: what an admin should be shown/allowed for one withdrawal's
/// payout destination — resolves the exact 4 states a request can be in
/// rather than ever letting a live read stand in for a historical one.
enum SellerPayoutDestinationKind {
  /// destinationFull was frozen at request time (ADMR-77 or later) — full details, safe to use as-is.
  full,
  /// No destinationFull (a pre-ADMR-77 request), but a live payout-details read matches the frozen
  /// masked destination exactly — nothing has changed, so the live full details are safe to show.
  legacyVerified,
  /// No destinationFull, and live payout details are missing or do not match the frozen masked
  /// destination — showing or using them would risk presenting the wrong account. Paying is refused
  /// here, not attempted with best-effort data.
  legacyUnverified,
  /// No destination at all on the withdrawal — should not be reachable (requestWithdrawalCore refuses
  /// no_destination before creating one), handled defensively rather than crashing or guessing.
  missing,
}

class SellerPayoutDestinationResolution {
  const SellerPayoutDestinationResolution(this.kind, this.display, this.method);
  final SellerPayoutDestinationKind kind;

  /// What to show — full unmasked details (`full`/`legacyVerified`) or the masked destination
  /// (`legacyUnverified`, so the admin still sees *something* to cross-check by eye) — or null (`missing`).
  final Map<String, dynamic>? display;

  /// Always the FROZEN record's own method (never live's), or null for `missing`.
  final String? method;

  /// Only `full` and `legacyVerified` are safe to actually pay from this dialog.
  bool get payable => kind == SellerPayoutDestinationKind.full || kind == SellerPayoutDestinationKind.legacyVerified;
}

/// Pure — takes the withdrawal's own stored fields plus (for a legacy request only) a live
/// seller_payout_details read, and returns which of the 4 states above applies.
SellerPayoutDestinationResolution resolveSellerWithdrawalDestination(
  Map<String, dynamic> withdrawal, {
  Map<String, dynamic>? liveDetails,
}) {
  final full = (withdrawal['destinationFull'] as Map?)?.cast<String, dynamic>();
  if (full != null) {
    return SellerPayoutDestinationResolution(SellerPayoutDestinationKind.full, full, full['payoutMethod'] as String?);
  }
  final masked = (withdrawal['destination'] as Map?)?.cast<String, dynamic>();
  if (masked == null) {
    return const SellerPayoutDestinationResolution(SellerPayoutDestinationKind.missing, null, null);
  }
  if (destinationMatchesMasked(liveDetails, masked)) {
    return SellerPayoutDestinationResolution(SellerPayoutDestinationKind.legacyVerified, liveDetails, masked['method'] as String?);
  }
  return SellerPayoutDestinationResolution(SellerPayoutDestinationKind.legacyUnverified, masked, masked['method'] as String?);
}

/// The text for whichever state `resolveSellerWithdrawalDestination` returned.
String sellerPayoutDestinationText(SellerPayoutDestinationResolution r) => switch (r.kind) {
      SellerPayoutDestinationKind.full => sellerDestinationFull(r.display),
      SellerPayoutDestinationKind.legacyVerified => '${sellerDestinationFull(r.display)}\n(verified against this request\'s original destination)',
      SellerPayoutDestinationKind.legacyUnverified =>
        '${sellerDestinationMasked(r.display)}\n⚠ Full details were not saved for this older request, and the seller\'s '
            'current payout details no longer match this masked destination. Do not pay — check with the seller/owner first.',
      SellerPayoutDestinationKind.missing => '⚠ No payout account on file for this request — this should not happen. Contact the owner.',
    };

double _paise(Object? v) => ((v as num?) ?? 0) / 100;

Widget _message(String text) =>
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));

Future<void> _call(BuildContext context, String name, Map<String, dynamic> data, String done) async {
  try {
    await FirebaseFunctions.instance.httpsCallable(name).call<Map<String, dynamic>>(data);
    if (context.mounted) SnackbarHelper.showSuccess(context, done);
  } on FirebaseFunctionsException catch (e) {
    debugPrint('$name: ${e.code} ${e.details}');
    final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
    if (context.mounted) SnackbarHelper.showError(context, sellerWalletRefusal(e.code, reason));
  } catch (e) {
    debugPrint('$name: $e');
    if (context.mounted) SnackbarHelper.showError(context, sellerWalletRefusal('unknown', null));
  }
}

Future<String?> _askReason(BuildContext context, String title, String action) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Reason (shown to the seller)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  final reason = c.text.trim();
  c.dispose();
  return ok == true ? reason : null;
}

/// Shop name + whether a bank/UPI change is waiting, read fresh.
///
/// `withdrawal`, when given, shows THAT withdrawal's own resolved destination
/// (ADMR-78: full/legacyVerified/legacyUnverified/missing — never a live read
/// standing in unchecked for a historical one) instead of the seller's
/// current payout details — used for the "To pay" list, where the preview
/// must always match what `_markPaid`'s own dialog will show for the same row.
class _SellerHeader extends StatelessWidget {
  const _SellerHeader(this.sellerId, {this.showDestination = false, this.withdrawal});
  final String sellerId;
  final bool showDestination;
  final Map<String, dynamic>? withdrawal;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        _db.collection('sellers').doc(sellerId).get(),
        _db.collection('seller_wallets').doc(sellerId).get(),
      ]),
      builder: (context, snap) {
        final seller = snap.data?[0].data();
        final pending = snap.data?[1].data()?['payoutChangePending'];
        final name = (seller?['shopName'] ?? seller?['businessName'] ?? seller?['name'] ?? sellerId).toString();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (showDestination) ...[
            const SizedBox(height: 4),
            if (withdrawal != null)
              _WithdrawalDestinationText(sellerId: sellerId, withdrawal: withdrawal!)
            else
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _db.collection('seller_payout_details').doc(sellerId).get(),
                builder: (context, dsnap) =>
                    SelectableText(sellerDestinationFull(dsnap.data?.data()), style: const TextStyle(fontSize: 12)),
              ),
          ],
          if (pending is String && pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Bank/UPI change waiting for review — paying is blocked',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
            ),
        ]);
      },
    );
  }
}

/// Resolves and shows one withdrawal's own destination (ADMR-78) — a live
/// seller_payout_details read is only ever fetched, and only ever shown, for
/// a legacy request (no destinationFull) as a cross-check against its own
/// frozen masked destination, never as a stand-in for it.
class _WithdrawalDestinationText extends StatelessWidget {
  const _WithdrawalDestinationText({required this.sellerId, required this.withdrawal});
  final String sellerId;
  final Map<String, dynamic> withdrawal;

  @override
  Widget build(BuildContext context) {
    if (withdrawal['destinationFull'] != null) {
      final r = resolveSellerWithdrawalDestination(withdrawal);
      return SelectableText(sellerPayoutDestinationText(r), style: const TextStyle(fontSize: 12));
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _db.collection('seller_payout_details').doc(sellerId).get(),
      builder: (context, dsnap) {
        final r = resolveSellerWithdrawalDestination(withdrawal, liveDetails: dsnap.data?.data());
        return SelectableText(sellerPayoutDestinationText(r), style: const TextStyle(fontSize: 12));
      },
    );
  }
}

class SellerWithdrawalsTab extends StatefulWidget {
  const SellerWithdrawalsTab({super.key});
  @override
  State<SellerWithdrawalsTab> createState() => _SellerWithdrawalsTabState();
}

class _SellerWithdrawalsTabState extends State<SellerWithdrawalsTab> {
  String _status = 'requested';

  Future<void> _markPaid(String id, Map<String, dynamic> w) async {
    // The destination frozen on this withdrawal at request time (ADMR-77) —
    // for a legacy request (no destinationFull) this cross-checks a live
    // seller_payout_details read against the frozen masked destination
    // (ADMR-78) rather than ever trusting live data for a historical request.
    final sellerId = (w['sellerId'] ?? '').toString();
    Map<String, dynamic>? live;
    if (w['destinationFull'] == null) {
      live = (await _db.collection('seller_payout_details').doc(sellerId).get()).data();
    }
    final resolution = resolveSellerWithdrawalDestination(w, liveDetails: live);
    if (!mounted) return;
    if (!resolution.payable) {
      SnackbarHelper.showError(context, sellerPayoutDestinationText(resolution));
      return;
    }
    var method = resolution.method == 'upi' ? 'upi' : 'bank';
    final ref = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Mark withdrawal as paid'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Send ${AgFormat.rupees(_paise(w['amountPaise']))} to:'),
            const SizedBox(height: 4),
            SelectableText(sellerPayoutDestinationText(resolution), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bank', label: Text('Bank')),
                ButtonSegment(value: 'upi', label: Text('UPI'))
              ],
              selected: {method},
              onSelectionChanged: (s) => setD(() => method = s.first),
            ),
            TextField(
              controller: ref,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'UTR / payment reference', helperText: 'Required — shown to the seller'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark paid')),
          ],
        ),
      ),
    );
    final reference = ref.text.trim();
    ref.dispose();
    if (confirmed != true || !mounted) return;
    final error = paymentReferenceError(reference);
    if (error != null) {
      SnackbarHelper.showError(context, error);
      return;
    }
    await _call(context, 'markSellerWithdrawalPaid', {'withdrawalId': id, 'reference': reference, 'method': method},
        'Withdrawal marked as paid');
  }

  Future<void> _reject(String id) async {
    final reason = await _askReason(context, 'Reject withdrawal', 'Reject');
    if (reason == null || !mounted) return;
    await _call(context, 'rejectSellerWithdrawal', {'withdrawalId': id, 'reason': reason},
        'Withdrawal rejected — the amount is back in the seller\'s balance');
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'requested', label: Text('To pay')),
            ButtonSegment(value: 'paid', label: Text('Paid')),
            ButtonSegment(value: 'rejected', label: Text('Rejected')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('seller_withdrawals').where('status', isEqualTo: _status).limit(300).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              debugPrint('Seller withdrawals load failed: ${snap.error}');
              return _message("Couldn't load withdrawals. Check your connection and try again.");
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs.toList()
              ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
                  .compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
            if (docs.isEmpty) {
              return _message(switch (_status) {
                'requested' => 'No withdrawals waiting. Sellers request them from Payments in the seller app.',
                'paid' => 'No paid withdrawals yet.',
                _ => 'No rejected withdrawals.',
              });
            }
            final total = docs.fold<double>(0, (a, d) => a + _paise(d.data()['amountPaise']));
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${docs.length} ${docs.length == 1 ? 'withdrawal' : 'withdrawals'} · ${AgFormat.rupees(total)}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final d in docs) _tile(d.id, d.data()),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _tile(String id, Map<String, dynamic> w) {
    final orders = (w['orderNumbers'] as List?)?.whereType<String>().where((s) => s.isNotEmpty).toList() ?? const [];
    final created = (w['createdAt'] as Timestamp?)?.toDate();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _SellerHeader((w['sellerId'] ?? '').toString(),
                showDestination: _status == 'requested',
                withdrawal: _status == 'requested' ? w : null)),
            Text(AgFormat.rupees(_paise(w['amountPaise'])), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(
            '${w['payoutCount'] ?? orders.length} ${w['payoutCount'] == 1 ? 'order' : 'orders'}'
            '${orders.isEmpty ? '' : ' · ${orders.take(6).join(', ')}${orders.length > 6 ? '…' : ''}'}'
            '${created == null ? '' : ' · requested ${AgFormat.date(created)}'}',
            style: const TextStyle(fontSize: 12),
          ),
          if (_status == 'requested')
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => _reject(id), child: const Text('Reject')),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _markPaid(id, w), child: const Text('Mark paid')),
            ])
          else if (_status == 'paid')
            Text('Ref ${w['paymentReference'] ?? ''} · ${w['payoutMethod'] ?? ''}',
                style: const TextStyle(fontSize: 12))
          else
            Text('Reason: ${w['rejectionReason'] ?? ''}', style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class SellerPayoutChangesTab extends StatelessWidget {
  const SellerPayoutChangesTab({super.key});

  Future<void> _review(BuildContext context, String id, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason(context, 'Reject change', 'Reject');
      if (reason == null) return;
    }
    if (!context.mounted) return;
    await _call(
        context,
        'reviewSellerPayoutChange',
        {'requestId': id, 'approve': approve, if (reason != null) 'reason': reason},
        approve ? 'Approved — payouts now go to the new details' : 'Rejected');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          _db.collection('seller_payout_change_requests').where('status', isEqualTo: 'pending').limit(200).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Seller payout changes load failed: ${snap.error}');
          return _message("Couldn't load requests. Check your connection and try again.");
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _message('No bank/UPI changes waiting.');
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
            'Check each change (e.g. the account holder matches the seller\'s KYC) before approving — '
            'approved details receive the seller\'s money.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final d in docs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SellerHeader((d.data()['sellerId'] ?? '').toString(), showDestination: true),
                  const Divider(),
                  const Text('New details', style: TextStyle(fontWeight: FontWeight.w700)),
                  SelectableText(sellerDestinationFull(d.data())),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => _review(context, d.id, false), child: const Text('Reject')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => _review(context, d.id, true), child: const Text('Approve')),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

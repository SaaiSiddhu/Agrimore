import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/application_rules.dart';
import 'payments_screen.dart' show payoutAccountLine;

/// SELLER-WALLET-1 (owner 2026-09-24): the seller's wallet on Payments.
///
/// The balance is the server's — `sellerWalletSummary` adds up the pending
/// seller_payouts rows (one per delivered order, after commission). A
/// withdrawal asks AgriMore to pay all of it to the bank/UPI on file; the
/// admin pays and records the reference. Bank/UPI changes are requested
/// here and verified by an admin before any money goes to them
/// (functions/src/seller/sellerWallet.ts).

@immutable
class WalletSummary {
  const WalletSummary({
    required this.available,
    required this.held,
    required this.minimum,
    required this.holdDays,
    required this.hasDestination,
    this.openWithdrawalId,
    this.payoutChangePendingId,
  });

  factory WalletSummary.fromMap(Map<String, dynamic> m) {
    double rupees(Object? paise) => ((paise as num?) ?? 0) / 100;
    return WalletSummary(
      available: rupees(m['availablePaise']),
      held: rupees(m['heldPaise']),
      minimum: rupees(m['minWithdrawalPaise']),
      holdDays: (m['holdDays'] as num?)?.toInt() ?? 0,
      hasDestination: m['hasDestination'] == true,
      openWithdrawalId: m['openWithdrawalId'] as String?,
      payoutChangePendingId: m['payoutChangePendingId'] as String?,
    );
  }

  final double available;
  final double held;
  final double minimum;
  final int holdDays;
  final bool hasDestination;
  final String? openWithdrawalId;
  final String? payoutChangePendingId;

  /// Why Withdraw is not offered, or null when it is.
  WalletBlock? get block {
    if (payoutChangePendingId != null) return WalletBlock.changePending;
    if (openWithdrawalId != null) return WalletBlock.open;
    if (!hasDestination) return WalletBlock.noAccount;
    if (available <= 0) return WalletBlock.nothing;
    if (available < minimum) return WalletBlock.belowMinimum;
    return null;
  }
}

enum WalletBlock { changePending, open, noAccount, nothing, belowMinimum }

@immutable
class SellerWithdrawal {
  const SellerWithdrawal({
    required this.id,
    required this.amount,
    required this.status,
    required this.orderCount,
    this.destination = const {},
    this.createdAt,
    this.paidAt,
    this.reference,
    this.reason,
  });

  factory SellerWithdrawal.fromDoc(String id, Map<String, dynamic> d) {
    DateTime? t(Object? v) => v is Timestamp ? v.toDate() : null;
    return SellerWithdrawal(
      id: id,
      amount: ((d['amountPaise'] as num?) ?? 0) / 100,
      status: (d['status'] ?? 'requested').toString(),
      orderCount: (d['payoutCount'] as num?)?.toInt() ?? 0,
      destination: Map<String, dynamic>.from((d['paidTo'] ?? d['destination'] ?? const {}) as Map),
      createdAt: t(d['createdAt']),
      paidAt: t(d['paidAt']),
      reference: d['paymentReference'] as String?,
      reason: d['rejectionReason'] as String?,
    );
  }

  final String id;
  final double amount;
  final String status;
  final int orderCount;
  final Map<String, dynamic> destination;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? reference;
  final String? reason;
}

@immutable
class PayoutChange {
  const PayoutChange({required this.id, required this.details});
  final String id;
  final Map<String, dynamic> details;
}

/// A refusal from the wallet callables, by the server's reason code.
class WalletException implements Exception {
  const WalletException(this.reason);
  final String reason;
}

/// Everything the wallet reads and does; the Firebase one below, fakes in tests.
abstract class WalletSource {
  Future<WalletSummary> summary();
  Stream<List<SellerWithdrawal>> withdrawals();
  Stream<PayoutChange?> pendingChange();
  Future<void> withdraw(String requestId);
  Future<void> cancelWithdrawal(String id);
  Future<void> requestChange(Map<String, dynamic> details);
  Future<void> cancelChange(String id);
}

class FirebaseWalletSource implements WalletSource {
  FirebaseWalletSource(this.uid);
  final String uid;
  static const int _historyLimit = 20;

  FirebaseFunctions get _fn => FirebaseFunctions.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final r = await _fn.httpsCallable(name).call<dynamic>(data);
      return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const {};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('$name failed: ${e.code} ${e.message}');
      final details = e.details;
      throw WalletException(details is Map && details['reason'] is String ? details['reason'] as String : e.code);
    }
  }

  @override
  Future<WalletSummary> summary() async => WalletSummary.fromMap(await _call('sellerWalletSummary'));

  @override
  Stream<List<SellerWithdrawal>> withdrawals() => _db
      .collection('seller_withdrawals')
      .where('sellerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(_historyLimit)
      .snapshots()
      .map((s) => [for (final d in s.docs) SellerWithdrawal.fromDoc(d.id, d.data())]);

  @override
  Stream<PayoutChange?> pendingChange() => _db
      .collection('seller_payout_change_requests')
      .where('sellerId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : PayoutChange(id: s.docs.first.id, details: s.docs.first.data()));

  @override
  Future<void> withdraw(String requestId) => _call('requestSellerWithdrawal', {'requestId': requestId});

  @override
  Future<void> cancelWithdrawal(String id) => _call('cancelSellerWithdrawal', {'withdrawalId': id});

  @override
  Future<void> requestChange(Map<String, dynamic> details) => _call('requestSellerPayoutChange', details);

  @override
  Future<void> cancelChange(String id) => _call('cancelSellerPayoutChange', {'requestId': id});
}

/// A fresh id per tap, so a retried call cannot create a second withdrawal.
String newWalletRequestId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

/// "Example Bank · ••••4821" or "UPI · ka•••@okbank" from a withdrawal's
/// destination (which only ever holds the last four digits).
String destinationLine(AppLocalizations l10n, Map<String, dynamic> d) => d['method'] == 'upi'
    ? l10n.payoutAccountUpi(SellerFormat.maskUpi((d['upiId'] ?? '').toString()))
    : l10n.payoutAccountBank((d['bankName'] ?? '').toString(), SellerFormat.maskAccount((d['accountLast4'] ?? '').toString()));

Widget withdrawalBadge(AppLocalizations l10n, String status) => switch (status) {
      'paid' => SellerStatusBadge(label: l10n.withdrawalPaid, tone: SellerTone.success, icon: SellerIcons.success),
      'rejected' => SellerStatusBadge(label: l10n.withdrawalRejected, tone: SellerTone.danger, icon: SellerIcons.error),
      'cancelled' => SellerStatusBadge(label: l10n.withdrawalCancelled, tone: SellerTone.neutral),
      _ => SellerStatusBadge(label: l10n.withdrawalRequested, tone: SellerTone.warning, icon: SellerIcons.pending),
    };

/// The wallet section of Payments: balance + Withdraw, the open withdrawal,
/// the payout account (add / change / pending review) and past withdrawals.
class WalletSection extends StatefulWidget {
  const WalletSection({super.key, required this.source, this.payoutDetails});
  final WalletSource source;
  final Map<String, dynamic>? payoutDetails;

  @override
  State<WalletSection> createState() => _WalletSectionState();
}

class _WalletSectionState extends State<WalletSection> {
  late Future<WalletSummary> _summary = widget.source.summary();
  StreamSubscription<List<SellerWithdrawal>>? _sub;
  StreamSubscription<PayoutChange?>? _changeSub;
  PayoutChange? _change;
  List<SellerWithdrawal> _history = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Listened to once (a Firestore snapshot stream allows one listener). A
    // withdrawal paid or rejected by AgriMore changes the balance too.
    var first = true;
    _sub = widget.source.withdrawals().listen((list) {
      if (!mounted) return;
      setState(() => _history = list);
      if (first) {
        first = false;
      } else {
        _reload();
      }
    }, onError: (Object e) => debugPrint('Withdrawals failed: $e'));
    _changeSub = widget.source.pendingChange().listen((c) {
      if (!mounted) return;
      final decided = _change != null && c == null;
      setState(() => _change = c);
      // Approved or rejected by AgriMore: the balance card's block changes.
      if (decided) _reload();
    }, onError: (Object e) => debugPrint('Payout change failed: $e'));
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final next = widget.source.summary();
    setState(() {
      _summary = next;
    });
  }

  String _errorText(AppLocalizations l10n, String reason) => switch (reason) {
        'withdrawal_open' => l10n.walletErrOpen,
        'payout_change_pending' => l10n.walletChangePendingBlock,
        'no_destination' => l10n.walletNeedAccount,
        'nothing_to_withdraw' => l10n.walletNothing,
        'already_pending' => l10n.payoutFormPending,
        _ => l10n.walletErrFailed,
      };

  Future<void> _run(Future<void> Function() action, String done) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) SellerToast.show(context, done, tone: SellerToastTone.success);
    } on WalletException catch (e) {
      if (mounted) SellerToast.show(context, _errorText(l10n, e.reason), tone: SellerToastTone.danger);
    } catch (e) {
      debugPrint('Wallet action failed: $e');
      if (mounted) SellerToast.show(context, l10n.walletErrFailed, tone: SellerToastTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
      _reload();
    }
  }

  Future<void> _withdraw(WalletSummary s) async {
    final l10n = AppLocalizations.of(context);
    final details = widget.payoutDetails;
    final amount = SellerFormat.money(s.available);
    final ok = await sellerConfirm(
      context,
      icon: SellerIcons.bank,
      title: l10n.walletConfirmTitle(amount),
      message: l10n.walletConfirmBody(details == null ? '' : payoutAccountLine(l10n, details)),
      confirmLabel: l10n.walletWithdrawCta,
    );
    if (!ok || !mounted) return;
    final id = newWalletRequestId();
    await _run(() => widget.source.withdraw(id), l10n.walletRequested);
  }

  Future<void> _cancel(SellerWithdrawal w) async {
    final l10n = AppLocalizations.of(context);
    final ok = await sellerConfirm(
      context,
      title: l10n.walletCancelTitle,
      message: l10n.walletCancelBody,
      confirmLabel: l10n.walletCancel,
      cancelLabel: l10n.walletKeep,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() => widget.source.cancelWithdrawal(w.id), l10n.walletCancelled);
  }

  Future<void> _openForm() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PayoutAccountScreen(source: widget.source, changing: widget.payoutDetails != null),
    ));
    if (sent == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = _history;
    final open = history.where((w) => w.status == 'requested').firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FutureBuilder<WalletSummary>(
        future: _summary,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Wallet summary failed: ${snap.error}');
            return SellerBanner(tone: SellerTone.danger, message: l10n.walletLoadFailed, actionLabel: l10n.dsTryAgain, onAction: _reload);
          }
          final s = snap.data;
          if (s == null) return SellerLoadingView(label: l10n.dsLoading);
          return _BalanceCard(summary: s, busy: _busy, onWithdraw: () => _withdraw(s));
        },
      ),
      if (open != null) ...[
        const SizedBox(height: SellerSpace.s12),
        _OpenWithdrawalCard(withdrawal: open, busy: _busy, onCancel: () => _cancel(open)),
      ],
      const SizedBox(height: SellerSpace.s16),
      _AccountCard(
        details: widget.payoutDetails,
        pending: _change,
        busy: _busy,
        onEdit: _openForm,
        onCancelChange: (c) => _run(() => widget.source.cancelChange(c.id), l10n.payoutChangeCancelled),
      ),
      if (history.isNotEmpty) ...[
        const SizedBox(height: SellerSpace.section),
        SellerSectionHeader(title: l10n.withdrawalsTitle),
        SellerMenuGroup(children: [for (final w in history) _WithdrawalRow(withdrawal: w)]),
      ],
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.busy, required this.onWithdraw});
  final WalletSummary summary;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final s = summary;
    final block = s.block;
    final String? note = switch (block) {
      WalletBlock.changePending => l10n.walletChangePendingBlock,
      WalletBlock.open => null,
      WalletBlock.noAccount => l10n.walletNeedAccount,
      WalletBlock.nothing => l10n.walletNothing,
      WalletBlock.belowMinimum => l10n.walletMinimum(SellerFormat.money(s.minimum)),
      null => null,
    };
    return SellerCard(
      tone: SellerCardTone.mint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SellerIconTile(icon: SellerIcons.wallet, circle: true),
          const SizedBox(width: SellerSpace.s12),
          Expanded(child: Text(l10n.walletTitle, style: text.labelLarge!.copyWith(color: c.textPrimary))),
        ]),
        const SizedBox(height: SellerSpace.s12),
        Text(SellerFormat.money(s.available), style: text.displayLarge!.tabular),
        const SizedBox(height: SellerSpace.s4),
        if (block == null) Text(l10n.walletAvailableHelp, style: text.bodyMedium!.copyWith(color: c.textPrimary)),
        if (s.held > 0) ...[
          const SizedBox(height: SellerSpace.s4),
          Text(l10n.walletHeld(SellerFormat.money(s.held), s.holdDays), style: text.bodyMedium),
        ],
        if (note != null) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(tone: block == WalletBlock.changePending ? SellerTone.warning : SellerTone.info, message: note),
        ],
        if (block != WalletBlock.open) ...[
          const SizedBox(height: SellerSpace.s16),
          SellerButton(
            label: block == null ? '${l10n.walletWithdrawCta} ${SellerFormat.money(s.available)}' : l10n.walletWithdrawCta,
            icon: SellerIcons.bank,
            loading: busy,
            onPressed: block == null && !busy ? onWithdraw : null,
          ),
        ],
      ]),
    );
  }
}

class _OpenWithdrawalCard extends StatelessWidget {
  const _OpenWithdrawalCard({required this.withdrawal, required this.busy, required this.onCancel});
  final SellerWithdrawal withdrawal;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final w = withdrawal;
    return SellerCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SellerIconTile(icon: SellerIcons.pending, tone: SellerTone.warning),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.walletOpenTitle, style: text.titleSmall),
              Text(l10n.walletOpenBody(SellerFormat.money(w.amount), destinationLine(l10n, w.destination)), style: text.bodyMedium!.tabular),
              if (w.createdAt != null) Text(l10n.walletOpenWaiting(SellerFormat.date(w.createdAt!)), style: text.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: SellerSpace.s8),
        Align(
          alignment: Alignment.centerRight,
          child: SellerButton.tertiary(label: l10n.walletCancel, onPressed: busy ? null : onCancel),
        ),
      ]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.details, required this.pending, required this.busy, required this.onEdit, required this.onCancelChange});
  final Map<String, dynamic>? details;
  final PayoutChange? pending;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<PayoutChange> onCancelChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final d = details;
    final p = pending;
    return SellerCard(
      tone: d == null && p == null ? SellerCardTone.sunken : SellerCardTone.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MergeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SellerIconTile(icon: SellerIcons.bank, tone: d == null ? SellerTone.warning : SellerTone.brand),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d == null ? l10n.payoutAccountMissing : l10n.payoutAccountTitle, style: text.titleSmall),
                if (d != null) ...[
                  Text(payoutAccountLine(l10n, d), style: text.bodyMedium!.copyWith(color: c.textPrimary).tabular),
                  Text(l10n.payoutAccountOnFile, style: text.bodyMedium),
                ],
              ]),
            ),
          ]),
        ),
        // Below the text, so no label is ever squeezed (large text, long names).
        if (p == null && d == null) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerButton.secondary(label: l10n.payoutAccountAdd, icon: SellerIcons.add, onPressed: busy ? null : onEdit),
        ] else if (p == null)
          Align(
            alignment: Alignment.centerRight,
            child: SellerButton.tertiary(label: l10n.payoutAccountChange, onPressed: busy ? null : onEdit),
          ),
        if (p != null) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerBanner(
            tone: SellerTone.warning,
            icon: SellerIcons.pending,
            title: l10n.payoutChangePendingTitle,
            message: l10n.payoutChangePendingBody(payoutAccountLine(l10n, p.details)),
            actionLabel: l10n.payoutChangeCancel,
            onAction: busy ? null : () => onCancelChange(p),
          ),
        ],
      ]),
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow({required this.withdrawal});
  final SellerWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final w = withdrawal;
    final when = w.paidAt ?? w.createdAt;
    final parts = [
      if (when != null) destinationLine(l10n, w.destination),
      l10n.withdrawalOrders(w.orderCount),
      if (w.status == 'paid' && w.reference != null) l10n.withdrawalRef(w.reference!),
      if (w.status == 'rejected' && w.reason != null) l10n.withdrawalReason(w.reason!),
    ];
    return SellerListRow(
      icon: SellerIcons.bank,
      title: when == null ? destinationLine(l10n, w.destination) : SellerFormat.date(when),
      subtitle: parts.join(' · '),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(SellerFormat.money(w.amount), style: text.titleSmall!.tabular),
        const SizedBox(height: SellerSpace.s4),
        withdrawalBadge(l10n, w.status),
      ]),
    );
  }
}

/// Add or change the bank account / UPI ID (board 16-03 step 4 fields). Sent
/// for an admin to verify; nothing is paid to it until then.
class PayoutAccountScreen extends StatefulWidget {
  const PayoutAccountScreen({super.key, required this.source, this.changing = false});
  final WalletSource source;
  final bool changing;

  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  static const int _ifscLength = 11;
  static const int _accountMaxLength = 18;

  final _form = GlobalKey<FormState>();
  String _method = 'bank';
  final _holder = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _accountConfirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  bool get _dirty => [_holder, _bank, _account, _accountConfirm, _ifsc, _upi].any((c) => c.text.isNotEmpty);

  @override
  void dispose() {
    for (final c in [_holder, _bank, _account, _accountConfirm, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) {
      SellerFormScope.maybeOf(_form.currentContext!)?.focusFirstInvalid();
      return;
    }
    final details = <String, dynamic>{'payoutMethod': _method};
    if (_method == 'bank') {
      details.addAll({
        'accountHolder': _holder.text.trim(),
        'bankName': _bank.text.trim(),
        'accountNumber': _account.text.trim(),
        'ifsc': _ifsc.text.trim().toUpperCase(),
      });
    } else {
      details.addAll({'upiId': _upi.text.trim(), if (_holder.text.trim().isNotEmpty) 'accountHolder': _holder.text.trim()});
    }
    setState(() => _busy = true);
    try {
      await widget.source.requestChange(details);
      if (!mounted) return;
      setState(() => _sent = true);
      SellerToast.show(context, l10n.payoutFormSent, tone: SellerToastTone.success);
      Navigator.of(context).pop(true);
    } on WalletException catch (e) {
      if (mounted) {
        SellerToast.show(context, e.reason == 'already_pending' ? l10n.payoutFormPending : l10n.payoutFormFailed, tone: SellerToastTone.danger);
      }
    } catch (e) {
      debugPrint('Payout change failed: $e');
      if (mounted) SellerToast.show(context, l10n.payoutFormFailed, tone: SellerToastTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? required(String v) => ApplicationRules.text(v) ? null : l10n.errRequired;
    const gap = SizedBox(height: SellerSpace.s16);
    return SellerDiscardGuard(
      hasChanges: _dirty && !_busy && !_sent,
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: widget.changing ? l10n.payoutFormTitleChange : l10n.payoutFormTitleAdd),
        body: Form(
          key: _form,
          child: SellerFormScope(
            child: SellerPage(
              footer: SellerButton(label: l10n.payoutFormSubmit, loadingLabel: l10n.payoutFormSending, loading: _busy, onPressed: _busy ? null : _submit),
              children: [
                SellerBanner(tone: SellerTone.info, icon: SellerIcons.info, message: l10n.payoutFormIntro),
                const SizedBox(height: SellerSpace.s24),
                SellerSegmented<String>(
                  semanticLabel: l10n.stepPayout,
                  segments: [SellerSegment('bank', l10n.payoutBank, icon: SellerIcons.bank), SellerSegment('upi', l10n.payoutUpi, icon: SellerIcons.upi)],
                  selected: _method,
                  onChanged: (v) => setState(() => _method = v),
                ),
                const SizedBox(height: SellerSpace.s24),
                if (_method == 'bank') ...[
                  SellerTextField(
                      label: l10n.fieldAccountHolder,
                      required: true,
                      controller: _holder,
                      textCapitalization: TextCapitalization.words,
                      validator: required,
                      onChanged: (_) => setState(() {})),
                  gap,
                  SellerTextField(
                      label: l10n.fieldBankName,
                      required: true,
                      controller: _bank,
                      prefixIcon: SellerIcons.bank,
                      textCapitalization: TextCapitalization.words,
                      validator: required,
                      onChanged: (_) => setState(() {})),
                  gap,
                  SellerTextField(
                    label: l10n.fieldAccountNumber,
                    required: true,
                    controller: _account,
                    obscure: true,
                    tabular: true,
                    keyboardType: TextInputType.number,
                    maxLength: _accountMaxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => ApplicationRules.account.hasMatch(v) ? null : l10n.errAccount,
                    onChanged: (_) => setState(() {}),
                  ),
                  gap,
                  SellerTextField(
                    label: l10n.fieldAccountNumberConfirm,
                    required: true,
                    controller: _accountConfirm,
                    tabular: true,
                    keyboardType: TextInputType.number,
                    maxLength: _accountMaxLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v == _account.text ? null : l10n.accountMismatch,
                  ),
                  gap,
                  SellerTextField(
                    label: l10n.fieldIfsc,
                    required: true,
                    controller: _ifsc,
                    tabular: true,
                    maxLength: _ifscLength,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
                    ],
                    validator: (v) => ApplicationRules.ifsc.hasMatch(v) ? null : l10n.errIfsc,
                  ),
                ] else ...[
                  SellerTextField(
                    label: l10n.fieldUpiId,
                    required: true,
                    controller: _upi,
                    prefixIcon: SellerIcons.upi,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => ApplicationRules.upi.hasMatch(v.trim()) ? null : l10n.errUpi,
                    onChanged: (_) => setState(() {}),
                  ),
                  gap,
                  SellerTextField(label: l10n.fieldAccountHolder, optional: true, controller: _holder, textCapitalization: TextCapitalization.words),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

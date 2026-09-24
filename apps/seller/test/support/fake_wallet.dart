import 'dart:async';

import 'package:seller/screens/payments/wallet.dart';

/// In-memory [WalletSource] for tests, renders and the device tour — TEST
/// data only, never Firebase.
class FakeWalletSource implements WalletSource {
  FakeWalletSource({
    this.balance = const WalletSummary(available: 3840, held: 0, minimum: 100, holdDays: 0, hasDestination: true),
    List<SellerWithdrawal> history = const [],
    this.change,
    this.refuseWith,
  }) : _history = List.of(history);

  WalletSummary balance;
  PayoutChange? change;

  /// When set, every action throws this refusal reason.
  String? refuseWith;

  final List<SellerWithdrawal> _history;
  final _historyOut = StreamController<List<SellerWithdrawal>>.broadcast();
  final _changeOut = StreamController<PayoutChange?>.broadcast();
  final withdrawn = <String>[];
  final cancelled = <String>[];
  final requested = <Map<String, dynamic>>[];

  void _refuse() {
    if (refuseWith != null) throw WalletException(refuseWith!);
  }

  @override
  Future<WalletSummary> summary() async => balance;

  @override
  Stream<List<SellerWithdrawal>> withdrawals() async* {
    yield List.of(_history);
    yield* _historyOut.stream;
  }

  @override
  Stream<PayoutChange?> pendingChange() async* {
    yield change;
    yield* _changeOut.stream;
  }

  @override
  Future<void> withdraw(String requestId) async {
    _refuse();
    withdrawn.add(requestId);
    _history.insert(0, SellerWithdrawal(id: 'w-$requestId', amount: balance.available, status: 'requested', orderCount: 3,
        destination: const {'method': 'bank', 'bankName': 'Example Bank', 'accountLast4': '4821'}, createdAt: DateTime(2026, 9, 24)));
    balance = WalletSummary(available: 0, held: balance.held, minimum: balance.minimum, holdDays: balance.holdDays,
        hasDestination: true, openWithdrawalId: 'w-$requestId');
    _historyOut.add(List.of(_history));
  }

  @override
  Future<void> cancelWithdrawal(String id) async {
    _refuse();
    cancelled.add(id);
  }

  @override
  Future<void> requestChange(Map<String, dynamic> details) async {
    _refuse();
    requested.add(details);
  }

  @override
  Future<void> cancelChange(String id) async {
    _refuse();
    cancelled.add(id);
    change = null;
    _changeOut.add(null);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'checkout_request_store.dart';
import 'checkout_request_store_stub.dart'
    if (dart.library.io) 'checkout_request_store_file.dart' as storage;
import 'payment_checkout_order.dart';

bool _id(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
bool _integer(Object? value) =>
    value is num &&
    value.isFinite &&
    value.abs() <= 9007199254740991 &&
    value == value.truncateToDouble();
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

class PendingWalletTopup {
  PendingWalletTopup._(Map<String, dynamic> value) : _json = jsonEncode(value);
  final String _json;
  Map<String, dynamic> toMap() =>
      (jsonDecode(_json) as Map).cast<String, dynamic>();
  String get ownerId => toMap()['ownerId'] as String;
  String get requestId => toMap()['requestId'] as String;
  String get stage => toMap()['stage'] as String;
  int get amountPaise => toMap()['amountPaise'] as int;
  double get amount => amountPaise / 100;
  Map<String, dynamic>? get gateway =>
      (toMap()['gateway'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get proof =>
      (toMap()['proof'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get confirmation =>
      (toMap()['confirmation'] as Map?)?.cast<String, dynamic>();
}

/// Native foreground wallet journal; server top-up anchors own financial truth.
/// A new amount never replaces an attempted payment, even after a lost callback.
class WalletTopupRecoveryService {
  WalletTopupRecoveryService(
      {CheckoutRequestStore? store,
      FirebaseFunctions? functions,
      String? Function()? currentUserId})
      : _store = store ?? storage.createWalletTopupRequestStore(),
        _functions = functions,
        _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final CheckoutRequestStore _store;
  final FirebaseFunctions? _functions;
  final String? Function() _currentUserId;
  static final _locks = <String, Future<void>>{};

  void _check(String owner) {
    if (_currentUserId() != owner) throw StateError('Top-up session changed.');
  }

  String _owner() {
    final uid = _currentUserId();
    if (uid == null || uid.isEmpty || uid.length > 128) {
      throw StateError('Sign in to continue your top-up.');
    }
    return uid;
  }

  Future<T> _locked<T>(String owner, Future<T> Function() body) async {
    final previous = _locks[owner];
    final release = Completer<void>();
    _locks[owner] = release.future;
    try {
      if (previous != null) await previous;
      _check(owner);
      final value = await body();
      _check(owner);
      return value;
    } finally {
      release.complete();
      if (identical(_locks[owner], release.future)) _locks.remove(owner);
    }
  }

  Map<String, dynamic> _validateConfirmation(Object? value, int amountPaise) {
    if (value is! Map ||
        value['success'] != true ||
        value['amount'] != amountPaise / 100 ||
        value['alreadyCredited'] is! bool ||
        !_integer(value['bonusCoins']) ||
        (value['bonusCoins'] as num) < 0 ||
        !_integer(value['coinsAfter']) ||
        value['balanceAfter'] is! num) {
      throw const FormatException('Top-up confirmation needs review.');
    }
    final balance = value['balanceAfter'] as num;
    if (!balance.isFinite ||
        balance.abs() * 100 > 9007199254740991 ||
        (balance * 100 - (balance * 100).round()).abs() > 1e-7) {
      throw const FormatException('Top-up confirmation needs review.');
    }
    // Store only the server-confirmed money/coin receipt, never extra metadata.
    return {
      for (final key in [
        'success',
        'amount',
        'alreadyCredited',
        'bonusCoins',
        'balanceAfter',
        'coinsAfter'
      ])
        key: value[key]
    };
  }

  Future<PendingWalletTopup?> _read(String owner) async {
    final raw = await _store.read(owner);
    _check(owner);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Top-up recovery needs review.');
    }
    final data = decoded.cast<String, dynamic>();
    if (data['version'] != 1 ||
        data['ownerId'] != owner ||
        data['requestId'] is! String ||
        !RegExp(r'^wt_[a-f0-9]{32}$').hasMatch(data['requestId']) ||
        !['draft', 'awaiting_payment', 'ready', 'completed']
            .contains(data['stage']) ||
        data['amountPaise'] is! int ||
        (data['amountPaise'] as int) < 10000 ||
        (data['amountPaise'] as int) > 9007199254740991) {
      throw const FormatException('Top-up recovery needs review.');
    }
    final gateway = data['gateway'];
    if (gateway != null) {
      if (gateway is! Map) {
        throw const FormatException('Top-up recovery needs review.');
      }
      final order =
          PaymentCheckoutOrder.fromResponse(gateway.cast<String, dynamic>());
      if (order.amountPaise != data['amountPaise'] ||
          order.isTestMode ||
          order.orderId.startsWith('order_test_')) {
        throw const FormatException('Top-up recovery needs review.');
      }
    }
    final proof = data['proof'];
    if (proof != null) {
      if (proof is! Map ||
          !_id(proof['paymentId']) ||
          !_id(proof['orderId']) ||
          (proof['paymentId'] as String).startsWith('pay_test_') ||
          proof['orderId'] != (gateway as Map?)?['orderId'] ||
          (proof['source'] == 'provider_api_recovery'
              ? proof.containsKey('signature')
              : proof['source'] != null ||
                  proof['signature'] is! String ||
                  (proof['signature'] as String).isEmpty ||
                  (proof['signature'] as String).length > 256)) {
        throw const FormatException('Top-up proof needs review.');
      }
    }
    if (data['stage'] == 'draft' && (gateway != null || proof != null) ||
        data['stage'] == 'awaiting_payment' &&
            (gateway == null || proof != null) ||
        ['ready', 'completed'].contains(data['stage']) &&
            (gateway == null || proof == null) ||
        data['stage'] != 'completed' && data['confirmation'] != null) {
      throw const FormatException('Top-up recovery needs review.');
    }
    if (data['stage'] == 'completed') {
      _validateConfirmation(data['confirmation'], data['amountPaise']);
    }
    return PendingWalletTopup._(data);
  }

  Future<PendingWalletTopup> _save(
      String owner, Map<String, dynamic> data) async {
    _check(owner);
    await _store.write(owner, jsonEncode(data));
    _check(owner);
    return PendingWalletTopup._(data);
  }

  Future<PendingWalletTopup> _request(String owner, String requestId) async {
    final value = await _read(owner);
    if (value == null || value.requestId != requestId) {
      throw StateError('Saved top-up is unavailable.');
    }
    return value;
  }

  Future<PendingWalletTopup?> pending() {
    final owner = _owner();
    return _locked(owner, () => _read(owner));
  }

  Future<PendingWalletTopup> prepare(double amount) {
    final owner = _owner();
    if (!amount.isFinite ||
        amount < 100 ||
        amount * 100 > 9007199254740991 ||
        (amount * 100 - (amount * 100).round()).abs() > 1e-7) {
      throw const FormatException('Enter a valid top-up amount.');
    }
    final paise = (amount * 100).round();
    return _locked(owner, () async {
      final existing = await _read(owner);
      if (existing != null) {
        if (existing.amountPaise != paise) {
          throw StateError('Finish the saved top-up first.');
        }
        return existing;
      }
      final random = Random.secure();
      final id =
          'wt_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      return _save(owner, {
        'version': 1,
        'ownerId': owner,
        'requestId': id,
        'amountPaise': paise,
        'stage': 'draft'
      });
    });
  }

  Future<PendingWalletTopup> attachGateway(
          String owner, String requestId, PaymentCheckoutOrder order) =>
      _locked(owner, () async {
        final request = await _request(owner, requestId);
        if (order.amountPaise != request.amountPaise ||
            order.isTestMode ||
            order.orderId.startsWith('order_test_')) {
          throw StateError('Top-up order needs review.');
        }
        final gateway = {
          'success': true,
          'orderId': order.orderId,
          'keyId': order.keyId,
          'amount': order.amountPaise,
          'currency': 'INR',
          'isTestMode': false
        };
        if (request.gateway != null) {
          if (jsonEncode(request.gateway) != jsonEncode(gateway)) {
            throw StateError('Top-up order cannot change.');
          }
          return request;
        }
        if (request.stage != 'draft') {
          throw StateError('Top-up is not a draft.');
        }
        return _save(owner, {
          ...request.toMap(),
          'gateway': gateway,
          'stage': 'awaiting_payment'
        });
      });
  Future<PendingWalletTopup> _record(
      String owner, String requestId, Map<String, dynamic> proof) async {
    final request = await _request(owner, requestId);
    if (request.gateway == null ||
        !_id(proof['paymentId']) ||
        !_id(proof['orderId']) ||
        (proof['paymentId'] as String).startsWith('pay_test_') ||
        proof['orderId'] != request.gateway!['orderId']) {
      throw StateError('Top-up proof needs review.');
    }
    if (request.proof != null) {
      if (request.proof!['paymentId'] != proof['paymentId'] ||
          request.proof!['orderId'] != proof['orderId']) {
        throw StateError('Top-up proof cannot change.');
      }
      // A late SDK callback never replaces already trusted provider-API proof.
      if (request.proof!['source'] == 'provider_api_recovery' ||
          proof['source'] == 'provider_api_recovery') {
        return request;
      }
      if (jsonEncode(request.proof) != jsonEncode(proof)) {
        throw StateError('Top-up proof cannot change.');
      }
      return request;
    }
    if (request.stage != 'awaiting_payment') {
      throw StateError('Top-up order is unavailable.');
    }
    return _save(owner, {...request.toMap(), 'proof': proof, 'stage': 'ready'});
  }

  Future<PendingWalletTopup> recordPayment(String owner, String requestId,
      {required String paymentId,
      required String orderId,
      required String signature}) {
    if (signature.isEmpty || signature.length > 256) {
      throw const FormatException('Top-up proof needs review.');
    }
    return _locked(
        owner,
        () => _record(owner, requestId, {
              'paymentId': paymentId,
              'orderId': orderId,
              'signature': signature
            }));
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final result = await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable(name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 25)))
        .call<Map<String, dynamic>>(data);
    return result.data;
  }

  Future<Map<String, dynamic>> _recover(PendingWalletTopup request) async {
    if (request.gateway == null) {
      throw StateError('Top-up order is unavailable.');
    }
    _check(request.ownerId);
    final data = await _call('recoverWalletTopupPayment', {
      'checkoutOwnerId': request.ownerId,
      'orderId': request.gateway!['orderId']
    });
    _check(request.ownerId);
    if (data['success'] != true ||
        data['verified'] != true ||
        data['outcome'] != 'captured' ||
        data['orderId'] != request.gateway!['orderId'] ||
        data['amountPaise'] != request.amountPaise ||
        data['currency'] != 'INR' ||
        !_id(data['paymentId']) ||
        (data['paymentId'] as String).startsWith('pay_test_')) {
      throw StateError('Top-up outcome needs review.');
    }
    return {
      'source': 'provider_api_recovery',
      'paymentId': data['paymentId'],
      'orderId': data['orderId']
    };
  }

  Future<PendingWalletTopup> recoverPayment(String owner, String requestId) =>
      _locked(owner, () async {
        final request = await _request(owner, requestId);
        if (request.stage == 'completed') return request;
        final proof = await _recover(request);
        return _record(owner, requestId, proof);
      });
  Future<Map<String, dynamic>> confirm(String owner, String requestId) =>
      _locked(owner, () async {
        final request = await _request(owner, requestId);
        if (request.stage == 'completed') return request.confirmation!;
        if (request.stage != 'ready' || request.proof == null) {
          throw StateError('Top-up proof is unavailable.');
        }
        final proof = request.proof!;
        final viaApi = proof['source'] == 'provider_api_recovery';
        if (viaApi) {
          final refreshed = await _recover(request);
          if (refreshed['paymentId'] != proof['paymentId']) {
            throw StateError('Top-up proof needs review.');
          }
        }
        _check(owner);
        final result = await _call('verifyWalletTopup', {
          'checkoutOwnerId': owner,
          'amount': request.amount,
          'paymentId': proof['paymentId'],
          'orderId': proof['orderId'],
          if (viaApi)
            'proofSource': 'provider_api_recovery'
          else
            'signature': proof['signature']
        });
        _check(owner);
        final receipt = _validateConfirmation(result, request.amountPaise);
        await _save(owner, {
          ...request.toMap(),
          'stage': 'completed',
          'confirmation': receipt
        });
        return _copy(receipt);
      });
  Future<void> discardDraft(String owner, String requestId) =>
      _locked(owner, () async {
        if ((await _request(owner, requestId)).stage != 'draft') {
          throw StateError('Attempted top-up cannot be removed.');
        }
        await _store.remove(owner);
        _check(owner);
      });
  Future<void> acknowledge(String owner, String requestId) =>
      _locked(owner, () async {
        if ((await _request(owner, requestId)).stage != 'completed') {
          throw StateError('Top-up is not confirmed.');
        }
        await _store.remove(owner);
        _check(owner);
      });
}

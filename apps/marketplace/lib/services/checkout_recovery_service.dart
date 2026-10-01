import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'checkout_request_store.dart';
import 'checkout_request_store_stub.dart'
    if (dart.library.io) 'checkout_request_store_file.dart' as storage;
import 'payment_checkout_order.dart';

bool _safeId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

void _validateIntent(Map<dynamic, dynamic> value) {
  final items = value['items'];
  if (!['cod', 'razorpay'].contains(value['paymentMethod']) ||
      !['B2C', 'B2B'].contains(value['orderMode']) ||
      items is! List ||
      items.isEmpty ||
      [
        'checkoutOwnerId',
        'checkoutRequestId',
        'razorpayOrderId',
        'razorpayPaymentId',
        'razorpaySignature'
      ].any(value.containsKey)) {
    throw const FormatException('Checkout details are unavailable.');
  }
  for (final item in items) {
    if (item is! Map ||
        item['productId'] is! String ||
        (item['productId'] as String).isEmpty ||
        item['quantity'] is! num) {
      throw const FormatException('Checkout details are unavailable.');
    }
    final quantity = item['quantity'] as num;
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity > 9007199254740991 ||
        quantity != quantity.truncateToDouble()) {
      throw const FormatException('Checkout details are unavailable.');
    }
  }
}

String _canonical(Object? value) {
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

class CheckoutReceipt {
  const CheckoutReceipt._(
      this.orderId, this.orderNumber, this.sellerId, this.total);
  final String orderId;
  final String orderNumber;
  final String sellerId;
  final double total;

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'sellerId': sellerId,
        'total': total,
      };

  static List<CheckoutReceipt> parse(Object? value) {
    if (value is! List || value.isEmpty || value.length > 100) {
      throw const FormatException('Order confirmation is unavailable.');
    }
    final ids = <String>{};
    final receipts = <CheckoutReceipt>[];
    for (final row in value) {
      if (row is! Map ||
          !_safeId(row['orderId']) ||
          row['orderNumber'] is! String ||
          (row['orderNumber'] as String).isEmpty ||
          row['sellerId'] is! String ||
          row['total'] is! num) {
        throw const FormatException('Order confirmation is unavailable.');
      }
      final total = row['total'] as num;
      if (!total.isFinite ||
          total < 0 ||
          total * 100 > 9007199254740991 ||
          !ids.add(row['orderId'] as String)) {
        throw const FormatException('Order confirmation is unavailable.');
      }
      receipts.add(CheckoutReceipt._(
          row['orderId'] as String,
          row['orderNumber'] as String,
          row['sellerId'] as String,
          total.toDouble()));
    }
    return List.unmodifiable(receipts);
  }
}

/// Immutable snapshot: public maps are defensive copies, including nested data.
class PendingCheckoutRequest {
  PendingCheckoutRequest._(Map<String, dynamic> value)
      : _json = jsonEncode(value);
  final String _json;
  Map<String, dynamic> toMap() =>
      (jsonDecode(_json) as Map).cast<String, dynamic>();
  String get ownerId => toMap()['ownerId'] as String;
  String get requestId => toMap()['requestId'] as String;
  String get stage => toMap()['stage'] as String;
  Map<String, dynamic> get intent =>
      (toMap()['intent'] as Map).cast<String, dynamic>();
  Map<String, dynamic>? get gateway =>
      (toMap()['gateway'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get payment =>
      (toMap()['payment'] as Map?)?.cast<String, dynamic>();
  List<CheckoutReceipt> get receipts =>
      CheckoutReceipt.parse(toMap()['orders']);
}

class CheckoutRecoveryService {
  CheckoutRecoveryService(
      {CheckoutRequestStore? store,
      FirebaseFunctions? functions,
      String? Function()? currentUserId})
      : _store = store ?? storage.createCheckoutRequestStore(),
        _functions = functions,
        _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final CheckoutRequestStore _store;
  final FirebaseFunctions? _functions;
  final String? Function() _currentUserId;
  static final _locks = <String, Future<void>>{};

  void _checkOwner(String ownerId) {
    if (_currentUserId() != ownerId) {
      throw StateError('Sign in to the checkout account to continue.');
    }
  }

  Future<T> _locked<T>(String ownerId, Future<T> Function() body) async {
    final previous = _locks[ownerId];
    final release = Completer<void>();
    _locks[ownerId] = release.future;
    try {
      if (previous != null) await previous;
      _checkOwner(ownerId);
      final result = await body();
      _checkOwner(ownerId);
      return result;
    } finally {
      release.complete();
      if (identical(_locks[ownerId], release.future)) _locks.remove(ownerId);
    }
  }

  String _owner() {
    final ownerId = _currentUserId();
    if (ownerId == null || ownerId.isEmpty || ownerId.length > 128) {
      throw StateError('Sign in to continue checkout.');
    }
    return ownerId;
  }

  Future<PendingCheckoutRequest?> _read(String ownerId) async {
    final raw = await _store.read(ownerId);
    _checkOwner(ownerId);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Checkout recovery needs attention.');
    }
    final data = decoded.cast<String, dynamic>();
    final intent = data['intent'];
    if (data['version'] != 1 ||
        data['ownerId'] != ownerId ||
        data['requestId'] is! String ||
        !RegExp(r'^ck_[a-f0-9]{32}$').hasMatch(data['requestId'] as String) ||
        !['draft', 'awaiting_payment', 'ready', 'completed']
            .contains(data['stage']) ||
        intent is! Map ||
        !['cod', 'razorpay'].contains(intent['paymentMethod'])) {
      throw const FormatException('Checkout recovery needs attention.');
    }
    _validateIntent(intent);
    if (data['gateway'] != null) {
      PaymentCheckoutOrder.fromResponse(
          (data['gateway'] as Map).cast<String, dynamic>());
    }
    if (data['payment'] != null) {
      final proof = data['payment'] as Map;
      final viaProvider = proof['source'] == 'provider_api_recovery';
      if (!_safeId(proof['paymentId']) ||
          !_safeId(proof['orderId']) ||
          proof['orderId'] != (data['gateway'] as Map?)?['orderId'] ||
          (viaProvider
              ? proof.containsKey('signature')
              : proof['source'] != null ||
                  proof['signature'] is! String ||
                  (proof['signature'] as String).isEmpty ||
                  (proof['signature'] as String).length > 256)) {
        throw const FormatException('Checkout recovery needs attention.');
      }
    }
    if (data['stage'] == 'completed') CheckoutReceipt.parse(data['orders']);
    final hasGateway = data['gateway'] != null;
    final hasProof = data['payment'] != null;
    final paid = intent['paymentMethod'] != 'cod';
    if (data['stage'] == 'draft' && (hasGateway || hasProof) ||
        data['stage'] == 'awaiting_payment' &&
            (!paid || !hasGateway || hasProof) ||
        ['ready', 'completed'].contains(data['stage']) &&
            paid &&
            (!hasGateway || !hasProof) ||
        !paid && (hasGateway || hasProof)) {
      throw const FormatException('Checkout recovery needs attention.');
    }
    return PendingCheckoutRequest._(data);
  }

  Future<PendingCheckoutRequest> _save(
      String ownerId, Map<String, dynamic> value) async {
    _checkOwner(ownerId);
    await _store.write(ownerId, jsonEncode(value));
    _checkOwner(ownerId);
    return PendingCheckoutRequest._(value);
  }

  Future<PendingCheckoutRequest?> pending() {
    final ownerId = _owner();
    return _locked(ownerId, () => _read(ownerId));
  }

  Future<PendingCheckoutRequest> prepare(Map<String, dynamic> intent) {
    final ownerId = _owner();
    // Copy synchronously: caller mutations while awaiting a lock cannot alter it.
    final frozen = _copy(intent);
    _validateIntent(frozen);
    return _locked(ownerId, () async {
      final existing = await _read(ownerId);
      if (existing != null) {
        if (_canonical(existing.intent) != _canonical(frozen)) {
          throw StateError(
              'Finish the saved checkout before starting another.');
        }
        return existing;
      }
      final random = Random.secure();
      final id = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      return _save(ownerId, {
        'version': 1,
        'ownerId': ownerId,
        'requestId': 'ck_$id',
        'stage': 'draft',
        'intent': frozen
      });
    });
  }

  Future<PendingCheckoutRequest> attachGateway(
          String ownerId, String requestId, PaymentCheckoutOrder order) =>
      _locked(ownerId, () async {
        final request = await _require(ownerId, requestId);
        if (request.intent['paymentMethod'] == 'cod' ||
            request.stage != 'draft') {
          throw StateError('This checkout already has a payment attempt.');
        }
        return _save(ownerId, {
          ...request.toMap(),
          'stage': 'awaiting_payment',
          'gateway': {
            'success': true,
            'orderId': order.orderId,
            'keyId': order.keyId,
            'amount': order.amountPaise,
            'currency': 'INR',
            'isTestMode': order.isTestMode,
          }
        });
      });

  Future<PendingCheckoutRequest> recordPayment(String ownerId, String requestId,
          {required String paymentId,
          required String orderId,
          required String signature}) =>
      _locked(ownerId, () async {
        final request = await _require(ownerId, requestId);
        final proof = {
          'paymentId': paymentId,
          'orderId': orderId,
          'signature': signature
        };
        // A late SDK callback must not change the stable provider proof after
        // recovery or alter the fingerprint of an already confirmed request.
        if (request.payment?['source'] == 'provider_api_recovery' &&
            request.payment?['paymentId'] == paymentId &&
            request.payment?['orderId'] == orderId &&
            signature.isNotEmpty &&
            signature.length <= 256) {
          return request;
        }
        if (request.payment != null &&
            _canonical(request.payment) == _canonical(proof)) {
          return request;
        }
        if (request.stage != 'awaiting_payment' ||
            !_safeId(paymentId) ||
            !_safeId(orderId) ||
            orderId != request.gateway?['orderId'] ||
            signature.isEmpty ||
            signature.length > 256) {
          throw StateError(
              'Payment confirmation does not match the saved checkout.');
        }
        return _save(
            ownerId, {...request.toMap(), 'stage': 'ready', 'payment': proof});
      });

  Future<PendingCheckoutRequest> _require(
      String ownerId, String requestId) async {
    final request = await _read(ownerId);
    if (request == null || request.requestId != requestId) {
      throw StateError('The saved checkout is unavailable.');
    }
    return request;
  }

  /// Lookup only: an uncertain result preserves the original payment attempt.
  /// The descriptor is a retry hint; server-owned verified_payments remains
  /// financial authority, and confirmation rechecks the provider outcome.
  Future<PendingCheckoutRequest> recoverPayment(
          String ownerId, String requestId) =>
      _locked(ownerId, () async {
        final request = await _require(ownerId, requestId);
        if (['ready', 'completed'].contains(request.stage)) return request;
        if (request.stage != 'awaiting_payment') {
          throw StateError('There is no saved payment attempt to check.');
        }
        final proof = await _recoverProvider(request);
        if (proof == null) return request;
        return _save(ownerId, {
          ...request.toMap(),
          'stage': 'ready',
          'payment': proof,
        });
      });

  Future<Map<String, dynamic>?> _recoverProvider(
      PendingCheckoutRequest request) async {
    _checkOwner(request.ownerId);
    final result = await (_functions ?? FirebaseFunctions.instance)
        .httpsCallable('recoverCheckoutPayment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call<Map<String, dynamic>>({
      'checkoutOwnerId': request.ownerId,
      'orderId': request.gateway!['orderId'],
    });
    _checkOwner(request.ownerId);
    final data = result.data;
    if (data['success'] != true ||
        data['orderId'] != request.gateway!['orderId']) {
      throw StateError('Payment outcome could not be confirmed.');
    }
    if (data['verified'] == false && data['outcome'] == 'unconfirmed') {
      return null;
    }
    if (data['verified'] != true ||
        data['outcome'] != 'captured' ||
        !_safeId(data['paymentId']) ||
        data['amountPaise'] != request.gateway!['amount'] ||
        data['currency'] != 'INR' ||
        (request.payment != null &&
            data['paymentId'] != request.payment!['paymentId'])) {
      throw StateError('Payment outcome could not be confirmed.');
    }
    return {
      'source': 'provider_api_recovery',
      'orderId': data['orderId'],
      'paymentId': data['paymentId'],
    };
  }

  Future<List<CheckoutReceipt>> confirm(String ownerId, String requestId) =>
      _locked(ownerId, () async {
        var request = await _require(ownerId, requestId);
        if (request.stage == 'completed') return request.receipts;
        if (request.intent['paymentMethod'] == 'cod' &&
            request.stage == 'draft') {
          request =
              await _save(ownerId, {...request.toMap(), 'stage': 'ready'});
        }
        if (request.stage != 'ready') {
          throw StateError('Payment outcome is not confirmed yet.');
        }
        final functions = _functions ?? FirebaseFunctions.instance;
        final proof = request.payment;
        if (request.intent['paymentMethod'] != 'cod') {
          if (proof?['source'] == 'provider_api_recovery') {
            if (await _recoverProvider(request) == null) {
              throw StateError('Payment could not be confirmed.');
            }
          } else {
            _checkOwner(ownerId);
            final verified = await functions
                .httpsCallable('verifyRazorpayPayment',
                    options: HttpsCallableOptions(
                        timeout: const Duration(seconds: 15)))
                .call<Map<String, dynamic>>(proof);
            _checkOwner(ownerId);
            if (verified.data['verified'] != true) {
              throw StateError('Payment could not be confirmed.');
            }
          }
        }
        _checkOwner(ownerId);
        final result = await functions
            .httpsCallable('createOrder',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 25)))
            .call<Map<String, dynamic>>({
          ...request.intent,
          'checkoutRequestId': requestId,
          'checkoutOwnerId': ownerId,
          if (proof != null) 'razorpayPaymentId': proof['paymentId'],
          if (proof != null) 'razorpayOrderId': proof['orderId'],
          if (proof?['signature'] != null)
            'razorpaySignature': proof!['signature'],
        });
        _checkOwner(ownerId);
        if (result.data['success'] != true) {
          throw StateError('Order could not be confirmed.');
        }
        final receipts = CheckoutReceipt.parse(result.data['orders']);
        await _save(ownerId, {
          ...request.toMap(),
          'stage': 'completed',
          'orders': receipts.map((r) => r.toMap()).toList()
        });
        return receipts;
      });

  Future<void> acknowledge(String ownerId, String requestId) =>
      _locked(ownerId, () async {
        final request = await _require(ownerId, requestId);
        if (request.stage != 'completed') {
          throw StateError('Checkout is not complete.');
        }
        await _store.remove(ownerId);
      });

  Future<void> discardDraft(String ownerId, String requestId) =>
      _locked(ownerId, () async {
        final request = await _require(ownerId, requestId);
        if (request.stage != 'draft') {
          throw StateError('The payment outcome must be checked first.');
        }
        await _store.remove(ownerId);
      });
}

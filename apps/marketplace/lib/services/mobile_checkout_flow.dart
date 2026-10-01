import 'dart:async';
import 'dart:convert';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'checkout_recovery_service.dart';
import 'payment_checkout_order.dart';
import 'native_payment_flight.dart';
import 'razorpay_service.dart';

class MobileCheckoutCustomer {
  const MobileCheckoutCustomer(
      {required this.name, required this.email, required this.phone});
  final String name, email, phone;
}

/// One foreground flow shared by both native checkout screens. Financial
/// authority stays with the server; this class owns persistence and UI handoff.
class MobileCheckoutFlow {
  MobileCheckoutFlow({
    CheckoutRecoveryService? journal,
    RazorpayService? payments,
    String? Function()? currentUserId,
    required void Function() onChanged,
    required void Function(String message) onError,
    required Future<void> Function(
            PendingCheckoutRequest request, List<CheckoutReceipt> receipts)
        onConfirmed,
  })  : _journal =
            journal ?? CheckoutRecoveryService(currentUserId: currentUserId),
        _payments = payments ?? RazorpayService(),
        _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _onChanged = onChanged,
        _onError = onError,
        _onConfirmed = onConfirmed {
    _payments.initialize(
      onSuccess: (paymentId, orderId, signature) {
        final request = _pending;
        if (request == null) return;
        unawaited(_run(request.ownerId, () async {
          _waitingForSdk = false;
          _pending = await _journal.recordPayment(
              request.ownerId, request.requestId,
              paymentId: paymentId,
              orderId: orderId ?? '',
              signature: signature ?? '');
          _checkLive(request.ownerId);
          await _finish(_pending!);
        }));
      },
      onFailure: (_) => _paymentInterrupted(),
      onDismiss: _paymentInterrupted,
    );
  }

  final CheckoutRecoveryService _journal;
  final RazorpayService _payments;
  final String? Function() _currentUserId;
  final void Function() _onChanged;
  final void Function(String) _onError;
  final Future<void> Function(PendingCheckoutRequest, List<CheckoutReceipt>)
      _onConfirmed;
  Future<void> _tail = Future.value();
  PendingCheckoutRequest? _pending;
  String? _heldOwner, _deliveredRequestId;
  bool _busy = false, _waitingForSdk = false, _disposed = false;

  PendingCheckoutRequest? get pending =>
      !_disposed && _pending?.ownerId == _currentUserId() ? _pending : null;
  bool get isBusy => !_disposed && _busy && _heldOwner == _currentUserId();

  void _checkLive(String ownerId) {
    if (_disposed || _currentUserId() != ownerId) {
      throw StateError('Checkout session changed.');
    }
  }

  void _notify() {
    if (!_disposed) _onChanged();
  }

  void _release() {
    if (_heldOwner != null) {
      NativePaymentFlight.release(_heldOwner!, this);
    }
    _heldOwner = null;
    _busy = false;
  }

  Future<void> _run(String ownerId, Future<void> Function() body) async {
    final previous = _tail, release = Completer<void>();
    _tail = release.future;
    try {
      await previous;
      _checkLive(ownerId);
      if (!NativePaymentFlight.acquire(ownerId, this)) {
        throw StateError('Another checkout is in progress.');
      }
      _heldOwner = ownerId;
      _busy = true;
      _notify();
      await body();
    } catch (_) {
      _waitingForSdk = false;
      // Confirmation can durably advance the journal before its reply is
      // lost. Refresh the exposed stage before offering recovery actions.
      if (!_disposed && _currentUserId() == ownerId) {
        try {
          _pending = await _journal.pending();
          _checkLive(ownerId);
        } catch (_) {
          // An unreadable journal stays fail-closed in every command.
        }
      }
      if (!_disposed && _currentUserId() == ownerId) {
        _onError(
            'Checkout needs attention. Check for a saved checkout before paying again.');
      }
    } finally {
      if (!_waitingForSdk) _release();
      release.complete();
      _notify();
    }
  }

  Future<void> restore() async {
    final ownerId = _currentUserId();
    if (_disposed || ownerId == null) return;
    try {
      final request = await _journal.pending();
      _checkLive(ownerId);
      _pending = request;
      _notify();
    } catch (_) {
      if (!_disposed && _currentUserId() == ownerId) {
        _onError(
            'Checkout recovery needs attention. Please contact support before paying again.');
      }
    }
  }

  Future<void> start({
    required Map<String, dynamic> intent,
    required double amount,
    required MobileCheckoutCustomer customer,
    BuildContext? context,
  }) {
    final ownerId = _currentUserId();
    if (ownerId == null || _disposed) return Future.value();
    // Freeze before waiting for another callback/operation.
    final frozen =
        (jsonDecode(jsonEncode(intent)) as Map).cast<String, dynamic>();
    return _run(ownerId, () async {
      if (_waitingForSdk) return;
      _pending = await _journal.pending();
      _checkLive(ownerId);
      if (_pending != null) {
        throw StateError('Finish the saved checkout first.');
      }
      _pending = await _journal.prepare(frozen);
      _checkLive(ownerId);
      final request = _pending!;
      if (request.intent['paymentMethod'] == 'cod') {
        await _finish(request);
        return;
      }
      if (context != null && !context.mounted) {
        throw StateError('Checkout screen was closed.');
      }
      _waitingForSdk = true;
      await _payments.openCheckout(
        amount: amount,
        purpose: CheckoutPaymentPurpose.goods,
        userName: customer.name,
        userEmail: customer.email,
        userPhone: customer.phone,
        context: context,
        description: 'Agrimore order payment',
        canOpenCheckout: () =>
            !_disposed &&
            _currentUserId() == ownerId &&
            (context == null || context.mounted),
        onOrderCreated: (order) async {
          _checkLive(ownerId);
          _pending =
              await _journal.attachGateway(ownerId, request.requestId, order);
          _checkLive(ownerId);
          _notify();
        },
      );
    });
  }

  Future<void> resume({required MobileCheckoutCustomer customer}) {
    final ownerId = _currentUserId();
    if (ownerId == null || _disposed) return Future.value();
    return _run(ownerId, () async {
      if (_waitingForSdk) return;
      _pending = await _journal.pending();
      _checkLive(ownerId);
      final request = _pending;
      if (request == null) throw StateError('Saved checkout is unavailable.');
      if (request.stage == 'awaiting_payment') {
        final order = PaymentCheckoutOrder.fromResponse(request.gateway!);
        _waitingForSdk = true;
        final result = await _payments.resumeGoodsCheckout(
          order: order,
          ownerId: ownerId,
          currentUserId: () => _disposed ? null : _currentUserId(),
          userName: customer.name,
          userEmail: customer.email,
          userPhone: customer.phone,
          description: 'Agrimore order payment',
        );
        _checkLive(ownerId);
        if (result == GoodsCheckoutResumeOutcome.reopened) return;
        _waitingForSdk = false;
        _pending = await _journal.recoverPayment(ownerId, request.requestId);
        _checkLive(ownerId);
      } else if (request.stage == 'draft' &&
          request.intent['paymentMethod'] != 'cod') {
        throw StateError('Discard the unpaid draft to review the cart.');
      }
      await _finish(_pending!);
    });
  }

  Future<void> _finish(PendingCheckoutRequest request) async {
    if (_deliveredRequestId == request.requestId) return;
    final receipts = await _journal.confirm(request.ownerId, request.requestId);
    _checkLive(request.ownerId);
    _pending = await _journal.pending();
    _checkLive(request.ownerId);
    if (_pending?.stage != 'completed') {
      throw StateError('Receipt is unavailable.');
    }
    _deliveredRequestId = request.requestId;
    try {
      await _onConfirmed(_pending!, receipts);
    } catch (_) {
      _deliveredRequestId = null;
      rethrow;
    }
  }

  void _paymentInterrupted() {
    final request = _pending;
    if (request == null || _disposed) return;
    unawaited(_run(request.ownerId, () async {
      _waitingForSdk = false;
      throw StateError('Payment outcome must be checked.');
    }));
  }

  Future<void> discardDraft() {
    final request = pending;
    if (request == null || _disposed) return Future.value();
    return _run(request.ownerId, () async {
      await _journal.discardDraft(request.ownerId, request.requestId);
      _checkLive(request.ownerId);
      _pending = null;
    });
  }

  Future<void> acknowledge(PendingCheckoutRequest request) async {
    _checkLive(request.ownerId);
    await _journal.acknowledge(request.ownerId, request.requestId);
    _checkLive(request.ownerId);
    _pending = null;
    _notify();
  }

  void dispose() {
    _disposed = true;
    _waitingForSdk = false;
    _release();
    _payments.dispose();
  }
}

/// A restored checkout must display its server order, never today's cart total.
OrderModel orderFromCheckoutReceipt(
    CheckoutReceipt receipt, String ownerId, Map<String, dynamic> data) {
  if (data['id'] != receipt.orderId ||
      data['userId'] != ownerId ||
      data['orderNumber'] != receipt.orderNumber ||
      (data['sellerId'] ?? '') != receipt.sellerId ||
      data['total'] != receipt.total) {
    throw StateError('Confirmed order details are unavailable.');
  }
  return OrderModel.fromMap(data, receipt.orderId);
}

/// Preserve a cart edited while payment was open or between app sessions.
bool checkoutMatchesCart(PendingCheckoutRequest request,
    List<CartItemModel> items, String orderMode) {
  final current = items
      .map((item) => {
            'productId': item.productId,
            'quantity': item.quantity,
            if (item.variant != null && item.variant!.isNotEmpty)
              'variantId': item.variant,
          })
      .toList();
  return items.every((item) => item.userId == request.ownerId) &&
      request.intent['orderMode'] == orderMode &&
      jsonEncode(request.intent['items']) == jsonEncode(current);
}

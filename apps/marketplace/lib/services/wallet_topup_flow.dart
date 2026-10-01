import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'native_payment_flight.dart';
import 'payment_checkout_order.dart';
import 'razorpay_service.dart';
import 'wallet_topup_recovery_service.dart';

/// Foreground native top-up coordinator. The journal owns local recovery;
/// verifyWalletTopup owns the once-only wallet credit.
class WalletTopupFlow {
  WalletTopupFlow(
      {WalletTopupRecoveryService? journal,
      RazorpayService? payments,
      String? Function()? currentUserId,
      required void Function() onChanged,
      required void Function(String) onError,
      required Future<void> Function(PendingWalletTopup, Map<String, dynamic>)
          onConfirmed})
      : _journal =
            journal ?? WalletTopupRecoveryService(currentUserId: currentUserId),
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
            _check(request.ownerId);
            await _finish(_pending!);
          }));
        },
        onFailure: (_) => _interrupted(),
        onDismiss: _interrupted);
  }
  final WalletTopupRecoveryService _journal;
  final RazorpayService _payments;
  final String? Function() _currentUserId;
  final void Function() _onChanged;
  final void Function(String) _onError;
  final Future<void> Function(PendingWalletTopup, Map<String, dynamic>)
      _onConfirmed;
  Future<void> _tail = Future.value();
  PendingWalletTopup? _pending;
  String? _heldOwner, _deliveredId;
  bool _busy = false, _waitingForSdk = false, _disposed = false;

  PendingWalletTopup? get pending =>
      !_disposed && _pending?.ownerId == _currentUserId() ? _pending : null;
  bool get isBusy => !_disposed && _busy && _heldOwner == _currentUserId();
  void _check(String owner) {
    if (_disposed || _currentUserId() != owner) {
      throw StateError('Top-up session changed.');
    }
  }

  void _notify() {
    if (!_disposed) _onChanged();
  }

  void _release() {
    if (_heldOwner != null) NativePaymentFlight.release(_heldOwner!, this);
    _heldOwner = null;
    _busy = false;
  }

  Future<void> _run(String owner, Future<void> Function() body) async {
    final previous = _tail, release = Completer<void>();
    _tail = release.future;
    try {
      await previous;
      _check(owner);
      if (!NativePaymentFlight.acquire(owner, this)) {
        throw StateError('Another payment is in progress.');
      }
      _heldOwner = owner;
      _busy = true;
      _notify();
      await body();
    } catch (_) {
      _waitingForSdk = false;
      if (!_disposed && _currentUserId() == owner) {
        try {
          _pending = await _journal.pending();
          _check(owner);
        } catch (_) {}
        if (!_disposed && _currentUserId() == owner) {
          _onError(
              'Top-up needs attention. Check the saved top-up before paying again.');
        }
      }
    } finally {
      if (!_waitingForSdk) _release();
      release.complete();
      _notify();
    }
  }

  Future<void> restore() async {
    final owner = _currentUserId();
    if (owner == null || _disposed) return;
    try {
      _pending = await _journal.pending();
      _check(owner);
      _notify();
    } catch (_) {
      if (!_disposed && _currentUserId() == owner) {
        _onError(
            'Top-up recovery needs attention. Please contact support before paying again.');
      }
    }
  }

  Future<void> start({required double amount, BuildContext? context}) {
    final owner = _currentUserId();
    if (owner == null || _disposed) return Future.value();
    return _run(owner, () async {
      if (_waitingForSdk) return;
      _pending = await _journal.pending();
      _check(owner);
      if (_pending != null) throw StateError('Finish the saved top-up first.');
      _pending = await _journal.prepare(amount);
      _check(owner);
      final request = _pending!;
      if (context != null && !context.mounted) {
        throw StateError('Top-up screen was closed.');
      }
      _waitingForSdk = true;
      await _payments.openCheckout(
          amount: request.amount,
          purpose: CheckoutPaymentPurpose.walletTopup,
          userName: '',
          userEmail: '',
          userPhone: '',
          description: 'Agrimore wallet top-up',
          context: context,
          canOpenCheckout: () =>
              !_disposed &&
              _currentUserId() == owner &&
              (context == null || context.mounted),
          onOrderCreated: (order) async {
            _check(owner);
            _pending =
                await _journal.attachGateway(owner, request.requestId, order);
            _check(owner);
            _notify();
          });
    });
  }

  Future<void> resume() {
    final owner = _currentUserId();
    if (owner == null || _disposed) return Future.value();
    return _run(owner, () async {
      if (_waitingForSdk) return;
      _pending = await _journal.pending();
      _check(owner);
      final request = _pending;
      if (request == null || request.stage == 'draft') {
        throw StateError('Review the unpaid top-up draft.');
      }
      if (request.stage == 'awaiting_payment') {
        _waitingForSdk = true;
        final outcome = await _payments.resumeWalletTopup(
            order: PaymentCheckoutOrder.fromResponse(request.gateway!),
            ownerId: owner,
            currentUserId: () => _disposed ? null : _currentUserId(),
            userName: '',
            userEmail: '',
            userPhone: '',
            description: 'Agrimore wallet top-up');
        _check(owner);
        if (outcome == GoodsCheckoutResumeOutcome.reopened) return;
        _waitingForSdk = false;
        _pending = await _journal.recoverPayment(owner, request.requestId);
        _check(owner);
      }
      await _finish(_pending!);
    });
  }

  Future<void> _finish(PendingWalletTopup request) async {
    if (_deliveredId == request.requestId) return;
    final receipt = await _journal.confirm(request.ownerId, request.requestId);
    _check(request.ownerId);
    _pending = await _journal.pending();
    _check(request.ownerId);
    if (_pending?.stage != 'completed') {
      throw StateError('Top-up confirmation is unavailable.');
    }
    _deliveredId = request.requestId;
    try {
      await _onConfirmed(_pending!, receipt);
    } catch (_) {
      _deliveredId = null;
      rethrow;
    }
  }

  void _interrupted() {
    final request = _pending;
    if (request == null || _disposed) return;
    unawaited(_run(request.ownerId, () async {
      _waitingForSdk = false;
      throw StateError('Top-up outcome must be checked.');
    }));
  }

  Future<void> discardDraft() {
    final request = pending;
    if (request == null) return Future.value();
    return _run(request.ownerId, () async {
      await _journal.discardDraft(request.ownerId, request.requestId);
      _check(request.ownerId);
      _pending = null;
    });
  }

  Future<void> acknowledge(PendingWalletTopup request) async {
    _check(request.ownerId);
    await _journal.acknowledge(request.ownerId, request.requestId);
    _check(request.ownerId);
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

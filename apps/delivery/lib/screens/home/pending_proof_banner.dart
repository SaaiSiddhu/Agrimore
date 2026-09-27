// lib/screens/home/pending_proof_banner.dart
//
// Phase DLVPP1 — the only recovery surface for a delivery whose proof photo
// never got attached (crash between confirmDelivery succeeding and the
// upload+attach pair finishing). The order has already dropped out of
// active work by the time this shows, so it must not be hidden behind any
// completion modal — always visible on the dashboard whenever a pending
// entry exists, until it is resolved or explicitly dismissed.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../delivery/delivery_problems.dart';
import '../../delivery/proof_photo_recovery.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';

Future<Uint8List?> _defaultReadPhotoBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

/// Lists every pending proof and lets the rider retry or dismiss each one.
/// Shows nothing while empty -- callers can place this unconditionally.
class PendingProofBanner extends StatefulWidget {
  const PendingProofBanner({super.key, this.store, this.backend, this.readPhotoBytes, this.discardPhoto});

  /// Injected in tests.
  final PendingProofStore? store;
  final DeliveryProblemBackend? backend;

  /// Null return means the file is gone. Injected in tests so they never
  /// touch real dart:io from inside a widget's own event handler (flutter_
  /// test's fake-async zone can stall a real file read there).
  final Future<Uint8List?> Function(String path)? readPhotoBytes;
  final Future<void> Function(String path)? discardPhoto;

  @override
  State<PendingProofBanner> createState() => _PendingProofBannerState();
}

class _PendingProofBannerState extends State<PendingProofBanner> {
  late final PendingProofStore _store = widget.store ?? SharedPreferencesPendingProofStore();
  late final DeliveryProblemBackend _backend = widget.backend ?? FirebaseDeliveryProblemBackend();
  late final Future<Uint8List?> Function(String) _readPhotoBytes = widget.readPhotoBytes ?? _defaultReadPhotoBytes;
  late final Future<void> Function(String) _discardPhoto = widget.discardPhoto ?? discardStagedProofPhoto;
  List<PendingProof> _pending = const [];
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _store.all();
    if (mounted) setState(() => _pending = all);
  }

  Future<void> _dismiss(PendingProof p) async {
    await _store.clear(p.orderId);
    await _discardPhoto(p.photoPath);
    if (mounted) setState(() => _pending = _pending.where((e) => e.orderId != p.orderId).toList());
  }

  Future<void> _retry(PendingProof p) async {
    setState(() => _retrying.add(p.orderId));
    final l = AppLocalizations.of(context);
    try {
      final bytes = await _readPhotoBytes(p.photoPath);
      if (bytes == null) {
        if (mounted) {
          showDeliveryToast(context, message: l.proofRetryMissingFile, tone: DeliveryBannerTone.warning);
        }
        await _dismiss(p);
        return;
      }
      // DLVPP1: never re-confirms the delivery itself -- attachDeliveryProof
      // alone is what's outstanding, and it is already safely re-callable
      // on its own.
      final saved = await saveDeliveryProof(_backend, p.orderId, bytes, p.contentType);
      if (saved) {
        await _store.clear(p.orderId);
        await _discardPhoto(p.photoPath);
        if (mounted) {
          setState(() => _pending = _pending.where((e) => e.orderId != p.orderId).toList());
          showDeliveryToast(context, message: l.proofRetrySucceeded, tone: DeliveryBannerTone.success);
        }
      } else if (mounted) {
        // Never claimed as saved before this point -- saveDeliveryProof
        // only returns true once the backend has actually confirmed it.
        showDeliveryToast(context, message: l.proofNotSaved, tone: DeliveryBannerTone.danger);
      }
    } finally {
      if (mounted) setState(() => _retrying.remove(p.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        for (final p in _pending)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DeliverySpace.page,
              vertical: DeliverySpace.xs,
            ),
            child: p.expired()
                ? DeliveryBanner(
                    key: ValueKey('pending-proof-expired-${p.orderId}'),
                    tone: DeliveryTone.neutral,
                    title: l.proofRetryExpiredTitle,
                    body: l.proofRetryExpiredBody,
                    actionLabel: l.proofRetryDismiss,
                    onAction: () => _dismiss(p),
                  )
                : DeliveryBanner(
                    key: ValueKey('pending-proof-${p.orderId}'),
                    tone: DeliveryTone.warning,
                    title: l.proofRetryTitle,
                    body: l.proofRetryBody,
                    actionLabel: _retrying.contains(p.orderId) ? l.proofRetrying : l.proofRetryAction,
                    onAction: _retrying.contains(p.orderId) ? null : () => _retry(p),
                  ),
          ),
      ],
    );
  }
}

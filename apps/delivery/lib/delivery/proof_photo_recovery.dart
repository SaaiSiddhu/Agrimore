// lib/delivery/proof_photo_recovery.dart
//
// Phase DLVPP1 — durable recovery for an in-flight delivery proof photo.
// confirmDelivery and attachDeliveryProof (delivery_problems.dart) are both
// already safely re-callable from a fresh app session with no in-memory
// state at all (confirmDelivery.ts short-circuits once delivered;
// attachProofCore checks the Storage object directly, not any app session).
// The only missing piece is durably remembering WHICH order still needs its
// photo attached, and the photo bytes themselves, past a restart -- this
// file owns exactly that, nothing about confirming the delivery itself.
//
// attachProofCore's own PROOF_WINDOW_MS is exactly 24h from deliveredAt;
// staying an hour under it (using capturedAt, which is always at or before
// deliveredAt) means a rider is never shown a retry the server would just
// refuse as too_late.
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'delivery_pending_proofs';
const proofRecoveryWindow = Duration(hours: 23);

/// One delivery whose proof photo has not yet been confirmed attached.
class PendingProof {
  const PendingProof({
    required this.orderId,
    required this.photoPath,
    required this.contentType,
    required this.capturedAt,
  });

  final String orderId;
  final String photoPath;
  final String contentType;
  final DateTime capturedAt;

  bool expired([DateTime? now]) => (now ?? DateTime.now()).difference(capturedAt) > proofRecoveryWindow;

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'photoPath': photoPath,
        'contentType': contentType,
        'capturedAt': capturedAt.toIso8601String(),
      };

  static PendingProof? fromJson(Object? j) {
    if (j is! Map) return null;
    final orderId = j['orderId'];
    final photoPath = j['photoPath'];
    final contentType = j['contentType'];
    final capturedAtRaw = j['capturedAt'];
    if (orderId is! String || orderId.isEmpty) return null;
    if (photoPath is! String || photoPath.isEmpty) return null;
    if (contentType is! String || contentType.isEmpty) return null;
    if (capturedAtRaw is! String) return null;
    final capturedAt = DateTime.tryParse(capturedAtRaw);
    if (capturedAt == null) return null;
    return PendingProof(orderId: orderId, photoPath: photoPath, contentType: contentType, capturedAt: capturedAt);
  }
}

/// Persists which deliveries still need their proof photo attached.
/// Injectable so tests never touch real shared_preferences.
abstract class PendingProofStore {
  Future<void> save(PendingProof proof);
  Future<void> clear(String orderId);
  Future<List<PendingProof>> all();
}

class SharedPreferencesPendingProofStore implements PendingProofStore {
  SharedPreferencesPendingProofStore([Future<SharedPreferences>? prefs])
      : _prefs = prefs ?? SharedPreferences.getInstance();
  final Future<SharedPreferences> _prefs;

  Future<Map<String, String>> _readAll(SharedPreferences p) async {
    final byOrder = <String, String>{};
    for (final entry in p.getStringList(_prefsKey) ?? const <String>[]) {
      final proof = PendingProof.fromJson(jsonDecode(entry));
      if (proof != null) byOrder[proof.orderId] = entry;
    }
    return byOrder;
  }

  @override
  Future<void> save(PendingProof proof) async {
    final p = await _prefs;
    final byOrder = await _readAll(p);
    byOrder[proof.orderId] = jsonEncode(proof.toJson());
    await p.setStringList(_prefsKey, byOrder.values.toList());
  }

  @override
  Future<void> clear(String orderId) async {
    final p = await _prefs;
    final byOrder = await _readAll(p);
    if (byOrder.remove(orderId) == null) return;
    await p.setStringList(_prefsKey, byOrder.values.toList());
  }

  @override
  Future<List<PendingProof>> all() async {
    final p = await _prefs;
    return (await _readAll(p)).values.map((e) => PendingProof.fromJson(jsonDecode(e))).whereType<PendingProof>().toList();
  }
}

/// Copies [bytes] into [dir] at a fixed, order-keyed path -- durable and
/// re-readable across a restart, unlike image_picker's own OS temp/cache
/// file. [dir] is the caller's job to resolve (production passes the app's
/// documents directory via path_provider; tests pass any real directory).
Future<String> stageProofPhotoBytes(Directory dir, String orderId, List<int> bytes) async {
  final file = File('${dir.path}/proof_photos/$orderId.jpg');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Best-effort cleanup once a photo is confirmed attached or abandoned -- a
/// leftover file is harmless, so a failure here is never surfaced.
Future<void> discardStagedProofPhoto(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best-effort only.
  }
}

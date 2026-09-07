import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Provider for the AI Marketplace Assistant's BYO-key connection state
/// (Phase AI-3). Mirrors WalletProvider's shape exactly: a live Firestore
/// listener on the client-readable status projection plus Cloud Function
/// calls for the actual mutations.
///
/// Reads ONLY `ai_connection_status/{uid}` — never `ai_connections/{uid}`,
/// which holds the encrypted key and is closed to every client, including
/// the owner (functions/src/customer/aiConnection.ts, Phase AI-1; enforced
/// by firestore.rules, not just by this provider's own restraint).
class AiConnectionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _statusSubscription;

  bool _connected = false;
  String? _provider; // 'gemini' | 'chatgpt' | null
  DateTime? _connectedAt;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  bool get connected => _connected;
  String? get provider => _provider;
  DateTime? get connectedAt => _connectedAt;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  /// Starts (or restarts) listening to the caller's own AI connection
  /// status. Safe to call repeatedly (e.g. every time Settings opens).
  void loadStatus() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    _statusSubscription?.cancel();
    _statusSubscription = _firestore
        .collection('ai_connection_status')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      _connected = data?['connected'] == true;
      _provider = data?['provider'] as String?;
      final ts = data?['connectedAt'];
      _connectedAt = ts is Timestamp ? ts.toDate() : null;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to load AI connection status: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Connects (or rotates) the caller's own ChatGPT/Gemini key via the
  /// connectAiProvider callable. The ₹50 activation fee is debited ONLY the
  /// first time a connection is created for this account — calling this
  /// again while already connected is a free key rotation (this is
  /// connectAiProvider's own server-side behaviour, not a client-side
  /// guess: see that function's header comment for the reasoning).
  /// Throws FirebaseFunctionsException on failure (most commonly
  /// failed-precondition: "Insufficient balance") so the caller can show
  /// the real reason instead of a generic message.
  Future<void> connect({required String provider, required String apiKey}) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('connectAiProvider');
      await callable.call<Map<String, dynamic>>({
        'provider': provider,
        'apiKey': apiKey,
      });
      // _connected/_provider/_connectedAt update via the Firestore listener
      // once the write lands — no local state mutation needed here.
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to connect';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Disconnects via disconnectAiProvider. No refund is issued for the
  /// original activation fee — matches that callable's own documented
  /// default (mirrors the Sales Associate onboarding-fee precedent).
  Future<void> disconnect() async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('disconnectAiProvider');
      await callable.call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to disconnect';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

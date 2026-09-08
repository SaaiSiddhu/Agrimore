import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Phase AI-4C — apps/seller's own AI Assistant BYO-key connection state.
/// Mirrors apps/marketplace/lib/providers/ai_connection_provider.dart's
/// shape closely, with two deliberate differences:
///   - `connect()` calls `connectSellerAiProvider` (functions/src/seller/
///     aiConnection.ts), not `connectAiProvider` -- the seller variant
///     requires an approved seller and a paymentId from the activation
///     checkout, since sellers have no wallet balance to debit from
///     (D-SELLER-AI-FUNDING).
///   - `disconnect()` calls the SHARED `disconnectAiProvider` (AI-1,
///     functions/src/customer/aiConnection.ts) directly, unchanged -- it
///     operates on ai_connections/{uid} keyed purely by uid with no role
///     check, so it is correct for a seller's own uid with zero backend
///     changes needed (confirmed by reading its source at claim time).
///
/// Reads ONLY `ai_connection_status/{uid}` -- never `ai_connections/{uid}`,
/// which holds the encrypted key and is closed to every client, including
/// the owner (enforced by firestore.rules, not just by this provider).
class SellerAiConnectionProvider with ChangeNotifier {
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
  /// status. Safe to call repeatedly (e.g. every time the screen opens).
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

  /// Creates the ₹50 Razorpay activation order via
  /// `createSellerAiActivationOrder` -- server-priced and rate-limited, no
  /// client-supplied amount. Returns the order details for the caller to
  /// drive the (web-only) checkout with; throws FirebaseFunctionsException
  /// on failure (e.g. `already-exists` if already connected,
  /// `resource-exhausted` if rate-limited) so the caller can show the real
  /// reason.
  Future<Map<String, dynamic>> createActivationOrder() async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createSellerAiActivationOrder');
      final result = await callable.call<Map<String, dynamic>>();
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to start payment';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Connects (or rotates) the caller's own ChatGPT/Gemini key via
  /// `connectSellerAiProvider`, verifying the Razorpay `paymentId` from a
  /// completed activation checkout server-side.
  Future<void> connect({
    required String provider,
    required String apiKey,
    required String paymentId,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('connectSellerAiProvider');
      await callable.call<Map<String, dynamic>>({
        'provider': provider,
        'apiKey': apiKey,
        'paymentId': paymentId,
      });
      // _connected/_provider/_connectedAt update via the Firestore listener
      // once the write lands -- no local state mutation needed here.
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to connect';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Disconnects via the SHARED `disconnectAiProvider` (AI-1). No refund is
  /// issued for the original activation fee -- matches that callable's own
  /// documented default (mirrors the Sales Associate onboarding-fee
  /// precedent, same as AI-3's own customer-facing disconnect()).
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

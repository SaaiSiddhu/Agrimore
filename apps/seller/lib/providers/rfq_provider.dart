import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Why a quote action failed — mapped to copy by the screen, never shown raw.
enum QuoteActionError { expired, notYourTurn, closed, generic }

/// Seller side of the RFQ negotiation. submitRfqOffer / respondToRfqOffer
/// are the same callables the buyer uses — the role is derived server-side
/// from rfq.buyerId / rfq.sellerId, never client-asserted.
class RfqProvider with ChangeNotifier {
  RfqProvider() : _preview = false;

  /// Test constructor: a fixed list, no Firebase.
  @visibleForTesting
  RfqProvider.preview(List<RfqModel> quotes) : _preview = true {
    _myRfqs = quotes;
  }

  final bool _preview;
  StreamSubscription<QuerySnapshot>? _myRfqsSubscription;
  List<RfqModel> _myRfqs = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _loadFailed = false;
  QuoteActionError? _lastError;

  List<RfqModel> get myRfqs => _myRfqs;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get loadFailed => _loadFailed;
  QuoteActionError? get lastError => _lastError;

  RfqModel? byId(String id) {
    for (final q in _myRfqs) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Starts (or restarts) listening to this seller's RFQs.
  void loadMyRfqs() {
    if (_preview) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();
    _myRfqsSubscription?.cancel();
    _myRfqsSubscription = FirebaseFirestore.instance
        .collection('rfqs')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _myRfqs = snap.docs.map(RfqModel.fromFirestore).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('RfqProvider.loadMyRfqs stream error: $e');
      _loadFailed = true;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Counter-offer with its own validity window.
  Future<bool> submitOffer({
    required String rfqId,
    required double price,
    required int quantity,
    required int validForDays,
    String? notes,
  }) =>
      _call('submitRfqOffer', {
        'rfqId': rfqId,
        'price': price,
        'quantity': quantity,
        'validForDays': validForDays,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });

  Future<bool> accept(String rfqId) => _call('respondToRfqOffer', {'rfqId': rfqId, 'action': 'accept'});

  Future<bool> decline(String rfqId, {required String reason}) =>
      _call('respondToRfqOffer', {'rfqId': rfqId, 'action': 'reject', 'reason': reason});

  Future<bool> _call(String name, Map<String, dynamic> payload) async {
    _isSubmitting = true;
    _lastError = null;
    notifyListeners();
    try {
      await FirebaseFunctions.instance.httpsCallable(name).call<Map<String, dynamic>>(payload);
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('$name failed: ${e.code} ${e.message}');
      _lastError = errorFor(e.code, e.message);
      return false;
    } catch (e) {
      debugPrint('$name failed: $e');
      _lastError = QuoteActionError.generic;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Maps a callable failure to a user-facing category (rfq.ts messages).
  static QuoteActionError errorFor(String code, String? message) {
    if (code != 'failed-precondition') return QuoteActionError.generic;
    final m = (message ?? '').toLowerCase();
    if (m.contains('expired')) return QuoteActionError.expired;
    if (m.contains('waiting for the other party')) return QuoteActionError.notYourTurn;
    if (m.contains('no longer open')) return QuoteActionError.closed;
    return QuoteActionError.generic;
  }

  @override
  void dispose() {
    _myRfqsSubscription?.cancel();
    super.dispose();
  }
}

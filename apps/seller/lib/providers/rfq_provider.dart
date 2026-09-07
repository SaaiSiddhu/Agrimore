import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for the seller side of the RFQ negotiation (Phase RFQ-2B).
/// Mirrors apps/marketplace's RfqProvider (Phase RFQ-2) exactly, except:
/// no createRfq (a seller never originates an RFQ — only a buyer does, via
/// the marketplace app) and the live query is scoped by sellerId instead of
/// buyerId. submitRfqOffer/respondToRfqOffer are the SAME two callables a
/// buyer calls — role is derived server-side from rfq.buyerId/rfq.sellerId
/// (rfq.ts's own roleOf()), never client-asserted, so reusing them here for
/// the seller side is correct by construction, not a shortcut.
class RfqProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _myRfqsSubscription;
  List<RfqModel> _myRfqs = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<RfqModel> get myRfqs => _myRfqs;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  /// Starts (or restarts) listening to the caller's own RFQs as a seller.
  /// Safe to call repeatedly (e.g. every time the Quote Requests inbox opens).
  void loadMyRfqs() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    _myRfqsSubscription?.cancel();
    _myRfqsSubscription = _firestore
        .collection('rfqs')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final rfqs = snap.docs.map((d) => RfqModel.fromFirestore(d)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _myRfqs = rfqs;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('RfqProvider.loadMyRfqs stream error: $e');
      _error = 'Failed to load your quote requests';
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Submits a counter-offer via submitRfqOffer. Only valid when it is the
  /// caller's turn (rfq.canActNow(uid)) — the server re-checks this
  /// unconditionally regardless of what the UI allowed.
  Future<void> submitOffer({
    required String rfqId,
    required double price,
    required int quantity,
    String? notes,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitRfqOffer');
      await callable.call<Map<String, dynamic>>({
        'rfqId': rfqId,
        'price': price,
        'quantity': quantity,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to submit your offer';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Accepts or rejects the other party's last offer via
  /// respondToRfqOffer.
  Future<void> respond({required String rfqId, required String action}) async {
    assert(action == 'accept' || action == 'reject');
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('respondToRfqOffer');
      await callable.call<Map<String, dynamic>>({'rfqId': rfqId, 'action': action});
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Failed to respond to this quote';
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _myRfqsSubscription?.cancel();
    super.dispose();
  }
}

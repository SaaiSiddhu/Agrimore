import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for the buyer side of the RFQ negotiation (Phase RFQ-2).
/// Mirrors WalletProvider's/AiConnectionProvider's shape exactly: a live
/// Firestore listener for display, Cloud Function calls for every mutation
/// (rfqs/{rfqId} is Cloud-Functions-only — functions/src/customer/rfq.ts,
/// Phase RFQ-1 — the client never writes it directly).
class RfqProvider with ChangeNotifier {
  RfqProvider({
    String? Function()? currentUserId,
    Stream<String?> Function()? authChanges,
    Stream<List<RfqModel>> Function(String)? rfqSnapshots,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? call,
  })  : _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _authChanges = authChanges ??
            (() => FirebaseAuth.instance.authStateChanges().map((u) => u?.uid)),
        _rfqSnapshots = rfqSnapshots,
        _call = call;

  final String? Function() _currentUserId;
  final Stream<String?> Function() _authChanges;
  final Stream<List<RfqModel>> Function(String)? _rfqSnapshots;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
      _call;

  Future<Map<String, dynamic>> _invoke(
      String name, Map<String, dynamic> data) async {
    if (_call != null) return _call(name, data);
    return (await FirebaseFunctions.instance
            .httpsCallable(name)
            .call<Map<String, dynamic>>(data))
        .data;
  }

  StreamSubscription<List<RfqModel>>? _myRfqsSubscription;
  List<RfqModel> _myRfqs = [];
  bool _isLoading = false;
  int _submissions = 0;
  String? _ownerId;
  int _sessionGeneration = 0;
  int _listGeneration = 0;
  bool _disposed = false;
  bool _listStarted = false;
  StreamSubscription<String?>? _authSubscription;
  String? _error;

  bool get _hasOwner =>
      !_disposed && _ownerId != null && _ownerId == _currentUserId();
  List<RfqModel> get myRfqs =>
      List.unmodifiable(_hasOwner ? _myRfqs : <RfqModel>[]);
  bool get isLoading => _hasOwner && _isLoading;
  bool get isSubmitting => _hasOwner && _submissions > 0;
  String? get error => _hasOwner ? _error : null;

  bool _owns(String uid, int generation) =>
      _hasOwner && _ownerId == uid && generation == _sessionGeneration;

  void _syncOwner() {
    final uid = _currentUserId();
    if (_ownerId == uid) return;
    _ownerId = uid;
    ++_sessionGeneration;
    ++_listGeneration;
    _myRfqsSubscription?.cancel();
    _myRfqsSubscription = null;
    _myRfqs = [];
    _error = null;
    _isLoading = false;
    _submissions = 0;
  }

  void _bindSession() {
    if (_disposed) return;
    _authSubscription ??= _authChanges().listen((uid) {
      if (_disposed || uid != _currentUserId() || uid == _ownerId) return;
      _syncOwner();
      notifyListeners();
      if (_listStarted && uid != null) loadMyRfqs();
    });
    _syncOwner();
  }

  Future<Map<String, dynamic>> _runCommand(
      String name, Map<String, dynamic> data, String fallback) async {
    if (_disposed) throw StateError('Quote request session changed.');
    final ownerChanged = _ownerId != _currentUserId();
    _bindSession();
    if (ownerChanged && _listStarted && _ownerId != null) {
      loadMyRfqs();
    }
    final uid = _ownerId;
    if (uid == null) throw StateError('Sign in to manage quote requests.');
    final generation = _sessionGeneration;
    ++_submissions;
    _error = null;
    notifyListeners();
    try {
      final result = await _invoke(name, data);
      if (!_owns(uid, generation)) {
        throw StateError('Quote request session changed.');
      }
      return result;
    } catch (e) {
      if (!_owns(uid, generation)) {
        throw StateError('Quote request session changed.');
      }
      if (e is FirebaseFunctionsException) _error = e.message ?? fallback;
      rethrow;
    } finally {
      if (_owns(uid, generation)) {
        --_submissions;
        notifyListeners();
      }
    }
  }

  /// Starts (or restarts) listening to the caller's own RFQs as a buyer.
  /// Safe to call repeatedly (e.g. every time "My Quotes" opens).
  void loadMyRfqs() {
    if (_disposed) return;
    _listStarted = true;
    _bindSession();
    _myRfqsSubscription?.cancel();
    _myRfqsSubscription = null;
    final listGeneration = ++_listGeneration;
    final uid = _ownerId;
    if (uid == null) {
      _myRfqs = [];
      _isLoading = false;
      notifyListeners();
      return;
    }
    final sessionGeneration = _sessionGeneration;
    bool ownsList() =>
        _owns(uid, sessionGeneration) && listGeneration == _listGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();
    final snapshots = _rfqSnapshots?.call(uid) ??
        FirebaseFirestore.instance
            .collection('rfqs')
            .where('buyerId', isEqualTo: uid)
            .snapshots()
            .map((snap) =>
                snap.docs.map((d) => RfqModel.fromFirestore(d)).toList());
    _myRfqsSubscription = snapshots.listen((entries) {
      if (!ownsList()) return;
      final rfqs = List<RfqModel>.of(entries)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _myRfqs = rfqs;
      _error = null;
      _isLoading = false;
      notifyListeners();
    }, onError: (Object e) {
      if (!ownsList()) return;
      debugPrint('RfqProvider.loadMyRfqs stream error: $e');
      _error = 'Failed to load your quote requests';
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Submits a new quote request via createRfq. Returns the new rfqId.
  Future<String> createRfq({
    required String productId,
    required int quantity,
    double? proposedPrice,
    String? notes,
  }) async {
    final result = await _runCommand(
        'createRfq',
        {
          'productId': productId,
          'quantity': quantity,
          if (proposedPrice != null) 'proposedPrice': proposedPrice,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        'Failed to submit your quote request');
    return result['rfqId'] as String;
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
    await _runCommand(
        'submitRfqOffer',
        {
          'rfqId': rfqId,
          'price': price,
          'quantity': quantity,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        'Failed to submit your offer');
  }

  /// Converts an accepted, not-yet-consumed RFQ into a real order via
  /// createOrderFromRfq (Phase RFQ-3). Cash-on-delivery only in this first
  /// slice — deliberately does not accept a paymentMethod parameter, since
  /// a non-COD path needs the full Razorpay flow this provider does not
  /// drive (see rfq_detail_screen.dart's own module comment). Returns the
  /// new orderId.
  Future<String> placeOrder({
    required String rfqId,
    required String productId,
    required int quantity,
    required Map<String, dynamic> deliveryAddress,
    double deliveryCharge = 0,
    String? deliveryQuoteId,
  }) async {
    final result = await _runCommand(
        'createOrderFromRfq',
        {
          'rfqId': rfqId,
          'productId': productId,
          'quantity': quantity,
          'deliveryAddress': deliveryAddress,
          'paymentMethod': 'cod',
          'deliveryCharge': deliveryCharge,
          'legacyDeliveryCharge': 0,
          if (deliveryQuoteId != null) 'deliveryQuoteId': deliveryQuoteId,
        },
        'Failed to place your order');
    return result['orderId'] as String;
  }

  /// Accepts or rejects the other party's last offer via
  /// respondToRfqOffer.
  Future<void> respond({required String rfqId, required String action}) async {
    assert(action == 'accept' || action == 'reject');
    await _runCommand('respondToRfqOffer', {'rfqId': rfqId, 'action': action},
        'Failed to respond to this quote');
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    ++_listGeneration;
    _authSubscription?.cancel();
    _myRfqsSubscription?.cancel();
    _myRfqs = [];
    _error = null;
    _isLoading = false;
    _submissions = 0;
    super.dispose();
  }
}

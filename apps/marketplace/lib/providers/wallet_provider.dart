import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for managing user wallet, transactions, and config
class WalletProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String)?
      _walletSnapshots;

  // State
  WalletModel? _wallet;
  WalletConfigModel _config = WalletConfigModel.defaults();
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  String? _error;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _walletSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _sessionOwner, _transactionsOwner;
  bool _bound = false, _disposed = false;
  int _epoch = 0, _walletRead = 0, _historyRead = 0, _configRead = 0;

  bool _live(String owner, int epoch) =>
      !_disposed &&
      _bound &&
      _sessionOwner == owner &&
      _auth.currentUser?.uid == owner &&
      _epoch == epoch;
  bool get _currentSession =>
      !_disposed && _bound && _sessionOwner == _auth.currentUser?.uid;
  void _cancelWallet() {
    final old = _walletSubscription;
    _walletSubscription = null;
    if (old != null) unawaited(old.cancel().catchError((Object _) {}));
  }

  WalletModel _ownedWallet(DocumentSnapshot doc, String owner) {
    if (!doc.exists || doc.id != owner) {
      throw StateError('Wallet needs attention.');
    }
    final value = WalletModel.fromFirestore(doc);
    if (value.userId != owner ||
        !value.balance.isFinite ||
        !value.lifetimeEarnings.isFinite) {
      throw StateError('Wallet needs attention.');
    }
    return value;
  }

  // Getters
  WalletModel? get wallet =>
      !_disposed && _wallet?.userId == _auth.currentUser?.uid ? _wallet : null;
  WalletConfigModel get config => _config;
  List<WalletTransactionModel> get transactions => !_disposed &&
          _transactionsOwner == _auth.currentUser?.uid &&
          _transactionsOwner != null
      ? List.unmodifiable(_transactions)
      : const [];
  bool get isLoading => _currentSession && _isLoading;
  bool get isLoadingTransactions => _currentSession && _isLoadingTransactions;
  String? get error => _currentSession ? _error : null;

  // Wallet getters
  double get balance => wallet?.balance ?? 0;
  int get coins => wallet?.coins ?? 0;
  double get totalAvailable => wallet?.totalAvailable ?? 0;

  /// Returns referral code - falls back to generated code from user ID if wallet not loaded
  String get referralCode {
    if (_disposed) return '';
    if (wallet?.referralCode != null && wallet!.referralCode.isNotEmpty) {
      return wallet!.referralCode;
    }
    // Generate fallback code: First 4 letters of name + 2 digit sequence
    final user = _auth.currentUser;
    if (user != null) {
      String namePrefix = 'AGRI';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        // Get first 4 letters of name (no spaces)
        final cleanName = user.displayName!.replaceAll(' ', '').toUpperCase();
        namePrefix = cleanName.length >= 4
            ? cleanName.substring(0, 4)
            : cleanName.padRight(4, 'X');
      }
      // Get 2 digit sequence from user ID hash
      final sequence =
          (user.uid.hashCode.abs() % 100).toString().padLeft(2, '0');
      return '$namePrefix$sequence';
    }
    return '';
  }

  bool get hasWallet => wallet != null;
  bool get canUseWallet => wallet?.canUseWallet ?? false;

  // Config getters
  double get maxCoinsPercentage => _config.maxCoinsPercentage;
  double get minOrderForCoins => _config.minOrderForCoins;
  bool get isWalletEnabled => _config.isWalletEnabled;
  bool get isCoinsEnabled => _config.isCoinsEnabled;
  bool get isReferralEnabled => _config.isReferralEnabled;

  WalletProvider(
      {FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String)?
          walletSnapshots})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _walletSnapshots = walletSnapshots {
    _authSubscription = _auth.authStateChanges().listen((_) {
      if (!_disposed) _startWalletListener();
    }, onError: (_) {
      if (_currentSession) {
        _error = 'Your session needs attention. Sign in again to continue.';
        notifyListeners();
      }
    });
    _startWalletListener();
    unawaited(loadConfig());
  }

  /// Global configuration can outlive an account, but never the provider.
  Future<void> loadConfig() async {
    if (_disposed) return;
    final read = ++_configRead;
    try {
      final doc =
          await _firestore.collection('settings').doc('wallet_config').get();
      if (_disposed || read != _configRead) return;
      _config = doc.exists
          ? WalletConfigModel.fromFirestore(doc)
          : WalletConfigModel.defaults();
      notifyListeners();
    } catch (_) {
      if (!_disposed && read == _configRead) {
        debugPrint('Wallet configuration could not be loaded.');
      }
    }
  }

  void _startWalletListener() {
    if (_disposed) return;
    final owner = _auth.currentUser?.uid;
    if (!_bound || _sessionOwner != owner) {
      _epoch++;
      _walletRead++;
      _historyRead++;
      _cancelWallet();
      _bound = true;
      _sessionOwner = owner;
      _wallet = null;
      _transactions = [];
      _transactionsOwner = null;
      _isLoading = false;
      _isLoadingTransactions = false;
      _error = null;
      notifyListeners();
    }
    if (owner == null || _walletSubscription != null) return;
    final epoch = _epoch;
    final snapshots = _walletSnapshots?.call(owner) ??
        _firestore.collection('wallets').doc(owner).snapshots();
    _walletSubscription = snapshots.listen((doc) {
      if (!_live(owner, epoch)) return;
      try {
        _wallet = doc.exists ? _ownedWallet(doc, owner) : null;
        _error = null;
      } catch (_) {
        _wallet = null;
        _error = 'Your wallet needs attention. Please refresh it.';
      }
      notifyListeners();
    }, onError: (_) {
      if (!_live(owner, epoch)) return;
      _epoch++;
      _walletRead++;
      _historyRead++;
      _cancelWallet();
      _isLoading = false;
      _isLoadingTransactions = false;
      _error = 'Your wallet could not be loaded. Please refresh it.';
      notifyListeners();
    }, onDone: () {
      if (_live(owner, epoch)) {
        _epoch++;
        _walletRead++;
        _historyRead++;
        _cancelWallet();
        _isLoading = false;
        _isLoadingTransactions = false;
        _error = 'Wallet updates paused. Please refresh your wallet.';
        notifyListeners();
      }
    });
  }

  /// Zero-only wallet creation remains protected by rules; bonuses are server-owned.
  Future<void> loadWallet() async {
    if (_disposed) return;
    _startWalletListener();
    final owner = _auth.currentUser?.uid;
    if (owner == null) {
      _error = 'Sign in to view your wallet.';
      notifyListeners();
      return;
    }
    final epoch = _epoch, read = ++_walletRead;
    bool live() => _live(owner, epoch) && read == _walletRead;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (!live()) return;
      final doc = await _firestore.collection('wallets').doc(owner).get();
      if (!live()) return;
      if (doc.exists) {
        _wallet = _ownedWallet(doc, owner);
      } else {
        final empty = WalletModel.empty(owner);
        await _firestore.collection('wallets').doc(owner).set(empty.toMap());
        if (!live()) return;
        // A snapshot may already contain a newer server credit; do not replace it.
        _wallet ??= empty;
        try {
          if (!live()) return;
          await FirebaseFunctions.instance
              .httpsCallable('creditSignupBonus')
              .call<Map<String, dynamic>>({'checkoutOwnerId': owner});
          if (!live()) return;
        } catch (_) {
          if (live()) {
            debugPrint('Wallet signup bonus confirmation needs attention.');
          }
        }
      }
    } catch (_) {
      if (live()) {
        _error = 'Your wallet could not be loaded. Please refresh it.';
      }
    } finally {
      if (live()) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refresh confirmed credit from the server before acknowledging a native receipt.
  Future<void> refreshWalletForOwner(String ownerId) async {
    if (_disposed || _auth.currentUser?.uid != ownerId) {
      throw StateError('Wallet session changed.');
    }
    _startWalletListener();
    final epoch = _epoch, read = ++_walletRead;
    void checkOwner() {
      if (!_live(ownerId, epoch) || read != _walletRead) {
        throw StateError('Wallet session changed.');
      }
    }

    checkOwner();
    try {
      final doc = await _firestore
          .collection('wallets')
          .doc(ownerId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      checkOwner();
      _wallet = _ownedWallet(doc, ownerId);
      _error = null;
    } finally {
      if (_live(ownerId, epoch) && read == _walletRead) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Session-fenced history; query bounding/index rollout remains F7.
  Future<void> loadTransactions({int limit = 20}) async {
    if (_disposed) return;
    _startWalletListener();
    final owner = _auth.currentUser?.uid;
    if (owner == null) return;
    final epoch = _epoch, read = ++_historyRead;
    bool live() => _live(owner, epoch) && read == _historyRead;
    _isLoadingTransactions = true;
    notifyListeners();
    try {
      if (!live()) return;
      final query = await _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: owner)
          .get();
      if (!live()) return;
      final values = query.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
      if (values.any((value) => value.userId != owner)) {
        throw StateError('Wallet history owner changed.');
      }
      values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transactions =
          values.length > limit ? values.take(limit).toList() : values;
      _transactionsOwner = owner;
    } catch (_) {
      if (live()) {
        _error = 'Your wallet history could not be loaded. Please refresh it.';
      }
    } finally {
      if (live()) {
        _isLoadingTransactions = false;
        notifyListeners();
      }
    }
  }

  /// Calculate max coins usable for an order
  int maxCoinsUsableForOrder(double orderTotal) {
    if (!isCoinsEnabled || coins == 0) return 0;
    if (orderTotal < minOrderForCoins) return 0;
    return wallet?.maxCoinsUsable(orderTotal, maxCoinsPercentage) ?? 0;
  }

  /// Get bonus coins for top-up amount
  int getBonusForTopup(double amount) {
    return _config.getBonusForAmount(amount);
  }

  /// Add money to wallet after a Razorpay-verified payment. Calls the
  /// verifyWalletTopup callable (functions/src/customer/wallet.ts) instead
  /// of writing balance/coins directly — it independently re-verifies the
  /// HMAC signature and the payment's captured status/amount via the
  /// Razorpay API before crediting anything, exactly like
  /// verifyRazorpayPayment already does for order payments. firestore.rules
  /// rejects a direct client write to these fields regardless, so a direct
  /// write here would simply fail with permission-denied.
  Future<void> addMoney(
    double amount,
    String paymentId, {
    required String orderId,
    required String signature,
  }) async {
    if (_disposed) throw StateError('Wallet session changed.');
    _startWalletListener();
    final owner = _auth.currentUser?.uid;
    if (owner == null) throw StateError('Sign in to continue.');
    final epoch = _epoch;
    void checkOwner() {
      if (!_live(owner, epoch)) throw StateError('Wallet session changed.');
    }

    checkOwner();
    await FirebaseFunctions.instance
        .httpsCallable('verifyWalletTopup')
        .call<Map<String, dynamic>>({
      'checkoutOwnerId': owner,
      'amount': amount,
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
    });
    checkOwner();
    await loadTransactions();
    checkOwner();
  }

  /// Validate referral code
  Future<bool> validateReferralCode(String code) async {
    if (_disposed || code.isEmpty) return false;
    final owner = _auth.currentUser?.uid;
    final epoch = _epoch;

    try {
      final query = await _firestore
          .collection('wallets')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      return owner != null && _live(owner, epoch) && query.docs.isNotEmpty;
    } catch (e) {
      if (!_disposed) debugPrint('Referral validation could not be completed.');
      return false;
    }
  }

  /// Apply referral code for current user. Calls the redeemReferralCode
  /// callable (functions/src/customer/wallet.ts) instead of writing
  /// referredBy/coins directly — that also fixes a bug the direct-write
  /// version had regardless of this hardening: it wrote the referrer's
  /// bonus to `wallets/{referrerWallet.userId}`, a document the caller does
  /// not own, which firestore.rules' isOwner()-only rule already rejected
  /// before this phase — referrers have never actually received their
  /// bonus. The Admin SDK write in redeemReferralCode bypasses that
  /// entirely and credits both wallets in one transaction.
  Future<void> applyReferralCode(String code) async {
    if (wallet == null || !_config.isReferralEnabled) return;
    if (wallet!.referredBy != null) return; // Already referred

    final owner = _auth.currentUser!.uid, epoch = _epoch;
    void checkOwner() {
      if (!_live(owner, epoch)) throw StateError('Wallet session changed.');
    }

    checkOwner();
    await FirebaseFunctions.instance
        .httpsCallable('redeemReferralCode')
        .call<Map<String, dynamic>>(
            {'code': code.toUpperCase(), 'checkoutOwnerId': owner});
    checkOwner();
    await loadWallet();
    checkOwner();
  }

  /// Generate share text for referral
  String generateShareText() {
    return 'Hey! Use my referral code $referralCode to sign up on Agrimore and get ${_config.referredBonus} coins free! Download now: https://agrimore.app';
  }

  /// Refresh wallet data
  Future<void> refresh() async {
    if (_disposed) return;
    _startWalletListener();
    final owner = _auth.currentUser?.uid, epoch = _epoch;
    await loadConfig();
    if (owner == null || !_live(owner, epoch)) return;
    await loadWallet();
    if (!_live(owner, epoch)) return;
    await loadTransactions();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _walletRead++;
    _historyRead++;
    _configRead++;
    _cancelWallet();
    final auth = _authSubscription;
    _authSubscription = null;
    if (auth != null) unawaited(auth.cancel().catchError((Object _) {}));
    super.dispose();
  }
}

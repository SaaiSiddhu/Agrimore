import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for managing user wallet, transactions, and config
class WalletProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State
  WalletModel? _wallet;
  WalletConfigModel _config = WalletConfigModel.defaults();
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;

  // Getters
  WalletModel? get wallet => _wallet;
  WalletConfigModel get config => _config;
  List<WalletTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get error => _error;

  // Wallet getters
  double get balance => _wallet?.balance ?? 0;
  int get coins => _wallet?.coins ?? 0;
  double get totalAvailable => _wallet?.totalAvailable ?? 0;

  /// Returns referral code - falls back to generated code from user ID if wallet not loaded
  String get referralCode {
    if (_wallet?.referralCode != null && _wallet!.referralCode.isNotEmpty) {
      return _wallet!.referralCode;
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

  bool get hasWallet => _wallet != null;
  bool get canUseWallet => _wallet?.canUseWallet ?? false;

  // Config getters
  double get maxCoinsPercentage => _config.maxCoinsPercentage;
  double get minOrderForCoins => _config.minOrderForCoins;
  bool get isWalletEnabled => _config.isWalletEnabled;
  bool get isCoinsEnabled => _config.isCoinsEnabled;
  bool get isReferralEnabled => _config.isReferralEnabled;

  WalletProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadConfig();
    _startWalletListener();
  }

  /// Load wallet configuration from Firestore
  Future<void> loadConfig() async {
    try {
      final doc =
          await _firestore.collection('settings').doc('wallet_config').get();
      if (doc.exists) {
        _config = WalletConfigModel.fromFirestore(doc);
      } else {
        // Use local defaults if admin has not published config yet.
        // Customer clients must not create admin-owned settings documents.
        _config = WalletConfigModel.defaults();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wallet config: $e');
    }
  }

  /// Start listening to wallet changes
  void _startWalletListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _walletSubscription?.cancel();
    _walletSubscription =
        _firestore.collection('wallets').doc(userId).snapshots().listen((doc) {
      if (doc.exists) {
        _wallet = WalletModel.fromFirestore(doc);
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Wallet listener error: $e');
    });
  }

  /// Load or create wallet for current user
  Future<void> loadWallet() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _error = 'Not logged in';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore.collection('wallets').doc(userId).get();

      if (doc.exists) {
        _wallet = WalletModel.fromFirestore(doc);
      } else {
        // Create new wallet for user with personalized referral code. This
        // document creation itself stays client-side — firestore.rules only
        // allows it when every balance-bearing field is at its zero starting
        // value (WalletModel.empty()'s exact shape), so it carries no
        // self-credit risk. The signup bonus itself is a real balance
        // mutation (coins/lifetimeCoinsEarned), so it's credited by the
        // creditSignupBonus callable instead of a direct client write, which
        // firestore.rules would now reject anyway.
        final userName = _auth.currentUser?.displayName;
        _wallet = WalletModel.empty(userId, userName: userName);
        await _firestore
            .collection('wallets')
            .doc(userId)
            .set(_wallet!.toMap());

        try {
          await FirebaseFunctions.instance
              .httpsCallable('creditSignupBonus')
              .call<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error crediting signup bonus: $e');
        }
      }

      _startWalletListener();
    } catch (e) {
      _error = 'Failed to load wallet: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load transaction history
  Future<void> loadTransactions({int limit = 20}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _isLoadingTransactions = true;
    notifyListeners();

    try {
      final query = await _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: userId)
          .get();

      _transactions = query.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
      _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_transactions.length > limit) {
        _transactions = _transactions.take(limit).toList();
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  /// Calculate max coins usable for an order
  int maxCoinsUsableForOrder(double orderTotal) {
    if (!isCoinsEnabled || coins == 0) return 0;
    if (orderTotal < minOrderForCoins) return 0;
    return _wallet?.maxCoinsUsable(orderTotal, maxCoinsPercentage) ?? 0;
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
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyWalletTopup');
      await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
      });

      await loadTransactions();
    } catch (e) {
      debugPrint('Error adding money: $e');
      rethrow;
    }
  }

  /// Validate referral code
  Future<bool> validateReferralCode(String code) async {
    if (code.isEmpty) return false;

    try {
      final query = await _firestore
          .collection('wallets')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error validating referral: $e');
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
    if (_wallet == null || !_config.isReferralEnabled) return;
    if (_wallet!.referredBy != null) return; // Already referred

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('redeemReferralCode');
      await callable.call<Map<String, dynamic>>({'code': code.toUpperCase()});

      await loadWallet();
    } catch (e) {
      debugPrint('Error applying referral: $e');
      rethrow;
    }
  }

  /// Generate share text for referral
  String generateShareText() {
    return 'Hey! Use my referral code $referralCode to sign up on Agrimore and get ${_config.referredBonus} coins free! Download now: https://agrimore.app';
  }

  /// Refresh wallet data
  Future<void> refresh() async {
    await loadConfig();
    await loadWallet();
    await loadTransactions();
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
  }
}

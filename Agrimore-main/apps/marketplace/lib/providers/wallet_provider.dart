import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        // Create new wallet for user with personalized referral code
        final userName = _auth.currentUser?.displayName;
        _wallet = WalletModel.empty(userId, userName: userName);
        await _firestore
            .collection('wallets')
            .doc(userId)
            .set(_wallet!.toMap());

        // Credit sign-up bonus if enabled
        if (_config.signupBonus > 0 && _config.isCashbackEnabled) {
          await _creditCoins(
            _config.signupBonus,
            TransactionSource.bonus,
            'Welcome bonus',
          );
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

  /// Add money to wallet (called after successful payment)
  Future<void> addMoney(double amount, String paymentId) async {
    if (_wallet == null) return;

    final bonusCoins = getBonusForTopup(amount);
    final newBalance = balance + amount;
    final newCoins = coins + bonusCoins;

    try {
      // Update wallet
      await _firestore.collection('wallets').doc(_wallet!.userId).update({
        'balance': newBalance,
        'coins': newCoins,
        'lifetimeEarnings': FieldValue.increment(amount),
        'lifetimeCoinsEarned': FieldValue.increment(bonusCoins),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record transaction for money
      await _recordTransaction(
        type: TransactionType.credit,
        source: TransactionSource.topup,
        amount: amount,
        coins: 0,
        balanceAfter: newBalance,
        coinsAfter: newCoins,
        description: 'Added ₹${amount.toStringAsFixed(0)} to wallet',
        referenceId: paymentId,
      );

      // Record transaction for bonus coins if any
      if (bonusCoins > 0) {
        await _recordTransaction(
          type: TransactionType.credit,
          source: TransactionSource.bonus,
          amount: 0,
          coins: bonusCoins,
          balanceAfter: newBalance,
          coinsAfter: newCoins,
          description: 'Top-up bonus coins',
        );
      }

      await loadTransactions();
    } catch (e) {
      debugPrint('Error adding money: $e');
      rethrow;
    }
  }

  /// Use wallet for order payment
  Future<void> useWalletForOrder({
    required String orderId,
    required double amount,
    required int coinsUsed,
  }) async {
    if (_wallet == null) return;

    final newBalance = balance - amount;
    final newCoins = coins - coinsUsed;

    try {
      await _firestore.collection('wallets').doc(_wallet!.userId).update({
        'balance': newBalance,
        'coins': newCoins,
        'lifetimeSpent': FieldValue.increment(amount),
        'lifetimeCoinsUsed': FieldValue.increment(coinsUsed),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (amount > 0) {
        await _recordTransaction(
          type: TransactionType.debit,
          source: TransactionSource.order,
          amount: amount,
          coins: 0,
          balanceAfter: newBalance,
          coinsAfter: newCoins,
          description: 'Payment for order #$orderId',
          orderId: orderId,
        );
      }

      if (coinsUsed > 0) {
        await _recordTransaction(
          type: TransactionType.debit,
          source: TransactionSource.order,
          amount: 0,
          coins: coinsUsed,
          balanceAfter: newBalance,
          coinsAfter: newCoins,
          description: 'Coins used for order #$orderId',
          orderId: orderId,
        );
      }

      await loadTransactions();
    } catch (e) {
      debugPrint('Error using wallet for order: $e');
      rethrow;
    }
  }

  /// Process refund to wallet
  Future<void> processRefund(String orderId, double amount) async {
    if (_wallet == null) return;

    final newBalance = balance + amount;

    try {
      await _firestore.collection('wallets').doc(_wallet!.userId).update({
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _recordTransaction(
        type: TransactionType.credit,
        source: TransactionSource.refund,
        amount: amount,
        coins: 0,
        balanceAfter: newBalance,
        coinsAfter: coins,
        description: 'Refund for order #$orderId',
        orderId: orderId,
      );

      await loadTransactions();
    } catch (e) {
      debugPrint('Error processing refund: $e');
      rethrow;
    }
  }

  /// Credit cashback after order
  Future<void> creditCashback(String orderId, double orderTotal) async {
    if (!_config.isCashbackEnabled) return;
    if (_wallet == null) return;

    final cashbackAmount =
        (orderTotal * _config.cashbackPercentage / 100).floor();
    if (cashbackAmount <= 0) return;

    await _creditCoins(
      cashbackAmount,
      TransactionSource.cashback,
      'Cashback for order #$orderId',
      orderId: orderId,
    );
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

  /// Apply referral code for current user
  Future<void> applyReferralCode(String code) async {
    if (_wallet == null || !_config.isReferralEnabled) return;
    if (_wallet!.referredBy != null) return; // Already referred

    try {
      // Find referrer wallet
      final query = await _firestore
          .collection('wallets')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final referrerWallet = WalletModel.fromFirestore(query.docs.first);

      // Update current user's wallet
      await _firestore.collection('wallets').doc(_wallet!.userId).update({
        'referredBy': code.toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Credit referred user bonus
      await _creditCoins(
        _config.referredBonus,
        TransactionSource.referral,
        'Referral bonus',
      );

      // Credit referrer bonus
      await _firestore.collection('wallets').doc(referrerWallet.userId).update({
        'coins': FieldValue.increment(_config.referrerBonus),
        'lifetimeCoinsEarned': FieldValue.increment(_config.referrerBonus),
        'referralCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Record referrer transaction
      await _firestore.collection('wallet_transactions').add({
        'walletId': referrerWallet.userId,
        'userId': referrerWallet.userId,
        'type': TransactionType.credit.name,
        'source': TransactionSource.referral.name,
        'amount': 0,
        'coins': _config.referrerBonus,
        'balanceAfter': referrerWallet.balance,
        'coinsAfter': referrerWallet.coins + _config.referrerBonus,
        'description': 'Referral bonus for inviting a friend',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create referral record
      await _firestore.collection('referrals').add(ReferralModel.create(
            referrerUserId: referrerWallet.userId,
            referredUserId: _wallet!.userId,
            referralCode: code.toUpperCase(),
            referrerBonus: _config.referrerBonus,
            referredBonus: _config.referredBonus,
          ).toMap());

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

  // Private helpers

  Future<void> _creditCoins(
      int amount, TransactionSource source, String description,
      {String? orderId}) async {
    if (_wallet == null) return;

    final newCoins = coins + amount;

    await _firestore.collection('wallets').doc(_wallet!.userId).update({
      'coins': newCoins,
      'lifetimeCoinsEarned': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordTransaction(
      type: TransactionType.credit,
      source: source,
      amount: 0,
      coins: amount,
      balanceAfter: balance,
      coinsAfter: newCoins,
      description: description,
      orderId: orderId,
    );
  }

  Future<void> _recordTransaction({
    required TransactionType type,
    required TransactionSource source,
    required double amount,
    required int coins,
    required double balanceAfter,
    required int coinsAfter,
    required String description,
    String? orderId,
    String? referenceId,
  }) async {
    if (_wallet == null) return;

    await _firestore.collection('wallet_transactions').add({
      'walletId': _wallet!.userId,
      'userId': _wallet!.userId,
      'type': type.name,
      'source': source.name,
      'amount': amount,
      'coins': coins,
      'balanceAfter': balanceAfter,
      'coinsAfter': coinsAfter,
      'orderId': orderId,
      'description': description,
      'referenceId': referenceId,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

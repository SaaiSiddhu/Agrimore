import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for managing wallet configuration in admin app
class WalletConfigProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WalletConfigModel _config = WalletConfigModel.defaults();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // Getters
  WalletConfigModel get config => _config;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  // Feature toggles
  bool get isWalletEnabled => _config.isWalletEnabled;
  bool get isCoinsEnabled => _config.isCoinsEnabled;
  bool get isReferralEnabled => _config.isReferralEnabled;
  bool get isCashbackEnabled => _config.isCashbackEnabled;

  // Referral settings
  int get referrerBonus => _config.referrerBonus;
  int get referredBonus => _config.referredBonus;
  int get referralFirstOrderBonus => _config.referralFirstOrderBonus;

  // Coin settings
  double get maxCoinsPercentage => _config.maxCoinsPercentage;
  double get minOrderForCoins => _config.minOrderForCoins;

  // Bonus settings
  int get signupBonus => _config.signupBonus;
  double get cashbackPercentage => _config.cashbackPercentage;
  double get firstOrderCashback => _config.firstOrderCashback;

  // Top-up bonuses (Map<amount, coins>)
  Map<int, int> get topupBonuses => _config.topupBonuses;

  WalletConfigProvider() {
    loadConfig();
  }

  /// Load wallet configuration from Firestore
  Future<void> loadConfig() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore.collection('settings').doc('wallet_config').get();
      
      if (doc.exists) {
        _config = WalletConfigModel.fromFirestore(doc);
      } else {
        // Create default config if doesn't exist
        _config = WalletConfigModel.defaults();
        await _firestore.collection('settings').doc('wallet_config').set(_config.toMap());
      }
    } catch (e) {
      _error = 'Failed to load wallet config: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save wallet configuration to Firestore
  Future<bool> saveConfig() async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.collection('settings').doc('wallet_config').set(
        _config.copyWith(updatedAt: DateTime.now()).toMap(),
        SetOptions(merge: true),
      );
      
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save wallet config: $e';
      debugPrint(_error);
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // UPDATE METHODS
  // ============================================

  /// Update feature toggles
  void updateFeatureToggles({
    bool? walletEnabled,
    bool? coinsEnabled,
    bool? referralEnabled,
    bool? cashbackEnabled,
  }) {
    _config = _config.copyWith(
      isWalletEnabled: walletEnabled,
      isCoinsEnabled: coinsEnabled,
      isReferralEnabled: referralEnabled,
      isCashbackEnabled: cashbackEnabled,
    );
    notifyListeners();
  }

  /// Update referral bonuses
  void updateReferralBonuses({
    int? referrerBonus,
    int? referredBonus,
    int? firstOrderBonus,
  }) {
    _config = _config.copyWith(
      referrerBonus: referrerBonus,
      referredBonus: referredBonus,
      referralFirstOrderBonus: firstOrderBonus,
    );
    notifyListeners();
  }

  /// Update coin settings
  void updateCoinSettings({
    double? maxPercentage,
    double? minOrder,
  }) {
    _config = _config.copyWith(
      maxCoinsPercentage: maxPercentage,
      minOrderForCoins: minOrder,
    );
    notifyListeners();
  }

  /// Update bonus settings
  void updateBonusSettings({
    int? signupBonus,
    double? cashbackPercentage,
    double? firstOrderCashback,
  }) {
    _config = _config.copyWith(
      signupBonus: signupBonus,
      cashbackPercentage: cashbackPercentage,
      firstOrderCashback: firstOrderCashback,
    );
    notifyListeners();
  }

  /// Update top-up bonuses (Map<amount, coins>)
  void updateTopupBonuses(Map<int, int> bonuses) {
    _config = _config.copyWith(topupBonuses: bonuses);
    notifyListeners();
  }

  /// Add a top-up bonus tier
  void addTopupBonus(int minAmount, int bonusCoins) {
    final bonuses = Map<int, int>.from(_config.topupBonuses);
    bonuses[minAmount] = bonusCoins;
    _config = _config.copyWith(topupBonuses: bonuses);
    notifyListeners();
  }

  /// Remove a top-up bonus tier
  void removeTopupBonus(int amount) {
    final bonuses = Map<int, int>.from(_config.topupBonuses);
    bonuses.remove(amount);
    _config = _config.copyWith(topupBonuses: bonuses);
    notifyListeners();
  }

  /// Edit a top-up bonus tier
  void editTopupBonus(int oldAmount, int newAmount, int bonusCoins) {
    final bonuses = Map<int, int>.from(_config.topupBonuses);
    bonuses.remove(oldAmount);
    bonuses[newAmount] = bonusCoins;
    _config = _config.copyWith(topupBonuses: bonuses);
    notifyListeners();
  }

  /// Reset to defaults
  void resetToDefaults() {
    _config = WalletConfigModel.defaults();
    notifyListeners();
  }
}

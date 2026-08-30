import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

/// Read-only provider for the customer-facing AgriMore Product Credit
/// surface (Phase E). Mirrors WalletProvider's shape — ChangeNotifier, a
/// balance listener, loading/error handling, disposal — but Product
/// Credit is a functionally and legally DISTINCT instrument from the cash
/// wallet: non-convertible store credit that can never become cash. See
/// wallet_screen.dart's header comment for why the two must never be
/// summed or presented as one figure. This provider never writes
/// anything — redemption happens at checkout via quoteOrderWithCredit,
/// out of scope here.
///
/// Fails closed on the feature flags. `BenefitFlagService.fetchFlags()`
/// already fails closed internally (missing doc, offline, any read error
/// -> every flag false — see that file). This provider adds one more
/// fail-closed layer on top: [init] checks the flag BEFORE touching
/// `product_credit_balances`/`product_credit_ledger` at all, so when the
/// programme is disabled (true for every environment as of this phase),
/// this provider performs ZERO Firestore reads for credit data — not "a
/// balance load that then hides itself," a genuine no-op.
class ProductCreditProvider with ChangeNotifier {
  ProductCreditProvider({BenefitFlagService? flagService})
      : _flagService = flagService ?? BenefitFlagService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BenefitFlagService _flagService;

  // Bounded read, matching this repo's Phase 10-13 read-cost discipline —
  // never an unbounded ledger listener. Loaded once per init()/refresh();
  // Workstream 3's full history screen re-queries with its own bound.
  static const int _ledgerPreviewSize = 20;

  bool _isEnabled = false;
  bool _isLoading = false;
  bool _hasLedgerError = false;
  ProductCreditBalanceModel? _balance;
  List<ProductCreditLedgerModel> _ledger = [];
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;

  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;

  /// True only when the ledger query itself failed (most likely
  /// FAILED_PRECONDITION from the missing composite index — see
  /// firestore.indexes.json — until the owner deploys it). Distinct from
  /// "flag disabled" and from "no entries yet," so the UI can show a
  /// neutral message instead of a false empty state.
  bool get hasLedgerError => _hasLedgerError;

  ProductCreditBalanceModel? get balanceModel => _balance;
  List<ProductCreditLedgerModel> get ledger => List.unmodifiable(_ledger);

  double get available => _balance?.available ?? 0;
  double get onHold => _balance?.onHold ?? 0;
  double get pending => _balance?.pending ?? 0;

  /// Call once per screen mount (mirrors WalletProvider.loadWallet()'s
  /// one-shot-fetch-then-listen shape). Checks the flag first; only when
  /// enabled does it start the balance listener and load the ledger
  /// preview.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final flags = await _flagService.fetchFlags();
      _isEnabled = flags.benefitProgramEnabled;
    } catch (e) {
      // fetchFlags() already fails closed internally; this catch is
      // belt-and-suspenders in case a future change to that contract ever
      // lets an exception through instead of resolving to disabled.
      debugPrint('ProductCreditProvider: flag fetch threw, failing closed: $e');
      _isEnabled = false;
    }

    if (!_isEnabled) {
      _balanceSubscription?.cancel();
      _balance = null;
      _ledger = [];
      _hasLedgerError = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _startBalanceListener();
    await _loadLedgerPreview();

    _isLoading = false;
    notifyListeners();
  }

  void _startBalanceListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _balanceSubscription?.cancel();
    _balanceSubscription = _firestore
        .collection('product_credit_balances')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      // A customer who has never accrued has no balance document — that
      // is a normal all-zero state, never an error.
      _balance = doc.exists
          ? ProductCreditBalanceModel.fromFirestore(doc)
          : ProductCreditBalanceModel.zero(userId);
      notifyListeners();
    }, onError: (e) {
      debugPrint('ProductCreditProvider: balance listener error: $e');
    });
  }

  Future<void> _loadLedgerPreview() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final query = await _firestore
          .collection('product_credit_ledger')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(_ledgerPreviewSize)
          .get();
      _ledger = query.docs
          .map((doc) => ProductCreditLedgerModel.fromFirestore(doc))
          .toList();
      _hasLedgerError = false;
    } catch (e) {
      // Catch rather than crash — see firestore.indexes.json's new
      // product_credit_ledger index, which production needs before this
      // query can succeed there.
      debugPrint('ProductCreditProvider: ledger query failed: $e');
      _ledger = [];
      _hasLedgerError = true;
    }
  }

  Future<void> refresh() => init();

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }
}

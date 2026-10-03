import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  ProductCreditProvider({
    BenefitFlagService? flagService,
    String? Function()? currentUserId,
    Stream<String?> Function()? authChanges,
    Stream<ProductCreditBalanceModel> Function(String uid)? balanceSnapshots,
    Future<List<ProductCreditLedgerModel>> Function(String uid)? loadLedger,
  })  : _flagService = flagService ?? BenefitFlagService(),
        _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _authChanges = authChanges ??
            (() => FirebaseAuth.instance
                .authStateChanges()
                .map((user) => user?.uid)),
        _balanceSnapshots = balanceSnapshots,
        _loadLedger = loadLedger;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BenefitFlagService _flagService;
  final String? Function() _currentUserId;
  final Stream<String?> Function() _authChanges;
  final Stream<ProductCreditBalanceModel> Function(String uid)?
      _balanceSnapshots;
  final Future<List<ProductCreditLedgerModel>> Function(String uid)?
      _loadLedger;

  // Bounded read, matching this repo's Phase 10-13 read-cost discipline —
  // never an unbounded ledger listener. Loaded once per init()/refresh();
  // Workstream 3's full history screen re-queries with its own bound.
  static const int _ledgerPreviewSize = 20;

  bool _isEnabled = false;
  bool _isLoading = false;
  bool _hasLedgerError = false;
  ProductCreditBalanceModel? _balance;
  List<ProductCreditLedgerModel> _ledger = [];
  StreamSubscription<ProductCreditBalanceModel>? _balanceSubscription;
  StreamSubscription<String?>? _authSubscription;
  String? _ownerId;
  int _loadGeneration = 0;
  bool _disposed = false;

  bool get _hasCurrentOwner =>
      !_disposed && _ownerId != null && _ownerId == _currentUserId();

  bool _owns(String ownerId, int generation) =>
      _hasCurrentOwner && _ownerId == ownerId && generation == _loadGeneration;

  bool get isEnabled => _hasCurrentOwner && _isEnabled;
  bool get isLoading => _hasCurrentOwner && _isLoading;

  /// True only when the ledger query itself failed (most likely
  /// FAILED_PRECONDITION from the missing composite index — see
  /// firestore.indexes.json — until the owner deploys it). Distinct from
  /// "flag disabled" and from "no entries yet," so the UI can show a
  /// neutral message instead of a false empty state.
  bool get hasLedgerError => isEnabled && _hasLedgerError;

  ProductCreditBalanceModel? get balanceModel => isEnabled ? _balance : null;
  List<ProductCreditLedgerModel> get ledger =>
      List.unmodifiable(isEnabled ? _ledger : <ProductCreditLedgerModel>[]);

  double get available => balanceModel?.available ?? 0;
  double get onHold => balanceModel?.onHold ?? 0;
  double get pending => balanceModel?.pending ?? 0;

  void _cancelBalanceListener() {
    _balanceSubscription?.cancel();
    _balanceSubscription = null;
  }

  void _clearCredit() {
    _balance = null;
    _ledger = [];
    _hasLedgerError = false;
    _isEnabled = false;
  }

  /// Call once per screen mount (mirrors WalletProvider.loadWallet()'s
  /// one-shot-fetch-then-listen shape). Checks the flag first; only when
  /// enabled does it start the balance listener and load the ledger
  /// preview.
  Future<void> init() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final ownerId = _currentUserId();
    if (_ownerId != ownerId) _clearCredit();
    _ownerId = ownerId;
    _cancelBalanceListener();
    _authSubscription ??= _authChanges().listen((userId) {
      // An auth event queued before the current identity changed cannot
      // rebind the provider to an obsolete session.
      if (_disposed || userId != _currentUserId() || userId == _ownerId) {
        return;
      }
      _ownerId = userId;
      ++_loadGeneration;
      _cancelBalanceListener();
      _clearCredit();
      _isLoading = false;
      notifyListeners();
      if (userId != null) unawaited(init());
    });
    if (ownerId == null) {
      _clearCredit();
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();

    var enabled = false;
    try {
      final flags = await _flagService.fetchFlags();
      enabled = flags.benefitProgramEnabled;
    } catch (e) {
      // fetchFlags() already fails closed internally; this catch is
      // belt-and-suspenders in case a future change to that contract ever
      // lets an exception through instead of resolving to disabled.
      debugPrint('ProductCreditProvider: flag fetch threw, failing closed: $e');
    }

    if (!_owns(ownerId, generation)) return;
    _isEnabled = enabled;

    if (!_isEnabled) {
      _cancelBalanceListener();
      _clearCredit();
      _isLoading = false;
      notifyListeners();
      return;
    }

    _startBalanceListener(ownerId, generation);
    await _loadLedgerPreview(ownerId, generation);

    if (!_owns(ownerId, generation)) return;

    _isLoading = false;
    notifyListeners();
  }

  void _startBalanceListener(String userId, int generation) {
    if (!_owns(userId, generation) || !_isEnabled) return;

    _cancelBalanceListener();
    final snapshots = _balanceSnapshots?.call(userId) ??
        _firestore
            .collection('product_credit_balances')
            .doc(userId)
            .snapshots()
            .map((doc) => doc.exists
                ? ProductCreditBalanceModel.fromFirestore(doc)
                : ProductCreditBalanceModel.zero(userId));
    _balanceSubscription = snapshots.listen((balance) {
      if (!_owns(userId, generation) || !_isEnabled) return;
      // A customer who has never accrued has no balance document — that
      // is a normal all-zero state, never an error.
      _balance = balance;
      notifyListeners();
    }, onError: (e) {
      if (!_owns(userId, generation) || !_isEnabled) return;
      debugPrint('ProductCreditProvider: balance listener error: $e');
    });
  }

  Future<void> _loadLedgerPreview(String userId, int generation) async {
    if (!_owns(userId, generation) || !_isEnabled) return;

    try {
      final entries = _loadLedger != null
          ? await _loadLedger(userId)
          : (await _firestore
                  .collection('product_credit_ledger')
                  .where('customerId', isEqualTo: userId)
                  .orderBy('createdAt', descending: true)
                  .limit(_ledgerPreviewSize)
                  .get())
              .docs
              .map((doc) => ProductCreditLedgerModel.fromFirestore(doc))
              .toList();
      if (!_owns(userId, generation) || !_isEnabled) return;
      _ledger = entries;
      _hasLedgerError = false;
    } catch (e) {
      if (!_owns(userId, generation) || !_isEnabled) return;
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
    _disposed = true;
    ++_loadGeneration;
    _authSubscription?.cancel();
    _cancelBalanceListener();
    _clearCredit();
    _isLoading = false;
    super.dispose();
  }
}

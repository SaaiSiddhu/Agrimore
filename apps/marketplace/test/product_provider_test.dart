// The repo's first Flutter test (apps/marketplace previously had no test/
// directory at all). Proves ProductProvider.loadProducts' race-window fix
// (Phase 12, Workstream 1) with a real, controllable-timing test instead of
// a written argument — the previous phase's written cache-interaction trace
// was later found to have a real hole, which is exactly what this test
// exists to prevent happening again silently.
//
// Firebase.initializeApp() is mocked via the OFFICIAL
// firebase_core_platform_interface test helper (package:firebase_core_
// platform_interface/test.dart's setupFirebaseCoreMocks()) — not a hand-
// rolled mock, and no change to any package under packages/. This is needed
// because DatabaseService (packages/agrimore_services) eagerly initializes
// `_firestore = FirebaseFirestore.instance` in its own constructor, which
// throws without a real Firebase app — even for a subclass that overrides
// every method DatabaseService exposes and never touches that field.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

import 'package:agrimore_marketplace/providers/product_provider.dart';

// Mirrors the private cache keys declared in product_provider.dart. Not
// importable directly — Dart privacy is per-file, not per-class — so these
// must be kept in sync by hand if the real constants ever change.
const _kProductsCacheKey = 'cached_products_v1';
const _kProductsCacheTimeKey = 'cached_products_time';

/// Fake data source with fully controllable per-call completion, so a test
/// can pause a "network" fetch mid-flight and observe exactly what happens
/// while it's still pending.
class _FakeDatabaseService extends DatabaseService {
  final List<int?> requestedLimits = [];
  final List<Completer<List<ProductModel>>> _resultCompleters = [];
  final List<Completer<void>> _startedCompleters = [];

  @override
  Future<List<ProductModel>> getAllProducts({
    String? location,
    int? limit,
  }) async {
    final index = requestedLimits.length;
    requestedLimits.add(limit);
    final resultCompleter = Completer<List<ProductModel>>();
    _resultCompleters.add(resultCompleter);
    _ensureStarted(index).complete();
    return resultCompleter.future;
  }

  Completer<void> _ensureStarted(int index) {
    while (_startedCompleters.length <= index) {
      _startedCompleters.add(Completer<void>());
    }
    return _startedCompleters[index];
  }

  /// Completes once getAllProducts has been invoked for the (index+1)-th
  /// time. Safe to call before or after that invocation actually happens.
  Future<void> callStarted(int index) => _ensureStarted(index).future;

  void completeCall(int index, List<ProductModel> result) {
    _resultCompleters[index].complete(result);
  }
}

ProductModel _fakeProduct(String id, {DateTime? createdAt}) {
  final at = createdAt ?? DateTime.now();
  return ProductModel(
    id: id,
    name: 'Product $id',
    description: 'desc',
    salePrice: 10.0,
    categoryId: 'cat-1',
    images: const [],
    stock: 5,
    createdAt: at,
    updatedAt: at,
  );
}

/// Hand-built cache JSON (rather than ProductModel(...).toJson(), which
/// embeds a cloud_firestore Timestamp for createdAt/updatedAt) so this test
/// has no dependency on Timestamp's own JSON behavior. ProductModel.fromMap
/// accepts ISO date strings for createdAt/updatedAt via parseDateSafely, so
/// this round-trips through the exact code path _loadFromCache uses.
String _seedCacheJson(List<String> ids) {
  final now = DateTime.now().toIso8601String();
  return jsonEncode(ids
      .map((id) => {
            'id': id,
            'name': 'Cached $id',
            'description': 'desc',
            'salePrice': 10.0,
            'categoryId': 'cat-1',
            'images': <String>[],
            'stock': 5,
            'createdAt': now,
            'updatedAt': now,
          })
      .toList());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ProductProvider.loadProducts', () {
    test(
      'a concurrent call does not silently short-circuit on a cache-preview-only state (the race fix)',
      () async {
        SharedPreferences.setMockInitialValues({
          _kProductsCacheKey: _seedCacheJson(['cached-1', 'cached-2']),
          _kProductsCacheTimeKey: DateTime.now().toIso8601String(),
        });
        await SharedPreferencesService.init();

        final fakeDb = _FakeDatabaseService();
        final provider = ProductProvider(databaseService: fakeDb);

        // Call A: limit 60. Runs synchronously up to its first await (the
        // on-disk cache read), so by the time this line returns, call A's
        // in-flight state (its own _loadCompleter, etc.) is already set up.
        final callA = provider.loadProducts(limit: 60);

        // Wait until call A's cache-preview step has actually run (this is
        // the exact moment the pre-fix code sets the transient
        // _isLoaded=true/_loadedProductLimit=null state) and it has reached
        // the real network call — i.e. it is genuinely mid-flight, which is
        // the race window under test.
        await fakeDb.callStarted(0).timeout(const Duration(seconds: 2));
        expect(fakeDb.requestedLimits, [60]);

        // Call B: limit 100, started while call A is still mid-flight. With
        // the fix, _isLoaded is still false at this point (only the cache
        // preview ran, not a real load), so call B does NOT take the
        // hasEnoughInMemoryProducts early return — it falls through to the
        // pre-existing _loadCompleter race-handling path and awaits call
        // A's completer instead, exactly as that path was always designed
        // to serialize concurrent callers.
        final callB = provider.loadProducts(limit: 100);

        // Resolve call A. This is what call B is waiting on.
        fakeDb.completeCall(0, [_fakeProduct('net-a')]);
        await callA;

        // THE KEY ASSERTION: now that call A has finished with a smaller
        // limit (60) than call B wants (100), call B must resume from its
        // _loadCompleter wait and issue its OWN network request — not
        // silently accept call A's smaller result. Pre-fix, this section is
        // never reached at all: call B already returned synchronously,
        // before call A even started its network fetch, via the
        // hasEnoughInMemoryProducts early return — so requestedLimits never
        // grows past length 1 and this line times out and fails the test.
        await fakeDb.callStarted(1).timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'call B never issued its own getAllProducts request — it '
            'short-circuited on a cache-preview-only state instead of '
            'either waiting on the in-flight call A or issuing its own '
            'follow-up fetch once call A turned out to be smaller than '
            'what call B needed. This is the exact race this test exists '
            'to catch.',
          ),
        );
        expect(fakeDb.requestedLimits, [60, 100]);

        // Resolve call B's own fetch so the test finishes cleanly.
        fakeDb.completeCall(
          1,
          [_fakeProduct('net-b-1'), _fakeProduct('net-b-2')],
        );
        await callB;

        // Final state reflects call B's real, larger fetch — not a stale
        // short-circuited result frozen at call A's smaller one.
        expect(
          provider.products.map((p) => p.id).toList(),
          ['net-b-1', 'net-b-2'],
        );
      },
    );

    test(
      'paints from the on-disk cache before the network fetch resolves (Phase 11 fix must not regress)',
      () async {
        SharedPreferences.setMockInitialValues({
          _kProductsCacheKey: _seedCacheJson(['cached-1', 'cached-2']),
          _kProductsCacheTimeKey: DateTime.now().toIso8601String(),
        });
        await SharedPreferencesService.init();

        final fakeDb = _FakeDatabaseService();
        final provider = ProductProvider(databaseService: fakeDb);

        var notifyCount = 0;
        provider.addListener(() => notifyCount++);

        final future = provider.loadProducts(limit: 60);

        await fakeDb.callStarted(0).timeout(const Duration(seconds: 2));
        // Let the deferred _notifySafely (Future.microtask) callback run.
        await Future<void>.delayed(Duration.zero);

        expect(notifyCount, greaterThanOrEqualTo(1));
        expect(
          provider.products.map((p) => p.id).toList(),
          ['cached-1', 'cached-2'],
        );

        fakeDb.completeCall(0, [_fakeProduct('net-1')]);
        await future;
      },
    );

    test(
      'writes the on-disk cache after a successful categoryId==null load with a non-null limit, '
      'and a fresh provider round-trips it correctly, including dates '
      '(the exact guard Phase 11 fixed, now that Phase 13 also fixed the Timestamp '
      'serialization bug that made the write always fail)',
      () async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferencesService.init();

        final fakeDb = _FakeDatabaseService();
        final provider = ProductProvider(databaseService: fakeDb);

        // Deliberately a local (non-UTC) DateTime, matching how the app
        // constructs dates elsewhere (DateTime.now()) — Timestamp.toDate()
        // returns local time, so a UTC fixture here would introduce a
        // spurious UTC-vs-local conversion into the comparison below that
        // has nothing to do with what this test is actually checking.
        final fixedCreatedAt = DateTime(2026, 1, 15, 10, 30);
        final future = provider.loadProducts(limit: 60);
        await fakeDb.callStarted(0).timeout(const Duration(seconds: 2));
        fakeDb.completeCall(0, [
          _fakeProduct('p1', createdAt: fixedCreatedAt),
          _fakeProduct('p2', createdAt: fixedCreatedAt),
        ]);
        await future;

        // The write itself: this is the assertion Phase 12 could not
        // honestly make, because it was always false at the time (see
        // Phase 13's completion report for the Timestamp bug this fixed).
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_kProductsCacheKey);
        expect(cached, isNotNull);
        expect(cached, isNotEmpty);
        final decoded = jsonDecode(cached!) as List<dynamic>;
        expect(decoded.length, 2);
        // Also proves the sanitizer actually ran: a raw Timestamp would
        // have made jsonEncode throw before reaching this point at all, so
        // getting real decoded JSON here is itself part of the proof.
        expect(decoded.every((e) => (e as Map)['createdAt'] is String), isTrue);

        // The read-back: a FRESH provider (simulating an app restart),
        // sharing only the persisted SharedPreferences, must reconstruct
        // equivalent products — including the correct date, not a
        // silently-substituted DateTime.now() — proving this is a genuine
        // round-trip, not just "a string got written somewhere."
        final freshFakeDb = _FakeDatabaseService();
        final freshProvider = ProductProvider(databaseService: freshFakeDb);
        final freshLoad = freshProvider.loadProducts(limit: 60);
        await freshFakeDb.callStarted(0).timeout(const Duration(seconds: 2));

        expect(
          freshProvider.products.map((p) => p.id).toSet(),
          {'p1', 'p2'},
        );
        for (final p in freshProvider.products) {
          expect(p.createdAt, fixedCreatedAt);
          expect(p.updatedAt, fixedCreatedAt);
        }

        freshFakeDb.completeCall(0, [
          _fakeProduct('p1', createdAt: fixedCreatedAt),
          _fakeProduct('p2', createdAt: fixedCreatedAt),
        ]);
        await freshLoad;
      },
    );
  });

  // A behavioral test of loadProductById itself (proving it resolves
  // without waiting on addToRecentlyViewed) was attempted here and removed:
  // addToRecentlyViewed unconditionally reads FirebaseAuth.instance.
  // currentUser, and this suite's Firebase mocking (setupFirebaseCoreMocks()
  // only, matching every other test in this file) does not stub the Auth
  // plugin's method channel — touching .currentUser throws a
  // PlatformException from inside the Auth plugin's own internal listener
  // registration, on a detached Future that addToRecentlyViewed's own
  // try/catch cannot reach (the throw happens outside its synchronous call
  // stack), which then surfaces as a spurious failure on whichever test
  // happens to be running when it lands — corrupting the source-shape
  // guards below, not exercising a real defect in the fix. Reproducing this
  // properly needs Auth-specific test mocking (e.g. a MethodChannel mock
  // for firebase_auth_platform_interface) or a fake_cloud_firestore-style
  // dependency, deliberately not added in this phase (see PERF-1's ledger
  // row: no packages/agrimore_core change, no new test dependency — kept
  // this phase's footprint to exactly the reported latency fixes). The two
  // guards below cover the same regression textually instead.
  group('PERF-1 source-shape guards', () {
    // These two assert a textual/structural property directly against the
    // committed source rather than an observed runtime timing (which proved
    // unreliable to assert deterministically in a unit test — both the
    // fixed and pre-fix shapes finish within the same test tick here, since
    // SharedPreferences' test mock and the unauthenticated
    // addToRecentlyViewed path are both effectively synchronous in this
    // harness). A textual guard is a weaker proof than a timing-based one,
    // but it is exact, deterministic, and will fail loudly if either
    // property is ever silently reverted — which a written PR description
    // alone would not catch (this repo's own standing lesson: a written
    // claim is not evidence).
    test(
      'main.dart: AppCheckService.activate() must not be awaited before runApp(',
      () async {
        final source = await File(
          '${Directory.current.path}/lib/main.dart',
        ).readAsString();

        final runAppIndex = source.indexOf('runApp(');
        final activateIndex = source.indexOf('AppCheckService.activate()');

        expect(runAppIndex, greaterThan(-1),
            reason: 'runApp( not found in main.dart — has it moved/renamed?');
        expect(activateIndex, greaterThan(-1),
            reason: 'AppCheckService.activate() not found in main.dart — '
                'has it moved/renamed?');

        // The historical bug: `await AppCheckService.activate();` sequenced
        // before runApp() held the app's very first frame behind a Play
        // Integrity/App Attest network round-trip. Guard both halves of
        // the fix: it must now come AFTER runApp(, and it must not be
        // awaited at its (new) call site.
        expect(
          activateIndex,
          greaterThan(runAppIndex),
          reason: 'AppCheckService.activate() is sequenced before runApp() '
              'again — this blocks the first frame behind an App Check '
              'network round-trip (PERF-1 regression).',
        );
        expect(
          source.contains('await AppCheckService.activate()'),
          isFalse,
          reason: 'AppCheckService.activate() is awaited again somewhere — '
              'it must stay fire-and-forget (PERF-1 regression).',
        );
      },
    );

    test(
      'product_provider.dart: addToRecentlyViewed(...) must not be awaited '
      'inside loadProductById',
      () async {
        final source = await File(
          '${Directory.current.path}/lib/providers/product_provider.dart',
        ).readAsString();

        expect(
          source.contains('await addToRecentlyViewed('),
          isFalse,
          reason: 'addToRecentlyViewed is awaited again inside '
              'loadProductById — this holds the product page\'s own '
              'loading/shimmer state hostage to "recently viewed" '
              'bookkeeping again (PERF-1 regression).',
        );
        expect(
          source.contains('addToRecentlyViewed(_selectedProduct!);'),
          isTrue,
          reason: 'the expected fire-and-forget call site is missing — has '
              'loadProductById been restructured?',
        );
      },
    );
  });
}

// Proves CategoryProvider's on-disk cache (Phase 13) actually round-trips,
// the same way product_provider_test.dart proves it for products. Mirrors
// that file's setupFirebaseCoreMocks() pattern — see its header comment for
// why that's needed (DatabaseService's own eager FirebaseFirestore.instance
// field, not anything specific to CategoryProvider).
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

import 'package:agrimore_marketplace/providers/category_provider.dart';

// Mirrors the private cache keys declared in category_provider.dart. Not
// importable directly — Dart privacy is per-file, not per-class.
const _kCategoriesCacheKey = 'cached_categories_v1';
const _kCategoriesCacheTimeKey = 'cached_categories_time';

class _FakeDatabaseService extends DatabaseService {
  final List<Completer<List<CategoryModel>>> _resultCompleters = [];
  final List<Completer<void>> _startedCompleters = [];

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    final index = _resultCompleters.length;
    final resultCompleter = Completer<List<CategoryModel>>();
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

  Future<void> callStarted(int index) => _ensureStarted(index).future;

  void completeCall(int index, List<CategoryModel> result) {
    _resultCompleters[index].complete(result);
  }
}

CategoryModel _fakeCategory(String id, {DateTime? createdAt}) {
  return CategoryModel(
    id: id,
    name: 'Category $id',
    description: 'desc',
    displayOrder: 1,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('CategoryProvider cache', () {
    test(
      'writes the on-disk cache after a successful load, and a fresh provider round-trips '
      'id/name/displayOrder — but deliberately NOT createdAt, which is intentionally omitted '
      '(see category_provider.dart for why: CategoryModel.fromMap has no String date branch, '
      'so caching an ISO string would read back lossily as DateTime.now(); createdAt is '
      'confirmed unused anywhere in the app — category display/sort uses displayOrder)',
      () async {
        SharedPreferences.setMockInitialValues({});
        await SharedPreferencesService.init();

        final fakeDb = _FakeDatabaseService();
        final provider = CategoryProvider(databaseService: fakeDb);

        final future = provider.loadCategories();
        await fakeDb.callStarted(0).timeout(const Duration(seconds: 2));
        fakeDb.completeCall(0, [_fakeCategory('c1'), _fakeCategory('c2')]);
        await future;

        // The write itself — this is the assertion that was impossible
        // before Phase 13's Timestamp-sanitizer fix (jsonEncode threw every
        // time, silently swallowed by _saveToCache's own catch block).
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_kCategoriesCacheKey);
        expect(cached, isNotNull);
        expect(cached, isNotEmpty);
        final decoded = jsonDecode(cached!) as List<dynamic>;
        expect(decoded.length, 2);

        // Confirms the deliberate omission, not an accident: createdAt
        // must not be present in the cached payload at all.
        for (final entry in decoded) {
          expect(
            (entry as Map<String, dynamic>).containsKey('createdAt'),
            isFalse,
            reason: 'createdAt should be omitted from the cached payload — '
                'see category_provider.dart _saveToCache',
          );
        }

        // The read-back: a FRESH provider (simulating an app restart)
        // reconstructs equivalent categories from the same persisted
        // SharedPreferences — proving a genuine round-trip through the real
        // _loadFromCache path, not just "a string got written somewhere."
        final freshFakeDb = _FakeDatabaseService();
        final freshProvider = CategoryProvider(databaseService: freshFakeDb);
        final freshLoad = freshProvider.loadCategories();
        await freshFakeDb.callStarted(0).timeout(const Duration(seconds: 2));

        expect(
          freshProvider.categories.map((c) => c.id).toSet(),
          {'c1', 'c2'},
        );
        expect(
          freshProvider.categories.map((c) => c.name).toSet(),
          {'Category c1', 'Category c2'},
        );
        expect(
          freshProvider.categories.map((c) => c.displayOrder).toSet(),
          {1},
        );

        freshFakeDb.completeCall(0, [_fakeCategory('c1'), _fakeCategory('c2')]);
        await freshLoad;
      },
    );
  });
}

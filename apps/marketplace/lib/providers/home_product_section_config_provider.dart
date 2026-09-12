import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Read-only marketplace counterpart to admin's HomeProductSectionProvider —
/// loads the same `home_product_sections` collection so Home's product
/// carousels can be admin-ordered instead of a hardcoded loop-all-active-
/// categories algorithm. Named *Config*Provider (not just
/// HomeProductSectionProvider) to avoid colliding with the write-side
/// class of the identical name in apps/admin — they're separate packages,
/// so this isn't a compile conflict, just a readability choice: the name
/// makes clear this side only ever reads the config, never edits it.
///
/// An empty/absent collection is NOT an error — mobile_home_screen.dart
/// falls back to its pre-existing behaviour in that case, so this provider
/// only needs to report what it has, never synthesize a default.
class HomeProductSectionConfigProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<HomeProductSectionConfigModel> _sections = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  /// Active sections, sorted by position — the only thing a caller needs.
  List<HomeProductSectionConfigModel> get activeSections {
    final active = _sections.where((s) => s.isActive).toList();
    active.sort((a, b) => a.position.compareTo(b.position));
    return active;
  }

  bool get hasConfiguredSections => activeSections.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  Future<void> loadSections({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _isLoading = true;
    if (!_hasLoadedOnce) notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('home_product_sections')
          .orderBy('position')
          .get();
      _sections = snapshot.docs
          .map((doc) => HomeProductSectionConfigModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('⚠️ HomeProductSectionConfigProvider load error: $e');
      // Keep whatever was previously loaded (or the empty default) — the
      // caller's own fallback path handles "nothing configured" already,
      // so a failed read degrades to that same safe path, not a crash.
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }
}

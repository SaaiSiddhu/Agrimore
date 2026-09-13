import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the singleton `settings/home_section_order` document so an admin
/// can reorder the Home screen's own reorderable content sections,
/// independently per platform (mobile's and web's own section sets already
/// differ -- web alone has `categories_grid`).
///
/// [mobileOrder] and [webOrder] each validate the admin's array is an exact
/// permutation of that platform's own known identifier set (right length, no
/// duplicates, no unrecognized entries) before trusting it -- any invalid or
/// absent data falls back to the FULL platform default (today's own exact
/// order, both screens' fixed sections excluded, see the constants below),
/// never a partial or broken render.
class HomeSectionOrderProvider with ChangeNotifier {
  static const List<String> defaultMobileOrder = [
    'bestsellers',
    'grocery_kitchen_strip',
    'recently_viewed',
    'dynamic_category_sections',
    'product_sections',
  ];

  static const List<String> defaultWebOrder = [
    'recently_viewed',
    'categories_grid',
    'bestsellers',
    'grocery_kitchen_strip',
    'dynamic_category_sections',
    'product_sections',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _subscription;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  List<String>? _rawMobileOrder;
  List<String>? _rawWebOrder;

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// The mobile section order to render: the admin's own array when it is a
  /// valid permutation of [defaultMobileOrder], else the default.
  List<String> get mobileOrder =>
      _validPermutationOrDefault(_rawMobileOrder, defaultMobileOrder);

  /// The web section order to render: the admin's own array when it is a
  /// valid permutation of [defaultWebOrder], else the default.
  List<String> get webOrder =>
      _validPermutationOrDefault(_rawWebOrder, defaultWebOrder);

  List<String> _validPermutationOrDefault(
      List<String>? candidate, List<String> platformDefault) {
    if (candidate == null) return platformDefault;
    if (candidate.length != platformDefault.length) return platformDefault;
    if (candidate.toSet().length != candidate.length) return platformDefault;
    if (!candidate.toSet().containsAll(platformDefault)) {
      return platformDefault;
    }
    return candidate;
  }

  Future<void> loadSettings({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _isLoading = true;
    if (!_hasLoadedOnce) notifyListeners();

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('home_section_order')
          .get();
      _applySnapshot(doc);
      _startRealtimeListener();
    } catch (e) {
      debugPrint('⚠️ HomeSectionOrderProvider load error: $e');
      // Keep the platform defaults already in effect -- never leave either
      // Home screen unable to render because this one read failed.
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();
    _subscription = _firestore
        .collection('settings')
        .doc('home_section_order')
        .snapshots()
        .listen((doc) {
      _applySnapshot(doc);
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ HomeSectionOrderProvider listener error: $e');
    });
  }

  void _applySnapshot(DocumentSnapshot doc) {
    if (!doc.exists) {
      _rawMobileOrder = null;
      _rawWebOrder = null;
      return;
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawMobile = data['mobileOrder'];
    _rawMobileOrder =
        rawMobile is List ? rawMobile.map((e) => e.toString()).toList() : null;

    final rawWeb = data['webOrder'];
    _rawWebOrder =
        rawWeb is List ? rawWeb.map((e) => e.toString()).toList() : null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

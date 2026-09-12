import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the same `settings/location_settings` document
/// `apps/admin`'s LocationSettingsScreen already writes (`activeLocations`,
/// `defaultEtaText`, `cityEtaOverrides`, `unserviceableText`) so the Home
/// app bar's delivery-promise line is admin-editable instead of a hardcoded
/// Dart string, and so "is this city serviceable" has exactly one source of
/// truth across the admin's location bottom sheet and the app bar.
///
/// Falls back to the pre-HOME-2 hardcoded copy/city list if the document
/// doesn't exist yet (a fresh install before any admin has ever saved this
/// screen) or a read fails — never an empty or broken app bar.
class LocationSettingsProvider with ChangeNotifier {
  static const List<String> _fallbackServiceableCities = [
    'chennai',
    'madurai',
    'theni',
    'coimbatore',
    'bengaluru',
    'bangalore',
  ];
  static const String _fallbackEtaText = '30 minutes';
  static const String _fallbackUnserviceableText = 'Not currently serviceable';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _subscription;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  List<String> _activeLocations = [];
  String _defaultEtaText = _fallbackEtaText;
  String _unserviceableText = _fallbackUnserviceableText;
  Map<String, String> _cityEtaOverrides = {};

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  Future<void> loadSettings({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _isLoading = true;
    if (!_hasLoadedOnce) notifyListeners();

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('location_settings')
          .get();
      _applySnapshot(doc);
      _startRealtimeListener();
    } catch (e) {
      debugPrint('⚠️ LocationSettingsProvider load error: $e');
      // Keep the fallback defaults already set — never leave the app bar
      // blank because this one read failed.
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
        .doc('location_settings')
        .snapshots()
        .listen((doc) {
      _applySnapshot(doc);
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ LocationSettingsProvider listener error: $e');
    });
  }

  void _applySnapshot(DocumentSnapshot doc) {
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>? ?? {};

    _activeLocations = List<String>.from(data['activeLocations'] ?? const []);

    final rawEta = data['defaultEtaText'];
    if (rawEta is String && rawEta.trim().isNotEmpty) {
      _defaultEtaText = rawEta.trim();
    }

    final rawUnserviceable = data['unserviceableText'];
    if (rawUnserviceable is String && rawUnserviceable.trim().isNotEmpty) {
      _unserviceableText = rawUnserviceable.trim();
    }

    final rawOverrides = data['cityEtaOverrides'];
    if (rawOverrides is Map) {
      _cityEtaOverrides = rawOverrides.map(
        (key, value) => MapEntry(key.toString().toLowerCase(), value.toString()),
      );
    }
  }

  /// Case-insensitive substring match against the admin-configured
  /// serviceable-location list, mirroring the matching style
  /// `_AutoLocationSheet` already used for its own (now superseded)
  /// hardcoded list — same semantics, single admin-editable source.
  bool isServiceable(String? city) {
    if (city == null || city.trim().isEmpty) return false;
    final normalized = city.toLowerCase();
    final locations = _activeLocations.isNotEmpty
        ? _activeLocations
        : _fallbackServiceableCities;
    return locations.any((loc) => normalized.contains(loc.toLowerCase()));
  }

  /// The delivery-promise text for [city]: a per-city override if the admin
  /// set one, else the global default, else the pre-HOME-2 fallback string —
  /// only when [city] actually resolves as serviceable. Callers should show
  /// [unserviceableText] instead when [isServiceable] is false.
  String etaTextFor(String? city) {
    if (city != null) {
      final override = _cityEtaOverrides[city.toLowerCase()];
      if (override != null && override.trim().isNotEmpty) return override;
      for (final key in _cityEtaOverrides.keys) {
        if (city.toLowerCase().contains(key)) {
          final value = _cityEtaOverrides[key];
          if (value != null && value.trim().isNotEmpty) return value;
        }
      }
    }
    return _defaultEtaText;
  }

  String get unserviceableText => _unserviceableText;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

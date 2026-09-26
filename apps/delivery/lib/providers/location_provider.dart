// lib/providers/location_provider.dart
//
// Phase DLV-3A — the rider's location while online (D-DLV-BG).
//
// Before: a foreground-only position stream plus a 30 s Timer, so location
// stopped whenever the rider switched apps or locked the phone. Now the stream
// runs inside geolocator's Android foreground service ("You're online"
// notification), which keeps the process — and this provider's heartbeat —
// alive in the background. Each send writes:
//  - delivery_partners/{uid} currentLat/currentLng/lastLocationUpdate, which
//    dispatch reads (DLV-0 owner allowlist);
//  - delivery_tasks/{orderId}/live/rider while an order is active, which the
//    customer's map reads (firestore.rules, phaseDLV3A_live_rules_test).
// Cadence and payload rules live in lib/location/location_policy.dart.
//
// Phase DLV-3A2: on Android the sending moved to the native
// RiderLocationService (lib/location/rider_platform.dart), which survives the
// app being swiped away or killed (D-DLV-NATIVE-LOC). This provider then only
// starts/stops it and keeps an on-screen position for the UI — no uploads,
// no geolocator foreground service. The Dart uploader below remains for other
// platforms.
import '../app/device_localizations.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../location/location_policy.dart';
import '../location/rider_platform.dart';

class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  LocationProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  // late: deferred to first access, not construction. LocationProvider is
  // constructed well before any code path that actually needs Firestore
  // (setActiveOrders, the constructor itself) touches it; forcing it eager
  // meant the provider could never be constructed at all without a live
  // Firebase app, even for a passive read of unrelated state.
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  LocationIssue? _issue;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeat;
  String? _partnerId;
  // DLV-C1: every active order (normally one) gets the live point.
  List<String> _activeOrderIds = const [];
  TrackingProfile _profile = idleProfile;
  DateTime? _lastUploadAt;
  bool _hasUnsentFix = false;
  bool _uploading = false;
  bool _native = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  /// Why location is not working, for diagnostics (not shown to the rider:
  /// going online reports its own GoOnlineResult).
  LocationIssue? get issue => _issue;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  List<String> get activeOrderIds => _activeOrderIds;
  TrackingProfile get profile => _profile;
  DateTime? get lastUploadAt => _lastUploadAt;

  /// True when the native service does the sending (Android).
  bool get usesNativeService => _native;

  /// Whether the native service is running (it may be, with the app just
  /// reopened after being swiped away).
  Future<bool> nativeServiceRunning() => RiderPlatform.isRunning();

  /// The app was reopened while the native service kept sending (after a
  /// swipe from Recents): show the rider as online without restarting it.
  void attachToRunningService(String partnerId) {
    _partnerId = partnerId;
    _native = true;
    _isTracking = true;
    _startStream();
    notifyListeners();
  }

  // With the native service sending, the on-screen stream is only needed
  // while the app is visible.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_native || !_isTracking) return;
    if (state == AppLifecycleState.resumed) {
      if (_positionSubscription == null) _startStream();
    } else if (state == AppLifecycleState.paused) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }
  }

  /// Location services on and permission granted (asking if not yet asked).
  Future<GoOnlineResult> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setPermission(false, LocationIssue.servicesOff);
        return GoOnlineResult.servicesOff;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _setPermission(false, LocationIssue.deniedForever);
        return GoOnlineResult.permissionDeniedForever;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _setPermission(false, LocationIssue.denied);
        return GoOnlineResult.permissionDenied;
      }
      _setPermission(true, null);
      return GoOnlineResult.started;
    } catch (e) {
      debugPrint('Location permission check failed: $e');
      _setPermission(false, LocationIssue.checkFailed);
      return GoOnlineResult.failed;
    }
  }

  /// Whether tracking can start without asking anything (used to resume
  /// after the app was closed while online).
  Future<bool> canTrackWithoutPrompt() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (e) {
      debugPrint('Location permission check failed: $e');
      return false;
    }
  }

  /// Kept for existing callers: true when location can be used.
  Future<bool> checkPermissions() async =>
      await ensurePermission() == GoOnlineResult.started;

  void _setPermission(bool granted, LocationIssue? issue) {
    _hasPermission = granted;
    _issue = issue;
    notifyListeners();
  }

  /// Starts background tracking for [partnerId]. The caller shows the
  /// disclosure first (dashboard_screen.dart).
  Future<GoOnlineResult> startTracking(String partnerId) async {
    if (_isTracking && _partnerId == partnerId) return GoOnlineResult.started;
    final permission = await ensurePermission();
    if (permission != GoOnlineResult.started) return permission;
    _partnerId = partnerId;
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: DeliveryTiming.goOnlineFixTimeout,
        ),
      );
    } catch (e) {
      debugPrint('Initial fix failed: $e');
      _currentPosition = await Geolocator.getLastKnownPosition();
      if (_currentPosition == null) {
        _issue = LocationIssue.noFix;
        notifyListeners();
        return GoOnlineResult.failed;
      }
    }
    _hasUnsentFix = true;
    if (RiderPlatform.available) {
      // The caller has already set delivery_partners.isOnline true: the
      // service stops itself when the server says offline.
      if (!await RiderPlatform.start()) {
        _issue = LocationIssue.serviceStartFailed;
        notifyListeners();
        return GoOnlineResult.failed;
      }
      _native = true;
      _isTracking = true;
      _startStream();
      notifyListeners();
      return GoOnlineResult.started;
    }
    _native = false;
    _isTracking = true;
    _startStream();
    _startHeartbeat();
    await _maybeUpload(force: true);
    notifyListeners();
    return GoOnlineResult.started;
  }

  LocationSettings _settingsFor(TrackingProfile p) {
    if (_native) {
      // On-screen position only; the native service owns the foreground
      // service and the sending.
      return LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: p.distanceFilterMeters,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final notice = deviceLocalizations();
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: p.distanceFilterMeters,
        intervalDuration: p.streamInterval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notice.onlineNoticeTitle,
          notificationText: notice.onlineNoticeText,
          notificationChannelName: notice.onlineNoticeChannel,
          notificationIcon: AndroidResource(
              name: 'ic_stat_delivery_offer', defType: 'drawable'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: p.distanceFilterMeters,
    );
  }

  void _startStream() {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: _settingsFor(samplingProfile))
            .listen((position) {
      _currentPosition = position;
      _hasUnsentFix = true;
      notifyListeners();
      _maybeUpload();
    }, onError: (Object e) {
      // Location switched off mid-shift: keep the service; the heartbeat
      // re-sends the last fix and the rider sees the error.
      debugPrint('Position stream error: $e');
      _issue = LocationIssue.streamLost;
      notifyListeners();
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat =
        Timer.periodic(DeliveryTiming.uploadCheckInterval, (_) => _maybeUpload());
  }

  /// Switches cadence when an order starts or ends, and routes the live
  /// point to that order's task. The stream itself is NOT restarted: a
  /// restart cancels the foreground service, and Android 12+ refuses to start
  /// a location foreground service while the app is in the background
  /// (ForegroundServiceStartNotAllowedException, seen on the device run when
  /// an order was delivered with the screen off) — tracking would silently
  /// stop. The stream always samples at [samplingProfile]; the idle/order
  /// cadence is applied when deciding what to send.
  void setActiveOrders(List<String> orderIds) {
    if (listEquals(orderIds, _activeOrderIds)) return;
    _activeOrderIds = List.unmodifiable(orderIds);
    _profile = profileFor(onOrder: orderIds.isNotEmpty);
    if (_isTracking) _maybeUpload(force: true);
    notifyListeners();
  }

  Future<void> _maybeUpload({bool force = false}) async {
    if (_native) return; // RiderLocationService sends.
    final pos = _currentPosition;
    final uid = _partnerId;
    if (!_isTracking || pos == null || uid == null || _uploading) return;
    final now = DateTime.now();
    if (!force &&
        !shouldUpload(
            now: now,
            lastUploadAt: _lastUploadAt,
            hasNewFix: _hasUnsentFix,
            profile: _profile)) {
      return;
    }
    if (!isValidFix(pos.latitude, pos.longitude)) return;
    _uploading = true;
    try {
      await _firestore.collection('delivery_partners').doc(uid).update({
        'currentLat': pos.latitude,
        'currentLng': pos.longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
      _lastUploadAt = now;
      _hasUnsentFix = false;
      for (final orderId in _activeOrderIds) {
        try {
          await _firestore
              .collection('delivery_tasks')
              .doc(orderId)
              .collection('live')
              .doc('rider')
              .set({
            ...livePointFields(
              riderId: uid,
              lat: pos.latitude,
              lng: pos.longitude,
              accuracy: pos.accuracy,
              speed: pos.speed,
              heading: pos.heading,
              isMocked: pos.isMocked,
            ),
            'at': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // The task projection trails the order by a moment after accept,
          // and the rules refuse once the leg ends: not the rider's problem.
          debugPrint('Live point for $orderId not written: $e');
        }
      }
    } catch (e) {
      debugPrint('Error uploading location: $e');
    } finally {
      _uploading = false;
    }
  }

  /// Phase DLVMAP1: a rider-initiated refresh when the map shows the last
  /// position as stale. Only meaningful on the Dart-uploader path -- on
  /// native Android [usesNativeService] is true and RiderLocationService
  /// alone decides when to send, independent of this provider entirely, so
  /// this returns false immediately there rather than pretending to help
  /// (callers should offer "Check settings" instead when this is the case).
  /// A one-shot [Geolocator.getCurrentPosition] first, never a stream
  /// restart -- restarting cancels the foreground service and Android 12+
  /// then refuses to start a new one from the background.
  Future<bool> refreshNow() async {
    if (_native || !_isTracking) return false;
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: DeliveryTiming.goOnlineFixTimeout,
        ),
      );
      _hasUnsentFix = true;
      notifyListeners();
      await _maybeUpload(force: true);
      return true;
    } catch (e) {
      debugPrint('LocationProvider.refreshNow: $e');
      return false;
    }
  }

  /// Stops the stream, the foreground service and the heartbeat.
  void stopTracking() {
    if (RiderPlatform.available) RiderPlatform.stop();
    _native = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _isTracking = false;
    _lastUploadAt = null;
    notifyListeners();
  }

  // Update online status
  Future<void> setOnlineStatus(String partnerId, bool isOnline) async {
    try {
      debugPrint('🚚 Setting online status: $isOnline for partner: $partnerId');
      // Use set with merge to create doc if it doesn't exist
      await _firestore.collection('delivery_partners').doc(partnerId).set({
        'isOnline': isOnline,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Online status updated');
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Only this provider's own stream and timer: tearing down the widget
    // tree must never end the rider's shift — the native service stops on
    // Go offline, logout, or the server's say-so.
    _positionSubscription?.cancel();
    _heartbeat?.cancel();
    super.dispose();
  }
}

/// Why location is not working (LocationProvider.issue).
enum LocationIssue { servicesOff, denied, deniedForever, checkFailed, noFix, serviceStartFailed, streamLost }

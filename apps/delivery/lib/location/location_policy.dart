// lib/location/location_policy.dart
//
// Phase DLV-3A — when the rider app sends its location, and what it sends.
// Pure (no Firebase, no plugins) so test/location_policy_test.dart can pin it.
//
// D-DLV-BG: while online the app keeps sending from a foreground service. The
// server takes a rider offline after 15 min without a location
// (functions/src/delivery/riderPresence.ts SILENT_OFFLINE_MS) and dispatch
// ignores locations older than 5 min (dispatch.ts LOCATION_FRESHNESS_MS), so
// even a rider standing still re-sends on a heartbeat well inside both.

/// How often to sample and send, idle or on an order.
class TrackingProfile {
  const TrackingProfile({
    required this.name,
    required this.distanceFilterMeters,
    required this.streamInterval,
    required this.minUploadGap,
    required this.heartbeat,
  });

  final String name;

  /// The location stream reports a fix only after moving this far.
  final int distanceFilterMeters;

  /// Requested interval between fixes (Android).
  final Duration streamInterval;

  /// A new fix is sent no more often than this.
  final Duration minUploadGap;

  /// With no new fix (standing still), the last one is re-sent this often.
  final Duration heartbeat;
}

/// Online, no order: enough for dispatch to see the rider.
const TrackingProfile idleProfile = TrackingProfile(
  name: 'idle',
  distanceFilterMeters: 100,
  streamInterval: Duration(seconds: 30),
  minUploadGap: Duration(seconds: 30),
  heartbeat: Duration(seconds: 60),
);

/// On an order: the customer is watching the map.
const TrackingProfile taskProfile = TrackingProfile(
  name: 'task',
  distanceFilterMeters: 25,
  streamInterval: Duration(seconds: 5),
  minUploadGap: Duration(seconds: 10),
  heartbeat: Duration(seconds: 30),
);

TrackingProfile profileFor({required bool onOrder}) =>
    onOrder ? taskProfile : idleProfile;

/// What the location stream samples at, whatever the cadence: the finest
/// profile, because the stream is started once when the rider goes online
/// and never restarted (see LocationProvider.setActiveOrders).
const TrackingProfile samplingProfile = taskProfile;

/// Whether to send now: always the first time; a new fix once [minUploadGap]
/// has passed; otherwise on the [heartbeat].
bool shouldUpload({
  required DateTime now,
  required DateTime? lastUploadAt,
  required bool hasNewFix,
  required TrackingProfile profile,
}) {
  if (lastUploadAt == null) return true;
  final since = now.difference(lastUploadAt);
  if (hasNewFix && since >= profile.minUploadGap) return true;
  return since >= profile.heartbeat;
}

double? _inRange(double? v, double lo, double hi) =>
    v == null || v.isNaN || v < lo || v > hi ? null : v;

/// The fields of delivery_tasks/{orderId}/live/rider except `at` (the caller
/// adds a server timestamp). Values outside the bounds firestore.rules
/// enforces are dropped to null rather than failing the whole write:
/// Android reports heading -1 / speed -1 when it has none.
Map<String, Object?> livePointFields({
  required String riderId,
  required double lat,
  required double lng,
  double? accuracy,
  double? speed,
  double? heading,
  bool isMocked = false,
}) =>
    {
      'riderId': riderId,
      'lat': lat,
      'lng': lng,
      'accuracy': _inRange(accuracy, 0, 100000),
      'speed': _inRange(speed, 0, 100),
      'heading': _inRange(heading, 0, 360),
      'isMocked': isMocked,
    };

/// Whether a fix can be sent at all (the rules refuse anything else).
bool isValidFix(double lat, double lng) =>
    !lat.isNaN && !lng.isNaN && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

/// What going online needs from the rider, in order.
enum GoOnlineResult {
  started,
  disclosureDeclined,
  servicesOff,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

extension GoOnlineResultX on GoOnlineResult {
  /// What the rider is told when going online did not work; null on success
  /// or when they chose not to continue.
  String? get message => switch (this) {
        GoOnlineResult.started || GoOnlineResult.disclosureDeclined => null,
        GoOnlineResult.servicesOff =>
          'Turn on location (GPS) to go online.',
        GoOnlineResult.permissionDenied =>
          'Allow location access to go online. Orders are offered by distance.',
        GoOnlineResult.permissionDeniedForever =>
          'Location access is turned off for this app. Turn it on in Settings to go online.',
        GoOnlineResult.failed =>
          'Could not get your location. Move to an open area and try again.',
      };

  /// Whether the fix is in the phone's settings rather than a retry.
  bool get needsSettings =>
      this == GoOnlineResult.servicesOff ||
      this == GoOnlineResult.permissionDeniedForever;
}

/// Why the server took the rider offline (delivery_partners.offlineReason).
String? serverOfflineMessage(String? reason) => switch (reason) {
      'no_location' =>
        "You're offline — your location stopped for 15 minutes. Go online again when you're ready.",
      _ => null,
    };

/// The prominent disclosure shown once, before the location permission
/// prompt (Google Play policy for location used while the app is closed).
const String locationDisclosureTitle = 'Your location while you are online';
const String locationDisclosureBody =
    'While you are online, Agrimore Delivery collects your location — also '
    'when the app is closed or not in use — to offer you nearby orders and '
    'to show customers where their delivery is. A notification shows while '
    'this is on. It stops as soon as you go offline.';

/// Phase DLV-3A2 (D-DLV-BGLOC-ALWAYS) — the 'Allow all the time' step.
const String backgroundLocationTitle = 'Keep deliveries working when the app closes';
const String backgroundLocationBody =
    'Your phone sometimes closes apps to save memory. To keep sharing your '
    'location while you are online even then, choose "Allow all the time" '
    'on the next screen. It still stops as soon as you go offline.';

/// Shown after going online when 'Allow all the time' was not given.
const String backgroundLocationReminder =
    'You are online. If your phone closes the app, location sharing stops '
    'and you go offline — allow location "all the time" in Settings to avoid this.';

/// Phase DLV-3A2 (D-DLV-BATTERY) — the one-time battery guide.
const String batteryGuideTitle = 'Stop your phone closing the app';
const String batteryGuideBody =
    'Some phones close apps in the background to save battery, which takes '
    'you offline. In the app settings that open next, set Battery to '
    '"Unrestricted" (or "No restrictions"). On Xiaomi, Oppo, Vivo and Realme '
    'phones also turn on "Autostart".';

/// Delivery-domain time limits shared by the rider app (not presentation
/// motion — see agrimore_ui WsMotion for animation durations).
///
/// The first group mirrors server constants and is pinned against
/// test/fixtures/delivery_status_table.json `timing` by BOTH
/// test/delivery/delivery_enums_test.dart and
/// functions/scripts/phaseDLV1A_delivery_states_test.js.
abstract final class DeliveryTiming {
  DeliveryTiming._();

  // ── mirrored from the server ──

  /// How long a delivery offer stays open (dispatch.ts OFFER_TTL_MS).
  static const Duration offerLifetime = Duration(seconds: 30);

  /// A rider silent this long is taken offline (riderPresence.ts SILENT_OFFLINE_MS).
  static const Duration riderSilentOffline = Duration(minutes: 15);

  /// Dispatch ignores a location older than this (dispatch.ts LOCATION_FRESHNESS_MS).
  static const Duration dispatchLocationFreshness = Duration(minutes: 5);

  // ── how often the rider app sends its location (D-DLV-BG) ──
  // Every heartbeat is well inside [dispatchLocationFreshness], so a rider
  // standing still is still offered orders and never swept offline.

  /// Online with no order: enough for dispatch to see the rider.
  static const Duration idleStreamInterval = Duration(seconds: 30);
  static const Duration idleMinUploadGap = Duration(seconds: 30);
  static const Duration idleHeartbeat = Duration(minutes: 1);

  /// On an order: the customer is watching the map.
  static const Duration taskStreamInterval = Duration(seconds: 5);
  static const Duration taskMinUploadGap = Duration(seconds: 10);
  static const Duration taskHeartbeat = Duration(seconds: 30);

  /// How often the app checks whether a heartbeat upload is due.
  static const Duration uploadCheckInterval = Duration(seconds: 5);

  // ── waits for a GPS fix ──

  /// How long a safety or problem report waits for a GPS fix before it is
  /// sent without one: a report must never be held up by location.
  static const Duration reportFixTimeout = Duration(seconds: 5);

  /// The platform fix request inside [reportFixTimeout] — shorter, so the
  /// request itself ends before the report stops waiting.
  static const Duration reportFixRequestLimit = Duration(seconds: 4);

  /// A step (arrived, picked up, delivered) waits this long for the fix that
  /// the server's geofence flag is computed from.
  static const Duration stepFixTimeout = Duration(seconds: 6);

  /// The first fix when the rider goes online.
  static const Duration goOnlineFixTimeout = Duration(seconds: 20);

  // ── calls and sessions ──

  /// A safety report call gives up after this (the rider can then dial).
  static const Duration incidentCallTimeout = Duration(seconds: 20);

  /// After sign-in, how long to wait for the rider's account to load.
  static const Duration signInAccountWait = Duration(seconds: 30);

  // ── offers on the device ──

  /// An offer is removed just after its expiry, never just before.
  static const Duration offerExpirySlack = Duration(milliseconds: 50);

  /// Android posts the server's offer notification itself; the ringing alert
  /// replaces it after this, so a late system copy cannot overwrite the ring.
  static const Duration offerAlertReplaceDelay = Duration(milliseconds: 800);
}

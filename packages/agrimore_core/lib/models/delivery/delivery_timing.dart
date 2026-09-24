/// Delivery-domain time limits shared by the rider app (not presentation
/// motion — see agrimore_ui WsMotion for animation durations).
abstract final class DeliveryTiming {
  DeliveryTiming._();

  /// How long a safety or problem report waits for a GPS fix before it is
  /// sent without one: a report must never be held up by location.
  static const Duration reportFixTimeout = Duration(seconds: 5);
}

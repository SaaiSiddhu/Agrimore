/// One foreground SDK operation per account across native payment purposes.
/// The server still owns financial idempotency and cross-device consumption.
class NativePaymentFlight {
  static final Map<String, Object> _held = {};
  static bool acquire(String ownerId, Object controller) {
    final current = _held[ownerId];
    if (current != null && !identical(current, controller)) return false;
    _held[ownerId] = controller;
    return true;
  }

  static void release(String ownerId, Object controller) {
    if (identical(_held[ownerId], controller)) _held.remove(ownerId);
  }
}

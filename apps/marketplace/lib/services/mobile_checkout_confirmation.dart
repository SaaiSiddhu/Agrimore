import 'package:agrimore_core/agrimore_core.dart';

import 'checkout_recovery_service.dart';
import 'mobile_checkout_flow.dart';

/// Fetch the original server receipt before changing a cart or leaving checkout.
/// Callbacks are screen-owned; every async boundary rechecks that same session.
Future<void> finishMobileCheckout({
  required PendingCheckoutRequest request,
  required List<CheckoutReceipt> receipts,
  required bool Function() isMounted,
  required String? Function() currentUserId,
  required Future<Map<String, dynamic>?> Function(String id) readOrder,
  required List<CartItemModel> Function() currentItems,
  required String Function() currentMode,
  required Future<bool> Function() clearCart,
  required void Function() clearCoupon,
  required void Function() clearSubscriptionHint,
  required Future<void> Function(PendingCheckoutRequest) acknowledge,
  required void Function(OrderModel) showOrder,
}) async {
  void checkSession() {
    if (!isMounted() || currentUserId() != request.ownerId) {
      throw StateError('Checkout session changed.');
    }
  }

  checkSession();
  if (receipts.isEmpty || request.stage != 'completed') {
    throw StateError('Order confirmation is unavailable.');
  }
  final receipt = receipts.first;
  final data = await readOrder(receipt.orderId);
  checkSession();
  if (data == null) throw StateError('Order details are unavailable.');
  final order = orderFromCheckoutReceipt(receipt, request.ownerId, data);
  if (checkoutMatchesCart(request, currentItems(), currentMode())) {
    if (!await clearCart()) throw StateError('Cart update needs attention.');
    checkSession();
    clearCoupon();
    checkSession();
    clearSubscriptionHint();
    checkSession();
  }
  await acknowledge(request);
  checkSession();
  showOrder(order);
}

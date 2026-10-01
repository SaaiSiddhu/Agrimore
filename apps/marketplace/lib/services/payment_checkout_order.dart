/// Only generic marketplace payments use these purposes. Activation fees
/// continue to use their dedicated server-created orders on the web.
enum CheckoutPaymentPurpose {
  goods('goods_checkout'),
  walletTopup('wallet_topup'),
  rfq('rfq_checkout');

  const CheckoutPaymentPurpose(this.value);
  final String value;
}

/// Validated public order metadata. The server's integer amount goes directly
/// to the SDK; converting it through rupees can lose a paise (e.g. 29).
class PaymentCheckoutOrder {
  const PaymentCheckoutOrder._(
      this.orderId, this.keyId, this.amountPaise, this.isTestMode);

  final String orderId;
  final String keyId;
  final int amountPaise;
  final bool isTestMode;

  factory PaymentCheckoutOrder.fromResponse(Map<String, dynamic> data) {
    final orderId = data['orderId'];
    final keyId = data['keyId'];
    final amount = data['amount'];
    if (data['success'] != true ||
        orderId is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(orderId) ||
        keyId is! String ||
        !RegExp(r'^rzp_(live|test)_[A-Za-z0-9_]{1,128}$').hasMatch(keyId) ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 9007199254740991 ||
        amount != amount.truncateToDouble() ||
        data['currency'] != 'INR') {
      throw const FormatException(
          'Payment order is unavailable. Please try again.');
    }
    return PaymentCheckoutOrder._(
        orderId, keyId, amount.toInt(), data['isTestMode'] == true);
  }
}

// Stub file for Web platform
// Provides dummy classes for razorpay_flutter so Web compilation succeeds

class Razorpay {
  static const String EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const String EVENT_PAYMENT_ERROR = 'payment.error';
  static const String EVENT_EXTERNAL_WALLET = 'payment.wallet';

  void on(String event, Function handler) {}
  void clear() {}
  void open(Map<String, dynamic> options) {}
}

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  PaymentSuccessResponse(this.paymentId, this.orderId, this.signature);
}

class PaymentFailureResponse {
  final int? code;
  final String? message;
  PaymentFailureResponse(this.code, this.message);
}

class ExternalWalletResponse {
  final String? walletName;
  ExternalWalletResponse(this.walletName);
}

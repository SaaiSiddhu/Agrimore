import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Get analytics observer for navigation
  FirebaseAnalyticsObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  // Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  // Log user login
  Future<void> logLogin({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // Log user signup
  Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  // Log product view
  Future<void> logViewProduct({
    required String productId,
    required String productName,
    required String category,
    required double price,
  }) async {
    await _analytics.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          itemCategory: category,
          price: price,
        ),
      ],
    );
  }

  // Log add to cart
  Future<void> logAddToCart({
    required String productId,
    required String productName,
    required String category,
    required double price,
    required int quantity,
  }) async {
    await _analytics.logAddToCart(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          itemCategory: category,
          price: price,
          quantity: quantity,
        ),
      ],
      value: price * quantity,
    );
  }

  // Log remove from cart
  Future<void> logRemoveFromCart({
    required String productId,
    required String productName,
    required double price,
  }) async {
    await _analytics.logRemoveFromCart(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          price: price,
        ),
      ],
    );
  }

  // Log add to wishlist
  Future<void> logAddToWishlist({
    required String productId,
    required String productName,
    required double price,
  }) async {
    await _analytics.logAddToWishlist(
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productName,
          price: price,
        ),
      ],
    );
  }

  // Log begin checkout
  Future<void> logBeginCheckout({
    required double value,
    required String currency,
    required List<AnalyticsEventItem> items,
  }) async {
    await _analytics.logBeginCheckout(
      value: value,
      currency: currency,
      items: items,
    );
  }

  // Log purchase
  Future<void> logPurchase({
    required String transactionId,
    required double value,
    required String currency,
    required double tax,
    required double shipping,
    required List<AnalyticsEventItem> items,
    String? coupon,
  }) async {
    await _analytics.logPurchase(
      transactionId: transactionId,
      value: value,
      currency: currency,
      tax: tax,
      shipping: shipping,
      items: items,
      coupon: coupon,
    );
  }

  // Log search
  Future<void> logSearch({required String searchTerm}) async {
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  // Log share
  Future<void> logShare({
    required String contentType,
    required String itemId,
    required String method,
  }) async {
    await _analytics.logShare(
      contentType: contentType,
      itemId: itemId,
      method: method,
    );
  }

  // Log custom event
  Future<void> logCustomEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  // Set user ID
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  // Set user property
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // Log app open
  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  // Log tutorial begin
  Future<void> logTutorialBegin() async {
    await _analytics.logTutorialBegin();
  }

  // Log tutorial complete
  Future<void> logTutorialComplete() async {
    await _analytics.logTutorialComplete();
  }
}

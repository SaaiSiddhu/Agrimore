class ApiConstants {
  // Base URLs
  static const String baseUrl = 'https://api.agrimore.com';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion';

  // Authentication Endpoints
  static const String loginEndpoint = '$apiBaseUrl/auth/login';
  static const String registerEndpoint = '$apiBaseUrl/auth/register';
  static const String logoutEndpoint = '$apiBaseUrl/auth/logout';
  static const String refreshTokenEndpoint = '$apiBaseUrl/auth/refresh';
  static const String forgotPasswordEndpoint = '$apiBaseUrl/auth/forgot-password';
  static const String resetPasswordEndpoint = '$apiBaseUrl/auth/reset-password';
  static const String verifyEmailEndpoint = '$apiBaseUrl/auth/verify-email';

  // User Endpoints
  static const String userProfileEndpoint = '$apiBaseUrl/user/profile';
  static const String updateProfileEndpoint = '$apiBaseUrl/user/update';
  static const String changePasswordEndpoint = '$apiBaseUrl/user/change-password';
  static const String deleteAccountEndpoint = '$apiBaseUrl/user/delete';

  // Product Endpoints
  static const String productsEndpoint = '$apiBaseUrl/products';
  static const String productDetailEndpoint = '$apiBaseUrl/products/{id}';
  static const String featuredProductsEndpoint = '$apiBaseUrl/products/featured';
  static const String searchProductsEndpoint = '$apiBaseUrl/products/search';
  static const String categoryProductsEndpoint = '$apiBaseUrl/products/category/{id}';

  // Category Endpoints
  static const String categoriesEndpoint = '$apiBaseUrl/categories';
  static const String categoryDetailEndpoint = '$apiBaseUrl/categories/{id}';

  // Cart Endpoints
  static const String cartEndpoint = '$apiBaseUrl/cart';
  static const String addToCartEndpoint = '$apiBaseUrl/cart/add';
  static const String updateCartEndpoint = '$apiBaseUrl/cart/update';
  static const String removeFromCartEndpoint = '$apiBaseUrl/cart/remove';
  static const String clearCartEndpoint = '$apiBaseUrl/cart/clear';

  // Wishlist Endpoints
  static const String wishlistEndpoint = '$apiBaseUrl/wishlist';
  static const String addToWishlistEndpoint = '$apiBaseUrl/wishlist/add';
  static const String removeFromWishlistEndpoint = '$apiBaseUrl/wishlist/remove';

  // Order Endpoints
  static const String ordersEndpoint = '$apiBaseUrl/orders';
  static const String createOrderEndpoint = '$apiBaseUrl/orders/create';
  static const String orderDetailEndpoint = '$apiBaseUrl/orders/{id}';
  static const String cancelOrderEndpoint = '$apiBaseUrl/orders/{id}/cancel';
  static const String orderHistoryEndpoint = '$apiBaseUrl/orders/history';
  static const String trackOrderEndpoint = '$apiBaseUrl/orders/{id}/track';

  // Address Endpoints
  static const String addressesEndpoint = '$apiBaseUrl/addresses';
  static const String addAddressEndpoint = '$apiBaseUrl/addresses/add';
  static const String updateAddressEndpoint = '$apiBaseUrl/addresses/{id}/update';
  static const String deleteAddressEndpoint = '$apiBaseUrl/addresses/{id}/delete';
  static const String setDefaultAddressEndpoint = '$apiBaseUrl/addresses/{id}/set-default';

  // Payment Endpoints
  static const String paymentMethodsEndpoint = '$apiBaseUrl/payment/methods';
  static const String createPaymentEndpoint = '$apiBaseUrl/payment/create';
  static const String verifyPaymentEndpoint = '$apiBaseUrl/payment/verify';
  static const String paymentStatusEndpoint = '$apiBaseUrl/payment/{id}/status';
  static const String razorpayOrderEndpoint = '$apiBaseUrl/payment/razorpay/order';
  static const String razorpayVerifyEndpoint = '$apiBaseUrl/payment/razorpay/verify';

  // Coupon Endpoints
  static const String couponsEndpoint = '$apiBaseUrl/coupons';
  static const String applyCouponEndpoint = '$apiBaseUrl/coupons/apply';
  static const String validateCouponEndpoint = '$apiBaseUrl/coupons/validate';
  static const String removeCouponEndpoint = '$apiBaseUrl/coupons/remove';

  // Review Endpoints
  static const String reviewsEndpoint = '$apiBaseUrl/reviews';
  static const String productReviewsEndpoint = '$apiBaseUrl/reviews/product/{id}';
  static const String addReviewEndpoint = '$apiBaseUrl/reviews/add';
  static const String updateReviewEndpoint = '$apiBaseUrl/reviews/{id}/update';
  static const String deleteReviewEndpoint = '$apiBaseUrl/reviews/{id}/delete';

  // Notification Endpoints
  static const String notificationsEndpoint = '$apiBaseUrl/notifications';
  static const String markNotificationReadEndpoint = '$apiBaseUrl/notifications/{id}/read';
  static const String markAllReadEndpoint = '$apiBaseUrl/notifications/read-all';
  static const String deleteNotificationEndpoint = '$apiBaseUrl/notifications/{id}/delete';

  // Admin Endpoints
  static const String adminDashboardEndpoint = '$apiBaseUrl/admin/dashboard';
  static const String adminUsersEndpoint = '$apiBaseUrl/admin/users';
  static const String adminProductsEndpoint = '$apiBaseUrl/admin/products';
  static const String adminOrdersEndpoint = '$apiBaseUrl/admin/orders';
  static const String adminAnalyticsEndpoint = '$apiBaseUrl/admin/analytics';
  static const String adminSettingsEndpoint = '$apiBaseUrl/admin/settings';

  // Upload Endpoints
  static const String uploadImageEndpoint = '$apiBaseUrl/upload/image';
  static const String uploadMultipleImagesEndpoint = '$apiBaseUrl/upload/images';

  // Other Endpoints
  static const String bannerEndpoint = '$apiBaseUrl/banners';
  static const String settingsEndpoint = '$apiBaseUrl/settings';
  static const String contactEndpoint = '$apiBaseUrl/contact';
  static const String feedbackEndpoint = '$apiBaseUrl/feedback';

  // HTTP Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> headersWithAuth(String token) {
    return {
      ...headers,
      'Authorization': 'Bearer $token',
    };
  }

  // Request Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Image Sizes
  static const String thumbnailSize = '200x200';
  static const String mediumSize = '600x600';
  static const String largeSize = '1200x1200';

  // Helper method to replace path parameters
  static String replacePath(String endpoint, String key, String value) {
    return endpoint.replaceAll('{$key}', value);
  }

  // Build query parameters
  static String buildQueryParams(Map<String, dynamic> params) {
    if (params.isEmpty) return '';
    
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    
    return '?$queryString';
  }

  // Build full URL with query params
  static String buildUrl(String endpoint, [Map<String, dynamic>? queryParams]) {
    if (queryParams == null || queryParams.isEmpty) {
      return endpoint;
    }
    return endpoint + buildQueryParams(queryParams);
  }
}

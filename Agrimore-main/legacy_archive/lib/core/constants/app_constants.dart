class AppConstants {
  // App Info
  static const String appName = 'Agrimore';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Agricultural Marketplace';
  
  // Pagination
  static const int productsPerPage = 20;
  static const int ordersPerPage = 15;
  static const int reviewsPerPage = 10;
  
  // Image Sizes
  static const int thumbnailSize = 300;
  static const int mediumImageSize = 600;
  static const int largeImageSize = 1200;
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 24);
  
  // Limits
  static const int maxImageUpload = 5;
  static const int maxCartItems = 50;
  static const int maxWishlistItems = 100;
  static const int minPasswordLength = 8;
  static const int maxProductNameLength = 100;
  static const int maxProductDescLength = 1000;
  
  // Delivery
  static const double minOrderAmount = 100.0;
  static const double freeDeliveryThreshold = 500.0;
  static const double deliveryCharge = 50.0;
  
  // Currency
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  
  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  
  // Support
  static const String supportEmail = 'support@agroconnect.com';
  static const String supportPhone = '+91 9876543210';
  
  // Social Media
  static const String facebookUrl = 'https://facebook.com/agroconnect';
  static const String instagramUrl = 'https://instagram.com/agroconnect';
  static const String twitterUrl = 'https://twitter.com/agroconnect';
  
  // Policies
  static const String privacyPolicyUrl = 'https://agroconnect.com/privacy';
  static const String termsUrl = 'https://agroconnect.com/terms';
  static const String returnPolicyUrl = 'https://agroconnect.com/returns';
}

class FirebaseConstants {
  // Collections
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';
  static const String ordersCollection = 'orders';
  static const String cartsCollection = 'carts';
  static const String wishlistsCollection = 'wishlists';
  static const String addressesCollection = 'addresses';
  static const String couponsCollection = 'coupons';
  static const String reviewsCollection = 'reviews';
  static const String bannersCollection = 'banners';
  static const String notificationsCollection = 'notifications';
  static const String settingsCollection = 'settings';
  
  // Storage Paths
  static const String productsStorage = 'products';
  static const String usersStorage = 'users';
  static const String bannersStorage = 'banners';
  static const String categoriesStorage = 'categories';
  
  // Settings Documents
  static const String paymentSettings = 'payment';
  static const String deliverySettings = 'delivery';
  static const String appSettings = 'app';
  
  // User Fields
  static const String userRole = 'role';
  static const String userRoleAdmin = 'admin';
  static const String userRoleUser = 'user';
  
  // Order Fields
  static const String orderStatus = 'status';
  static const String orderCreatedAt = 'createdAt';
  static const String orderUserId = 'userId';
  
  // Product Fields
  static const String productIsActive = 'isActive';
  static const String productCategory = 'category';
  static const String productStock = 'stock';
  static const String productCreatedAt = 'createdAt';
}

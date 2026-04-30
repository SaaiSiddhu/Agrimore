/// Agrimore Services Package
/// 
/// Contains Firebase services, API clients, and business logic services
/// shared across all Agrimore applications.
library agrimore_services;

// Re-export core package for convenience
export 'package:agrimore_core/agrimore_core.dart';

// ============================================
// AUTHENTICATION
// ============================================
export 'auth/auth_service.dart';

// ============================================
// DATABASE
// ============================================
export 'database/database_service.dart';
export 'database/firestore_data_service.dart';
export 'settings/delivery_slot_service.dart';

// ============================================
// STORAGE
// ============================================
export 'storage/storage_service.dart';

// ============================================
// NOTIFICATIONS
// ============================================
export 'notifications/notification_service.dart';
export 'notifications/fcm_service.dart';

// ============================================
// ANALYTICS
// ============================================
export 'analytics/analytics_service.dart';

// ============================================
// PAYMENT
// ============================================
export 'payment/payment_service.dart';
export 'payment/custom_payment_service.dart';

// ============================================
// LOCATION
// ============================================
export 'location/location_service.dart';

// ============================================
// AI
// ============================================
export 'ai/ai_chat_service.dart';

// ============================================
// ADMIN
// ============================================
export 'admin/admin_service.dart';
export 'admin/vendor_service.dart';

// ============================================
// ORDERS
// ============================================
export 'orders/order_service.dart';

// ============================================
// DEEP LINKING
// ============================================
export 'deep_link/deep_link_service.dart';

// ============================================
// LOCAL STORAGE
// ============================================
export 'local/shared_preferences_service.dart';

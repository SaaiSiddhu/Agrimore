// ============================================================
//  AGRIMORE FIREBASE CLOUD FUNCTIONS  —  FULL VERSION
// ============================================================

import * as admin from "firebase-admin";

// Initialize only if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// ============================================
// COMMON MODULE
// ============================================
export { sendEmailOTP } from "./common/sendEmailOTP";
export { verifyEmailOTP } from "./common/verifyEmailOTP";
export { cleanupInvalidTokens } from "./common/scheduled";

// ============================================
// ADMIN MODULE
// ============================================
export {
  sendBroadcastNotification,
  sendNotificationToUser,
  sendOrderUpdateNotification,
  getNotificationStats,
  onOrderStatusChanged
} from "./admin/notifications";
export { createSellerByAdmin } from "./admin/createSellerByAdmin";

// ============================================
// CUSTOMER MODULE
// ============================================
export {
  createRazorpayOrder,
  verifyRazorpayPayment
} from "./customer/payment";
export { splitCartIntoOrders } from "./customer/cartSplitting";

// ============================================
// INVENTORY & STOCK ALERTS
// ============================================
export {
  onProductStockChanged,
  setLowStockThreshold
} from "./customer/inventory";

// ============================================
// SELLER NOTIFICATIONS & PAYOUTS
// ============================================
export {
  notifySellerNewOrder,
  calculateSellerPayout
} from "./customer/sellerNotifications";

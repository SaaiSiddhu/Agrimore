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
export { sendPhoneOTP } from "./common/sendPhoneOTP";
export { verifyPhoneOTP } from "./common/verifyPhoneOTP";
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
export { createEmployeeByAdmin } from "./admin/createEmployeeByAdmin";
export {
  refreshUserRoleClaims,
  syncDeliveryRoleClaims,
  syncSellerRoleClaims,
  syncUserRoleClaims,
  syncEmployeeRoleClaims
} from "./admin/roleClaims";

// ============================================
// CUSTOMER MODULE
// ============================================
export {
  createRazorpayOrder,
  verifyRazorpayPayment
} from "./customer/payment";
export { splitCartIntoOrders } from "./customer/cartSplitting";
export { createOrder } from "./customer/createOrder";
export { onOrderCreatedNotifications } from "./customer/orderNotifications";

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

// ============================================
// EMPLOYEE COMMISSION (B2B)
// ============================================
export { payEmployeeCommissionOnDelivery } from "./customer/employeeCommission";
export { requestEmployeePayout } from "./customer/requestEmployeePayout";

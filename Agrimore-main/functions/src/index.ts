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
// Phase 15, Workstream 3b: the only supported way to promote/demote a user's
// role now that Phase 14 made users/{uid}.role unwritable by a non-admin
// client — see setUserRole.ts's header comment.
export { setUserRole } from "./admin/setUserRole";
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
// Phase 14, Workstream 5: splitCartIntoOrders removed (the file it lived in,
// customer/cartSplitting.ts, is deleted too). It accepted a client-supplied
// item `price`, performed no product lookup/payment verification/stock
// check, and wrote orders via the Admin SDK (bypassing firestore.rules'
// `orders` create:false entirely). Zero callers anywhere in apps/ or
// packages/ (grepped) — it was dead client-side but live and callable in
// production. Removing this export does NOT remove the already-deployed
// function — the owner must also run
// `firebase functions:delete splitCartIntoOrders`.
export { createOrder } from "./customer/createOrder";
export { onOrderCreatedNotifications } from "./customer/orderNotifications";
// Phase 16, Workstream 4: server-authoritative profile completion — see
// completeUserProfile.ts's header comment for the new-vs-existing-user
// distinction this relies on, and verifyEmailForProfile.ts's header for why
// it does NOT reuse verifyEmailOTP.ts (which mints a competing Auth
// identity keyed by email — wrong shape for a phone-authenticated caller
// proving they own an email address).
export { completeUserProfile } from "./customer/completeUserProfile";
export { verifyEmailForProfile } from "./customer/verifyEmailForProfile";

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

// ============================================
// WALLET HARDENING (Finding #3)
// ============================================
export { verifyWalletTopup, redeemReferralCode, creditSignupBonus } from "./customer/wallet";

// ============================================
// CUSTOMER PRODUCT BENEFIT PROGRAM — COMPLIANCE GATE (Phase A)
// ============================================
// The only way to change feature_flags/benefit_program or
// compliance_config/{programId} — both are write:false in firestore.rules
// for every client. See admin/complianceGate.ts's header comment for why
// this gate exists. assertProgramLaunchable() is intentionally NOT
// exported here (it has no callers yet; Phase B imports it directly from
// admin/complianceGate.ts).
export { setBenefitFeatureFlag, setComplianceStatus } from "./admin/complianceGate";

// ============================================
// CUSTOMER PRODUCT BENEFIT PROGRAM — LEDGER & ACCRUAL ENGINE (Phase B)
// ============================================
// Backend only: program config, enrollment records, the immutable
// product_credit_ledger, and the accrual/expiry/reconciliation jobs that
// write it. No redemption, no money movement — see
// customer/productCreditLedger.ts and admin/benefitEnrollment.ts's header
// comments. Every state-changing callable here calls
// admin/complianceGate.ts's assertProgramLaunchable() and refuses to run
// when it returns false.
export { setBenefitProgramConfig } from "./admin/benefitProgramConfig";
export { createBenefitEnrollment, setEnrollmentStatus } from "./admin/benefitEnrollment";
export { accrueMonthlyBenefits, runBenefitAccrualNow } from "./customer/benefitAccrual";
export { expireProductCredits, reconcileProductCreditBalances } from "./customer/productCreditExpiry";

// ============================================
// ASSOCIATE ONBOARDING (Phase 16A — ₹500 one-time Registration &
// Onboarding Fee). User-facing strings say "Sales Associate"; every
// internal identifier (the `employee` role, `employees` collection,
// EmployeeModel) stays unchanged — see employee/associateTerm.ts.
// ============================================
export { getAssociateOnboardingConfig } from "./employee/getAssociateOnboardingConfig";
export { createAssociateOnboardingPayment } from "./employee/createAssociateOnboardingPayment";
export { activateAssociateOnboarding } from "./employee/activateAssociateOnboarding";
export { razorpayOnboardingWebhook } from "./employee/razorpayOnboardingWebhook";
export { reconcileStaleOnboardingPayments } from "./employee/reconcileStaleOnboardingPayments";
export {
  waiveAssociateOnboardingFee,
  recordAssociateOnboardingRefund,
  requestAssociateOnboardingRefundOnSuspend,
} from "./employee/adminOnboardingActions";

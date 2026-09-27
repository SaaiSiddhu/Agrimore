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
// ADMR-24: canonical, server-authorized, audited, idempotent replacement
// for admin's own direct orders/{orderId}.orderStatus client write.
export { adminUpdateOrderStatus } from "./admin/adminOrderActions";
// ADMR-37: the sole path that resolves a delivered→cancelled order's
// deferred `stockRestorePending` flag (see restoreStockOnCancellation.ts).
export { confirmOrderReturnReceived } from "./admin/confirmOrderReturnReceived";
export {
  refreshUserRoleClaims,
  syncDeliveryRoleClaims,
  syncSellerRoleClaims,
  syncUserRoleClaims,
  syncEmployeeRoleClaims
} from "./admin/roleClaims";
// ADMR-61: unified admin support cases -- the investigation layer, never
// a competing source of truth for rider_support_tickets/rider_incidents/
// delivery_exceptions, which keep their own statuses authoritative.
export {
  createSupportCase,
  assignSupportCase,
  changeSupportCaseStatus,
  addSupportCaseNote,
  resolveSupportCase,
  reopenSupportCase,
} from "./admin/supportCases";

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
// Phase RFQ-3: converts an accepted rfqs/{rfqId} into a real order at its
// locked finalPrice/finalQuantity. NEW export — does not exist on
// agrimore-66a4e yet.
export { createOrderFromRfq } from "./customer/createOrderFromRfq";
// Phase FIX-5 (finding N-5, P1): server-side delivery verification. NEW export —
// this function does not exist on agrimore-66a4e yet, so the owner deploy is a
// CREATE, not an update. It does NOT close N-5 on its own: the direct status
// write the delivery client uses today is still permitted by the rules until
// phase FIX-5B tightens them, which must wait for a released client that uses
// this callable (B2B_PHASE_SEQUENCING).
export { confirmDelivery } from "./customer/confirmDelivery";
export { onOrderCreatedNotifications } from "./customer/orderNotifications";
// Phase 16, Workstream 4: server-authoritative profile completion — see
// completeUserProfile.ts's header comment for the new-vs-existing-user
// distinction this relies on, and verifyEmailForProfile.ts's header for why
// it does NOT reuse verifyEmailOTP.ts (which mints a competing Auth
// identity keyed by email — wrong shape for a phone-authenticated caller
// proving they own an email address).
export { completeUserProfile } from "./customer/completeUserProfile";
export { verifyEmailForProfile } from "./customer/verifyEmailForProfile";
// The post-completion "change my email/phone" path completeUserProfile.ts's
// own comment says is out of its scope — see each file's header comment for
// why neither reuses its corresponding login-purpose OTP endpoint.
export { changeEmailAddress } from "./customer/changeEmailAddress";
export { changePhoneNumber } from "./customer/changePhoneNumber";
// PROFILE-8: dateOfBirth's own post-completion change path — firestore.rules
// blanket-blocks a client write to this field regardless of value (Phase 16
// Workstream 5), so unlike gender (a plain owner-writable field, no callable
// needed) DOB needs this same Admin-SDK-bypasses-rules shape.
export { changeDateOfBirth } from "./customer/changeDateOfBirth";
export { verifyAssociateCode } from "./customer/verifyAssociateCode";
// AUTH-3: looks up whether a Google identity is already linked to an
// existing AgriMore account, with no Firebase Auth context required —
// see the file's own header comment for why this must be unauthenticated.
export { resolveGoogleIdentity } from "./customer/resolveGoogleIdentity";

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
// BUSINESS NETWORK — FOLLOW NOTIFICATIONS (Phase BUSINESS-NETWORK-1)
// ============================================
export { notifyFollowersOnNewProduct } from "./customer/sellerFollowNotifications";

// ============================================
// EMPLOYEE COMMISSION (B2B)
// ============================================
export {
  payEmployeeCommissionOnDelivery,
  reverseEmployeeCommissionOnCancellation,
  retryCommissionException,
} from "./customer/employeeCommission";
export { requestEmployeePayout } from "./customer/requestEmployeePayout";
// Phase ADMR-3: the only path for an admin to review a payout request —
// replaces employee_payout_detail_screen.dart's two direct Firestore writes,
// one of which (reject) had always failed outright, the other of which
// (paid) silently discarded any entered payment reference. See
// customer/reviewEmployeePayout.ts's header for the full rationale.
export { markEmployeePayoutPaid, rejectEmployeePayout } from "./customer/reviewEmployeePayout";
// Phase ADMR-5: an associate's own bank/UPI change request-review workflow —
// see employee/employeePayoutAccount.ts's header for the full rationale.
export {
  requestEmployeePayoutChange,
  cancelEmployeePayoutChange,
  reviewEmployeePayoutChange,
} from "./employee/employeePayoutAccount";
export { deleteUserData } from "./customer/deleteUserData";

// ============================================
// WALLET HARDENING (Finding #3)
// ============================================
export {
  verifyWalletTopup,
  redeemReferralCode,
  creditSignupBonus,
  completeReferralOnFirstDelivery,
  assignReferralCode,
} from "./customer/wallet";

// ============================================
// SCRATCH CARD CLAIM — server-side crediting (Phase FIX-N50, closes N-50)
// ============================================
export { claimScratchCard } from "./customer/claimScratchCard";

// ============================================
// AI MARKETPLACE ASSISTANT — WALLET-GATED BYO KEY CONNECTION (Phase AI-1)
// ============================================
export { connectAiProvider, disconnectAiProvider } from "./customer/aiConnection";

// ============================================
// AI MARKETPLACE ASSISTANT — GEMINI CHAT PROXY (Phase AI-2)
// ============================================
export { aiChatProxy } from "./customer/aiChatProxy";

// ============================================
// AI MARKETPLACE ASSISTANT — SELLER FUNDING + CONNECTION (Phase AI-4)
// ============================================
export { createSellerAiActivationOrder, connectSellerAiProvider } from "./seller/aiConnection";

// ============================================
// AI MARKETPLACE ASSISTANT — SELLER-SCOPED CHAT PROXY (Phase AI-4B)
// ============================================
export { sellerAiChatProxy } from "./seller/aiChatProxy";
// SELLER-AUTH-1b: the only path from a draft application to pending (ADR-S12)
export { submitSellerApplication } from "./seller/sellerApplication";
// SELLER-ORDERS-1: the only path for a seller to change an order status (ADR-S13)
export { sellerTransitionOrder } from "./seller/sellerTransitionOrder";
// SELLER-ORDERS-2: server-issued, sequentially numbered invoices (ADR-S14)
export { issueSellerInvoice } from "./seller/sellerInvoice";
export { rollupSellerStats, rebuildMySellerStats } from "./seller/sellerStats";
export { notifySellerPayoutPaid } from "./seller/payoutNotifications";
// SELLER-WALLET-1: seller withdrawals + admin-approved bank/UPI changes.
export {
  sellerWalletSummary, requestSellerWithdrawal, cancelSellerWithdrawal, markSellerWithdrawalPaid,
  rejectSellerWithdrawal, requestSellerPayoutChange, cancelSellerPayoutChange, reviewSellerPayoutChange,
} from "./seller/sellerWallet";
export { onProductReviewWrite, replyToReview } from "./seller/reviews";

// ============================================
// B2B RFQ & NEGOTIATION (Phase RFQ-1)
// ============================================
export { createRfq, submitRfqOffer, respondToRfqOffer } from "./customer/rfq";

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
export {
  expireProductCredits,
  releaseExpiredProductCreditHolds,
  reconcileProductCreditBalances
} from "./customer/productCreditExpiry";
// Phase C: everything redemption needs, WITHOUT spending credit yet — a
// server-authoritative quote (reused pricing logic from orderPricing.ts,
// shared verbatim with createOrder.ts) and the hold/release reservation
// lifecycle it places. No REDEMPTION entry is ever written by this phase;
// see customer/productCreditHold.ts's header comment.
export { quoteOrderWithCredit, releaseProductCreditHold } from "./customer/productCreditHold";
// Phase D: the redemption cutover — createOrder.ts (customer/createOrder.ts)
// settles a Product Credit hold into a real REDEMPTION ledger entry, and
// this trigger reverses that entry (a REVERSAL) when the order it was
// spent on is cancelled. See customer/productCreditReversal.ts's header.
export { reverseProductCreditOnCancellation } from "./customer/productCreditReversal";
// Phase ADMR-1: stock restoration on cancellation, generalized to every
// cancellation path (seller, customer, admin) and made variant-aware — see
// customer/restoreStockOnCancellation.ts's header for the full rationale.
export { restoreStockOnCancellation } from "./customer/restoreStockOnCancellation";

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
  createOnboardingWebHandoff,
  redeemOnboardingWebHandoff,
} from "./employee/onboardingWebHandoff";
export {
  waiveAssociateOnboardingFee,
  recordAssociateOnboardingRefund,
  requestAssociateOnboardingRefundOnSuspend,
} from "./employee/adminOnboardingActions";
// Phase DLV-1A: server-maintained delivery_tasks/{orderId} projection of each
// rider leg, in the typed vocabulary of delivery/states.ts. Writes only
// delivery_tasks; never the order. See delivery/syncDeliveryTask.ts.
export { syncDeliveryTask } from "./delivery/syncDeliveryTask";
// Phase DLV-2A: rider dispatch — offer waves, server-checked accept/decline,
// and the 1-minute scheduler for expiry, next waves and 2-min retries.
// See delivery/dispatch.ts. onOrderStatusChanged starts a dispatch.
export { acceptDeliveryOffer, declineDeliveryOffer } from "./delivery/dispatchCallables";
export { advanceDeliveryDispatch } from "./delivery/advanceDeliveryDispatch";
// Phase DLV-3B: road route for the customer's live tracking (Google Routes, server-side key).
export { refreshDeliveryRoute } from "./delivery/deliveryRoute";
// Phase DLV-3C: server-checked rider steps (transition table + location flags)
// and the "Seller not ready" hand-back. See delivery/riderSteps.ts.
export { advanceDeliveryStep, releaseDeliveryOrder } from "./delivery/riderSteps";
// Phase DLV-4A: rider pay per order, COD cash held, weekly statements, cash
// deposits and bank-detail review. See delivery/riderMoney.ts.
export {
  onRiderDelivery, buildRiderStatements, recordRiderCashDeposit, requestRiderBankChange, reviewRiderBankChange,
  markRiderPayoutPaid, riderMoneySummary,
} from "./delivery/riderMoney";
// Phase DLV-S2: a rider reports a safety incident to the Agrimore team; admins
// acknowledge and resolve it. See delivery/riderIncidents.ts.
export { reportRiderIncident, updateRiderIncident } from "./delivery/riderIncidents";
export { submitRiderApplication } from "./delivery/riderApplication";
export { updateRiderContact } from "./delivery/riderProfile";
export { attachDeliveryProof, reportDeliveryException, updateDeliveryException } from "./delivery/riderExceptions";
// Phase DLVID1: a rider requests a change to a locked identity field (name
// only — delivery_partners has no dateOfBirth field); admin approves or
// rejects. Modelled on requestRiderBankChange/reviewRiderBankChange above.
// See delivery/riderIdentity.ts.
export { requestRiderIdentityChange, reviewRiderIdentityChange } from "./delivery/riderIdentity";
// Phase DLVDOC2: a rider replaces one KYC document photo after their
// application was already decided; admin approves or rejects independently
// of the whole-application status. See delivery/riderDocumentReview.ts.
export { submitDocumentReplacement, reviewDocumentSubmission } from "./delivery/riderDocumentReview";
// Phase DLVSUP1: a rider files a support request (delivery/earnings/account
// category, a message, an optional attachment); admins mark it seen and
// close it with a written outcome. Modelled on reportRiderIncident/
// updateRiderIncident above, not the change-request pair: several tickets
// may be open on one rider at once. See delivery/riderSupport.ts.
export { submitSupportRequest, updateSupportRequest } from "./delivery/riderSupport";

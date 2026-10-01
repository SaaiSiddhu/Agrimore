import { onCall } from "firebase-functions/v2/https";
import { RAZORPAY_KEY_SECRET } from "./payment";
import { recoverOwnedPayment } from "./recoverCheckoutPayment";

// Recovery verifies a real capture only. verifyWalletTopup owns the credit,
// profile gate and atomic shared consumption marker.
export const recoverWalletTopupPayment = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [RAZORPAY_KEY_SECRET] },
  request => recoverOwnedPayment(request, "wallet_topup")
);

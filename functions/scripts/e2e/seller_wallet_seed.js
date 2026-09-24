// SELLER-WALLET-1 end-to-end — seeds the LOCAL emulators for the seller-app
// journey (apps/seller/integration_test/wallet_journey_test.dart).
//
// Refuses to run unless Auth and Firestore both point at local emulators, so
// it can never write to the live project. Test accounts use example.com
// addresses and a throwaway password that exists only in the Auth emulator.
//
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
//     node scripts/e2e/seller_wallet_seed.js
const local = (v) => typeof v === "string" && /^(127\.0\.0\.1|localhost):\d+$/.test(v);
if (!local(process.env.FIRESTORE_EMULATOR_HOST) || !local(process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  console.error("REFUSING: FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST must both be local emulators");
  process.exit(2);
}
const admin = require("firebase-admin");
const PROJECT = process.env.GCLOUD_PROJECT || "agrimore-66a4e";
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp } = require("firebase-admin/firestore");

const SELLER = { uid: "e2e-seller", email: "e2e-seller@example.com", password: "e2e-pass-123456", name: "Kaveri (TEST)" };
const ADMIN = { uid: "e2e-admin", email: "e2e-admin@example.com", password: "e2e-pass-123456", name: "Admin (TEST)" };
const BUYER = "e2e-buyer";

async function user(u, claims) {
  try { await admin.auth().deleteUser(u.uid); } catch (_) { /* first run */ }
  await admin.auth().createUser({ uid: u.uid, email: u.email, password: u.password, displayName: u.name, emailVerified: true });
  if (claims) await admin.auth().setCustomUserClaims(u.uid, claims);
}

async function main() {
  await user(SELLER, { seller: true, role: "seller" });
  await user(ADMIN, { admin: true, role: "admin" });
  const now = Date.now();
  await db.doc(`users/${SELLER.uid}`).set({ uid: SELLER.uid, email: SELLER.email, name: SELLER.name, role: "seller", sellerStatus: "approved", phone: "+919000000001" });
  await db.doc(`users/${ADMIN.uid}`).set({ uid: ADMIN.uid, email: ADMIN.email, name: ADMIN.name, role: "admin" });
  await db.doc(`users/${BUYER}`).set({ uid: BUYER, name: "Buyer (TEST)", role: "customer" });
  await db.doc(`sellers/${SELLER.uid}`).set({ uid: SELLER.uid, shopName: "Kaveri Fresh (TEST)", status: "approved", city: "Chennai", state: "Tamil Nadu", createdAt: Timestamp.fromMillis(now - 90 * 86400000) });
  await db.doc(`seller_payout_details/${SELLER.uid}`).set({ sellerId: SELLER.uid, payoutMethod: "bank", accountHolder: "Kaveri", bankName: "Example Bank", accountNumber: "123456784821", ifsc: "EXMP0001234" });
  await db.doc("settings/commission").set({ defaultRate: 5 });

  // Two orders, created shipped then delivered: the real calculateSellerPayout
  // trigger (functions emulator) writes the seller_payouts rows.
  const orders = [
    { id: "E2E-1001", items: [{ productId: "e2e-p1", name: "Fresh tomatoes", sellerId: SELLER.uid, price: 58, quantity: 10 }] },
    { id: "E2E-1002", items: [{ productId: "e2e-p2", name: "Green chillies", sellerId: SELLER.uid, price: 120, quantity: 3 }] },
  ];
  for (const o of orders) {
    await db.doc(`orders/${o.id}`).set({ orderNumber: o.id, userId: BUYER, sellerId: SELLER.uid, sellerIds: [SELLER.uid], items: o.items,
      total: o.items.reduce((s, i) => s + i.price * i.quantity, 0), paymentMethod: "razorpay", paymentStatus: "paid",
      orderStatus: "shipped", status: "shipped", createdAt: Timestamp.fromMillis(now - 3 * 86400000) });
  }
  for (const o of orders) await db.doc(`orders/${o.id}`).update({ orderStatus: "delivered", status: "delivered" });

  // Wait for the trigger.
  let payouts = [];
  for (let i = 0; i < 60; i++) {
    payouts = (await db.collection("seller_payouts").where("sellerId", "==", SELLER.uid).get()).docs;
    if (payouts.length === orders.length) break;
    await new Promise((r) => setTimeout(r, 1000));
  }
  const net = payouts.reduce((s, d) => s + Number(d.data().netAmount || 0), 0);
  console.log(`payouts written by the trigger: ${payouts.length} · net ₹${net.toFixed(2)}`);
  if (payouts.length !== orders.length) { console.error("FAILED: the payout trigger did not run"); process.exit(1); }

  // Followers + a post for the Followers & posts screen.
  for (let i = 1; i <= 3; i++) {
    await db.doc(`follows/e2e-buyer${i}_${SELLER.uid}`).set({ followerId: `e2e-buyer${i}`, sellerId: SELLER.uid, createdAt: Timestamp.fromMillis(now - i * 86400000) });
  }
  await db.doc("business_posts/e2e-post-1").set({ sellerId: SELLER.uid, text: "Fresh tomatoes in today (TEST)", createdAt: Timestamp.fromMillis(now - 3600000) });
  console.log(JSON.stringify({ seller: SELLER.email, admin: ADMIN.email, netRupees: Math.round(net * 100) / 100 }));
  process.exit(0);
}
main().catch((e) => { console.error(e); process.exit(1); });

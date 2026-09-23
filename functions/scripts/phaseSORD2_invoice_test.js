// ============================================================
//  Phase SELLER-ORDERS-2 — issueSellerInvoice
// ============================================================
//
// Run with: JAVA_HOME=/opt/homebrew/opt/openjdk@21 firebase emulators:exec
//             --only firestore "node scripts/phaseSORD2_invoice_test.js"

process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });
const db = admin.firestore();

const { issueSellerInvoice, buildLines, financialYear, invoiceNumber } = require("../lib/seller/sellerInvoice");

const SELLER = { uid: "seller1", token: { seller: true } };

async function call(auth, data) {
  try {
    return { ok: true, res: await issueSellerInvoice.run({ auth, data }) };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function order(id, extra = {}) {
  await db.collection("orders").doc(id).set({
    userId: "cust1", sellerId: "seller1", orderNumber: `ORD-${id}`, orderStatus: "confirmed",
    subtotal: 330, discount: 0, deliveryCharge: 20, tax: 0, total: 350, paymentMethod: "cod",
    deliveryAddress: { name: "Priya", addressLine1: "4 Lake Rd", city: "Madurai", state: "Tamil Nadu", zipcode: "625001" },
    items: [
      { productId: "tomato", productName: "Tomato 1kg", price: 40, quantity: 3 },
      { productId: "rice", productName: "Rice 5kg", price: 210, quantity: 1 },
    ],
    ...extra,
  });
}

async function main() {
  const results = {};
  const check = (k, ok, detail) => {
    results[k] = ok ? "PASSED" : `FAILED — ${detail}`;
    console.log(`${k}: ${ok ? "PASSED" : "FAILED"} — ${detail}`);
  };

  // ── pure ─────────────────────────────────────────────────────────────────
  check("p1_fy_mid_year", financialYear(new Date("2026-09-23T10:00:00+05:30")) === "2026-27", "");
  check("p2_fy_before_april", financialYear(new Date("2027-02-01T10:00:00+05:30")) === "2026-27", "");
  check("p3_fy_boundary_is_ist", financialYear(new Date("2027-04-01T00:10:00+05:30")) === "2027-28",
    financialYear(new Date("2027-04-01T00:10:00+05:30")));
  check("p4_number_format", invoiceNumber("2026-27", 42) === "INV/2026-27/000042", "");
  {
    const b = buildLines([{ name: "Tomato", quantity: 3, unitPrice: 40, hsnCode: "0702", gstRate: 0 }], null, "TN", "TN");
    check("p5_no_gstin_is_bill_of_supply", b.docType === "bill_of_supply" && b.taxTotal === 0, JSON.stringify(b));
  }
  {
    const b = buildLines([
      { name: "Rice", quantity: 1, unitPrice: 210, hsnCode: "1006", gstRate: 5 },
      { name: "Tomato", quantity: 3, unitPrice: 40 },
    ], "33ABCDE1234F1Z5", "Tamil Nadu", "Tamil Nadu");
    check("p6_missing_tax_data_on_any_line_is_bill_of_supply", b.docType === "bill_of_supply", b.docType);
  }
  {
    const b = buildLines([{ name: "Rice", quantity: 1, unitPrice: 210, hsnCode: "1006", gstRate: 5 }],
      "33ABCDE1234F1Z5", "Tamil Nadu", "tamil nadu");
    const l = b.lines[0];
    check("p7_intra_state_cgst_sgst_inclusive",
      b.docType === "tax_invoice" && l.taxable === 200 && l.cgst === 5 && l.sgst === 5 && l.igst === 0 && b.taxTotal === 10,
      JSON.stringify(l));
  }
  {
    const b = buildLines([{ name: "Rice", quantity: 1, unitPrice: 210, hsnCode: "1006", gstRate: 5 }],
      "33ABCDE1234F1Z5", "Tamil Nadu", "Kerala");
    const l = b.lines[0];
    check("p8_inter_state_igst", l.igst === 10 && l.cgst === 0 && l.sgst === 0, JSON.stringify(l));
  }
  {
    const b = buildLines([{ name: "Oil", quantity: 3, unitPrice: 33.33, hsnCode: "1512", gstRate: 18 }],
      "33ABCDE1234F1Z5", "TN", "TN");
    const l = b.lines[0];
    check("p9_line_parts_add_up_to_amount",
      Math.abs(l.taxable + l.cgst + l.sgst - l.amount) < 0.005, JSON.stringify(l));
  }

  // ── callable ─────────────────────────────────────────────────────────────
  await db.collection("sellers").doc("seller1").set({ shopName: "Ravi Stores", shopAddress: "Market St", state: "Tamil Nadu", gstin: "33ABCDE1234F1Z5" });
  await db.collection("products").doc("tomato").set({ name: "Tomato", hsnCode: "0702", gstRate: 0 });
  await db.collection("products").doc("rice").set({ name: "Rice", hsnCode: "1006", gstRate: 5 });

  {
    await order("o1");
    const r = await call(SELLER, { orderId: "o1" });
    const inv = r.ok ? (await db.collection("invoices").doc(r.res.invoiceId).get()).data() : {};
    const o = (await db.collection("orders").doc("o1").get()).data();
    check("c1_issues_tax_invoice_with_snapshot",
      r.ok && inv.docType === "tax_invoice" && /^INV\/\d{4}-\d{2}\/000001$/.test(inv.invoiceNumber) &&
        inv.lines.length === 2 && inv.totals.total === 350 && inv.buyer.address.includes("625001") &&
        o.invoiceId === r.res.invoiceId,
      JSON.stringify({ ok: r.ok, n: inv.invoiceNumber, t: inv.docType }));
    const again = await call(SELLER, { orderId: "o1" });
    check("c2_idempotent_same_invoice", again.ok && again.res.alreadyIssued && again.res.invoiceId === r.res.invoiceId,
      JSON.stringify(again));
  }
  {
    await order("o2");
    await order("o3");
    const [a, b] = await Promise.all([call(SELLER, { orderId: "o2" }), call(SELLER, { orderId: "o3" })]);
    const nums = [a.res?.invoiceNumber, b.res?.invoiceNumber].sort();
    check("c3_concurrent_issues_get_distinct_sequential_numbers",
      a.ok && b.ok && nums[0].endsWith("000002") && nums[1].endsWith("000003"), JSON.stringify(nums));
  }
  {
    await order("o4", { orderStatus: "pending" });
    const r = await call(SELLER, { orderId: "o4" });
    check("c4_pending_order_not_invoiceable", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    await order("o5", { orderStatus: "cancelled" });
    const r = await call(SELLER, { orderId: "o5" });
    check("c5_cancelled_order_not_invoiceable", !r.ok && r.code === "failed-precondition", JSON.stringify(r));
  }
  {
    await order("o6");
    const r = await call({ uid: "seller2", token: {} }, { orderId: "o6" });
    check("c6_other_seller_denied", !r.ok && r.code === "permission-denied", JSON.stringify(r));
    const u = await call(undefined, { orderId: "o6" });
    check("c7_unauthenticated", !u.ok && u.code === "unauthenticated", JSON.stringify(u));
  }

  console.log("\n=== PHASE SELLER-ORDERS-2 (invoice) SUMMARY ===");
  const total = Object.keys(results).length;
  const passed = Object.values(results).filter((v) => v === "PASSED").length;
  for (const [k, v] of Object.entries(results)) console.log(`  ${v === "PASSED" ? "PASS" : "FAIL"}  ${k}`);
  console.log(`\n${passed}/${total} scenarios passed`);
  if (passed !== total) { console.error("PHASE SELLER-ORDERS-2 (invoice): FAILED"); process.exitCode = 1; }
  else console.log("PHASE SELLER-ORDERS-2 (invoice): ALL PASSED");
}

main().catch((e) => { console.error("harness error", e); process.exit(1); });

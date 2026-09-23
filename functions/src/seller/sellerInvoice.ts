// ============================================================
//  Callable: issueSellerInvoice (Phase SELLER-ORDERS-2, ADR-S14)
// ============================================================
//
// Issues the invoice for an accepted order, once. Numbered per seller per
// Indian financial year (April–March) from a counter the client can never
// write: `INV/2026-27/000001`. The invoice is an immutable snapshot of the
// order, the seller's business details and each product's tax data at the
// moment of issue.
//
// Document type (D-SELLER-GST default, 2026-09-23):
//   - "tax_invoice"    — the seller has a GSTIN AND every line has an HSN
//                        code and a GST rate;
//   - "bill_of_supply" — otherwise (GST-exempt produce, unregistered seller,
//                        or incomplete tax data): no tax lines.
// Prices are treated as GST-INCLUSIVE (normal for Indian retail): per line,
// taxable = amount / (1 + rate/100) and tax = amount − taxable. The order's
// own totals are copied unchanged — the invoice never changes what the buyer
// paid. Intra-state → CGST + SGST (half each); inter-state → IGST.
//
// Generation: v2 onCall, no secrets.

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const INVOICEABLE = ["confirmed", "processing", "ready_for_pickup", "delivery_accepted", "arrived_at_store",
  "picked_up", "out_for_delivery", "shipped", "delivered", "completed"];
const GST_RATES = [0, 5, 12, 18, 28];
const HSN = /^(\d{4}|\d{6}|\d{8})$/;
const GSTIN = /^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;

export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

const IST_OFFSET_MS = 330 * 60 * 1000;

/** Indian financial year (April–March, in IST) for an instant:
 *  2026-09-23 → "2026-27"; 2027-02-01 → "2026-27"; 2027-04-01 00:10 IST → "2027-28". */
export function financialYear(d: Date): string {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const y = ist.getUTCMonth() >= 3 ? ist.getUTCFullYear() : ist.getUTCFullYear() - 1;
  return `${y}-${String((y + 1) % 100).padStart(2, "0")}`;
}

export function invoiceNumber(fy: string, seq: number): string {
  return `INV/${fy}/${String(seq).padStart(6, "0")}`;
}

export interface InvoiceLineInput {
  name: string;
  quantity: number;
  unitPrice: number;
  hsnCode?: string | null;
  gstRate?: number | null;
}

export interface InvoiceLine extends InvoiceLineInput {
  amount: number;
  taxable: number;
  cgst: number;
  sgst: number;
  igst: number;
}

/** Pure: document type and per-line tax split. Unit-tested without an emulator. */
export function buildLines(
  inputs: InvoiceLineInput[],
  sellerGstin: string | null | undefined,
  sellerState: string | null | undefined,
  buyerState: string | null | undefined
): { docType: "tax_invoice" | "bill_of_supply"; lines: InvoiceLine[]; taxTotal: number } {
  const hasGstin = typeof sellerGstin === "string" && GSTIN.test(sellerGstin.toUpperCase());
  const allTaxed = inputs.length > 0 && inputs.every((l) =>
    typeof l.hsnCode === "string" && HSN.test(l.hsnCode) &&
    typeof l.gstRate === "number" && GST_RATES.includes(l.gstRate));
  const docType = hasGstin && allTaxed ? "tax_invoice" : "bill_of_supply";
  const intraState = !!sellerState && !!buyerState &&
    sellerState.trim().toLowerCase() === buyerState.trim().toLowerCase();

  let taxTotal = 0;
  const lines = inputs.map((l) => {
    const amount = round2(l.quantity * l.unitPrice);
    if (docType === "bill_of_supply") {
      return { ...l, amount, taxable: amount, cgst: 0, sgst: 0, igst: 0 };
    }
    const rate = l.gstRate as number;
    const taxable = round2(amount / (1 + rate / 100));
    const tax = round2(amount - taxable);
    taxTotal = round2(taxTotal + tax);
    if (intraState) {
      const half = round2(tax / 2);
      return { ...l, amount, taxable, cgst: half, sgst: round2(tax - half), igst: 0 };
    }
    return { ...l, amount, taxable, cgst: 0, sgst: 0, igst: tax };
  });
  return { docType, lines, taxTotal };
}

export const issueSellerInvoice = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
    const uid = request.auth.uid;
    const orderId = (request.data ?? {}).orderId;
    if (typeof orderId !== "string" || orderId.length === 0) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }
    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    return db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw new HttpsError("not-found", "Order not found.");
      const order = orderSnap.data()!;
      if (order.sellerId !== uid) throw new HttpsError("permission-denied", "This order belongs to another seller.");
      if (typeof order.invoiceId === "string" && order.invoiceId) {
        const existing = await tx.get(db.collection("invoices").doc(order.invoiceId));
        return { invoiceId: order.invoiceId, invoiceNumber: existing.data()?.invoiceNumber, alreadyIssued: true };
      }
      const status = String(order.orderStatus ?? "");
      if (!INVOICEABLE.includes(status)) {
        throw new HttpsError("failed-precondition", `An invoice can be issued once the order is accepted (it is ${status}).`);
      }

      const items: Array<Record<string, unknown>> = Array.isArray(order.items) ? order.items : [];
      const productIds = [...new Set(items.map((i) => i.productId).filter((id): id is string => typeof id === "string" && id.length > 0))];
      const now = new Date();
      const fy = financialYear(now);
      const counterRef = db.collection("seller_invoice_counters").doc(`${uid}_${fy}`);
      const [sellerSnap, counterSnap, ...productSnaps] = await Promise.all([
        tx.get(db.collection("sellers").doc(uid)),
        tx.get(counterRef),
        ...productIds.map((id) => tx.get(db.collection("products").doc(id))),
      ]);
      const seller = sellerSnap.data() ?? {};
      const productTax = new Map(productSnaps.map((s) => [s.id, s.data() ?? {}]));

      const inputs: InvoiceLineInput[] = items.map((i) => {
        const p = productTax.get(String(i.productId ?? "")) ?? {};
        const price = Number(i.price ?? i.salePrice ?? i.unitPrice ?? 0);
        return {
          name: String(i.productName ?? i.name ?? p.name ?? "Item"),
          quantity: Number(i.quantity ?? 1),
          unitPrice: Number.isFinite(price) ? price : 0,
          hsnCode: typeof p.hsnCode === "string" ? p.hsnCode : null,
          gstRate: typeof p.gstRate === "number" ? p.gstRate : null,
        };
      });
      const address = (order.deliveryAddress ?? {}) as Record<string, unknown>;
      // Onboarding (SELLER-AUTH-1b) writes `gstin`; the older profile editor writes
      // `gstNumber` — accept either (unified in SELLER-ACCOUNT-1).
      const sellerGstin = (seller.gstin || seller.gstNumber || null) as string | null;
      const built = buildLines(inputs, sellerGstin, seller.state as string | undefined,
        address.state as string | undefined);

      const seq = (typeof counterSnap.data()?.last === "number" ? counterSnap.data()!.last : 0) + 1;
      const number = invoiceNumber(fy, seq);
      const invoiceRef = db.collection("invoices").doc();

      tx.set(counterRef, { sellerId: uid, financialYear: fy, last: seq, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      tx.set(invoiceRef, {
        invoiceNumber: number,
        financialYear: fy,
        sequence: seq,
        docType: built.docType,
        orderId,
        orderNumber: order.orderNumber ?? orderId,
        sellerId: uid,
        buyerId: order.userId ?? null,
        seller: {
          shopName: seller.shopName ?? null,
          address: seller.shopAddress ?? null,
          state: seller.state ?? null,
          gstin: sellerGstin,
        },
        buyer: {
          name: address.name ?? null,
          address: [address.addressLine1, address.addressLine2, address.city, address.state, address.zipcode]
            .filter((x) => typeof x === "string" && x).join(", ") || null,
          state: address.state ?? null,
        },
        lines: built.lines,
        totals: {
          subtotal: Number(order.subtotal ?? 0),
          discount: Number(order.discount ?? 0),
          deliveryCharge: Number(order.deliveryCharge ?? 0),
          tax: built.taxTotal,
          total: Number(order.total ?? 0),
        },
        paymentMethod: order.paymentMethod ?? null,
        issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(orderRef, { invoiceId: invoiceRef.id, invoiceNumber: number });
      return { invoiceId: invoiceRef.id, invoiceNumber: number, alreadyIssued: false };
    });
  }
);

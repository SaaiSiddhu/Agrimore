// ============================================================
//  Callables: createRfq / submitRfqOffer / respondToRfqOffer
// ============================================================
//
// Phase RFQ-1: the B2B "Request for Quote" negotiation mechanism confirmed
// as a real, entirely greenfield gap by BOTH the customer-app spec
// ("Request for Quote (RFQ), Buyer–seller negotiation, Custom quotation")
// and the seller-app spec ("RFQ & Negotiation — Bulk quotation, custom
// pricing and buyer negotiation") — owner chat, 2026-09-07.
//
// DELIBERATELY NARROW SCOPE: this phase builds ONLY the negotiation itself
// — a buyer and seller exchanging offers until one accepts or rejects the
// other's last offer, producing a LOCKED finalPrice/finalQuantity. It does
// NOT wire an accepted RFQ into createOrder.ts. That is split to a future
// phase (RFQ-3) on purpose: createOrder.ts is this codebase's single most
// security-sensitive, most collision-prone file (every historical
// concurrent-session incident touched it), and its pricing today is
// entirely catalog-derived (orderPricing.ts's product.b2bPrice/b2bMoq) with
// no existing concept of a per-order custom price. Bolting a new
// client-triggerable custom-price path onto that file deserves its own
// dedicated, carefully-reviewed phase — not a rider on this one.
//
// State machine:
//   pending      -> just created by the buyer, awaiting the seller's first
//                   response. lastOffer is the buyer's own initial ask, or
//                   null if they asked for a quote with no price in mind.
//   negotiating  -> at least one offer has been submitted by either side.
//                   awaitingResponseFrom names whose turn it is; only that
//                   party may submitRfqOffer or respondToRfqOffer next.
//   accepted     -> the party who was awaited accepted the other's last
//                   offer. finalPrice/finalQuantity are locked from
//                   lastOffer at that moment and never change again.
//   rejected     -> the party who was awaited rejected instead.
//
// Every state transition is derived from server-verified identity
// (request.auth.uid compared against the rfq's own stored buyerId/sellerId)
// — a caller never gets to assert which role they are playing.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { notifyUser } from "./orderNotifications";

const MAX_NOTES_LENGTH = 500; // FIX-16 precedent: bound every client string
const MAX_QUANTITY = 1_000_000; // generous engineering ceiling, not a business limit
const MAX_PRICE = 100_000_000; // ₹10 crore; same class of generous ceiling

// SELLER-RFQ-2 (ADR Q-02/Q-03): every open offer carries a validity window.
// Accepting an expired offer is refused; countering always stays possible
// (a counter is a fresh offer with its own window). RFQs written before
// this phase have no expiresAt and never expire.
export const DEFAULT_VALID_DAYS = 7;
export const MAX_VALID_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

function validateValidDays(days: unknown): number {
  if (days === undefined || days === null) return DEFAULT_VALID_DAYS;
  if (typeof days !== "number" || !Number.isInteger(days) || days < 1 || days > MAX_VALID_DAYS) {
    throw new HttpsError("invalid-argument", `validForDays must be a whole number from 1 to ${MAX_VALID_DAYS}`);
  }
  return days;
}

function expiryFrom(now: admin.firestore.Timestamp, days: number): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(now.toMillis() + days * DAY_MS);
}

/** Display-only snapshot so both inboxes can render a quote without reading
 * the product or the buyer's private profile. Never used for pricing —
 * createOrderFromRfq re-reads the product. */
function productSnapshot(p: Record<string, unknown>): Record<string, unknown> {
  const images = Array.isArray(p.images) ? p.images : [];
  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);
  return {
    name: typeof p.name === "string" ? p.name.slice(0, 200) : "",
    imageUrl: typeof images[0] === "string" ? images[0] : typeof p.imageUrl === "string" ? p.imageUrl : null,
    unit: typeof p.unit === "string" ? p.unit.slice(0, 40) : null,
    b2bPrice: num(p.b2bPrice),
    b2bMoq: num(p.b2bMoq),
  };
}

type RfqRole = "buyer" | "seller";

interface RfqHistoryEntry {
  actor: RfqRole;
  action: "create" | "offer" | "accept" | "reject";
  price: number | null;
  quantity: number | null;
  notes: string | null;
  at: admin.firestore.Timestamp;
}

function validateNotes(notes: unknown): string | null {
  if (notes === undefined || notes === null) return null;
  if (typeof notes !== "string") {
    throw new HttpsError("invalid-argument", "notes must be a string");
  }
  if (notes.length > MAX_NOTES_LENGTH) {
    throw new HttpsError("invalid-argument", `notes must be at most ${MAX_NOTES_LENGTH} characters`);
  }
  return notes.trim().length > 0 ? notes.trim() : null;
}

function validateQuantity(quantity: unknown): number {
  if (typeof quantity !== "number" || !Number.isInteger(quantity) || quantity <= 0) {
    throw new HttpsError("invalid-argument", "quantity must be a positive integer");
  }
  if (quantity > MAX_QUANTITY) {
    throw new HttpsError("invalid-argument", `quantity must be at most ${MAX_QUANTITY}`);
  }
  return quantity;
}

function validatePrice(price: unknown): number {
  if (typeof price !== "number" || !Number.isFinite(price) || price <= 0) {
    throw new HttpsError("invalid-argument", "price must be a positive number");
  }
  if (price > MAX_PRICE) {
    throw new HttpsError("invalid-argument", `price must be at most ${MAX_PRICE}`);
  }
  return price;
}

/** Derives the caller's role from the RFQ's own stored identities — never
 * from anything the client asserts. Throws permission-denied if the caller
 * is neither party. */
function roleOf(uid: string, rfq: { buyerId: string; sellerId: string }): RfqRole {
  if (uid === rfq.buyerId) return "buyer";
  if (uid === rfq.sellerId) return "seller";
  throw new HttpsError("permission-denied", "You are not a party to this RFQ");
}

function otherRole(role: RfqRole): RfqRole {
  return role === "buyer" ? "seller" : "buyer";
}

/**
 * SELLER-HOME-1b: tell the other party (inbox + push). Best-effort — a
 * notification failure never fails the negotiation step that already
 * committed.
 */
async function notifyRfqParty(
  userId: string,
  rfqId: string,
  title: string,
  body: string,
  type: string
): Promise<void> {
  try {
    await notifyUser(userId, title, body, type, { rfqId, actionUrl: `rfq/${rfqId}`, type: "rfq" }, "📝");
  } catch (e) {
    console.error(`RFQ notification ${type} for ${rfqId} failed`, e);
  }
}

const rupees = (n: number) => `Rs.${n.toFixed(2)}`;

interface CreateRfqData {
  productId?: string;
  quantity?: number;
  proposedPrice?: number;
  notes?: string;
  validForDays?: number;
}

export const createRfq = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as CreateRfqData;

    if (typeof data?.productId !== "string" || !data.productId) {
      throw new HttpsError("invalid-argument", "productId is required");
    }
    const quantity = validateQuantity(data.quantity);
    const proposedPrice = data.proposedPrice !== undefined ? validatePrice(data.proposedPrice) : null;
    const notes = validateNotes(data.notes);
    const validDays = validateValidDays(data.validForDays);

    const db = admin.firestore();
    const productSnap = await db.collection("products").doc(data.productId).get();
    if (!productSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = productSnap.data() as {
      isB2BEnabled?: boolean;
      sellerId?: string;
    };

    // Mirrors orderPricing.ts's own exact B2B-enablement check — an RFQ is
    // a B2B concept end to end; a B2C-only product has nothing to negotiate.
    if (product.isB2BEnabled !== true) {
      throw new HttpsError("failed-precondition", "This product is not enabled for B2B ordering");
    }
    const sellerId = typeof product.sellerId === "string" ? product.sellerId : "";
    if (!sellerId) {
      throw new HttpsError("failed-precondition", "This product has no seller assigned");
    }
    if (sellerId === uid) {
      throw new HttpsError("invalid-argument", "You cannot request a quote on your own product");
    }

    const buyerSnap = await db.collection("users").doc(uid).get();
    const buyerData = (buyerSnap.data() ?? {}) as Record<string, unknown>;
    const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim().slice(0, 120) : null);
    // Name and business only — never phone, email or address.
    const buyer = { name: str(buyerData.name), businessName: str(buyerData.businessName) };

    const rfqRef = db.collection("rfqs").doc();
    const now = admin.firestore.Timestamp.now();
    const expiresAt = proposedPrice !== null ? expiryFrom(now, validDays) : null;
    const historyEntry: RfqHistoryEntry = {
      actor: "buyer",
      action: "create",
      price: proposedPrice,
      quantity,
      notes,
      at: now,
    };

    await rfqRef.set({
      id: rfqRef.id,
      buyerId: uid,
      sellerId,
      productId: data.productId,
      status: "pending",
      awaitingResponseFrom: "seller",
      lastOffer:
        proposedPrice !== null ? { price: proposedPrice, quantity, by: "buyer", notes, expiresAt } : null,
      product: productSnapshot(productSnap.data() as Record<string, unknown>),
      buyer,
      finalPrice: null,
      finalQuantity: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: null,
      rejectedAt: null,
      history: [historyEntry],
    });

    const productName = typeof productSnap.data()?.name === "string" ? productSnap.data()?.name : "your product";
    const who = buyer.businessName || buyer.name || "A business buyer";
    await notifyRfqParty(
      sellerId,
      rfqRef.id,
      "New quote request",
      `${who} asked for ${quantity} × ${productName}` + (proposedPrice !== null ? ` at ${rupees(proposedPrice)} each.` : "."),
      "rfq_new"
    );

    return { success: true, rfqId: rfqRef.id };
  }
);

interface SubmitRfqOfferData {
  rfqId?: string;
  price?: number;
  quantity?: number;
  notes?: string;
  validForDays?: number;
}

export const submitRfqOffer = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as SubmitRfqOfferData;

    if (typeof data?.rfqId !== "string" || !data.rfqId) {
      throw new HttpsError("invalid-argument", "rfqId is required");
    }
    const price = validatePrice(data.price);
    const quantity = validateQuantity(data.quantity);
    const notes = validateNotes(data.notes);
    const validDays = validateValidDays(data.validForDays);

    const db = admin.firestore();
    const rfqRef = db.collection("rfqs").doc(data.rfqId);
    let notifyId = "";
    let productName = "";

    await db.runTransaction(async (tx) => {
      const rfqSnap = await tx.get(rfqRef);
      if (!rfqSnap.exists) {
        throw new HttpsError("not-found", "RFQ not found");
      }
      const rfq = rfqSnap.data() as {
        buyerId: string;
        sellerId: string;
        status: string;
        awaitingResponseFrom: RfqRole | null;
      };
      const role = roleOf(uid, rfq);

      if (rfq.status !== "pending" && rfq.status !== "negotiating") {
        throw new HttpsError("failed-precondition", "This RFQ is no longer open");
      }
      if (rfq.awaitingResponseFrom !== role) {
        throw new HttpsError("failed-precondition", "Waiting for the other party to respond");
      }

      const now = admin.firestore.Timestamp.now();
      const historyEntry: RfqHistoryEntry = {
        actor: role,
        action: "offer",
        price,
        quantity,
        notes,
        at: now,
      };

      notifyId = role === "buyer" ? rfq.sellerId : rfq.buyerId;
      productName = String((rfqSnap.data()?.product as { name?: string } | undefined)?.name || "");

      tx.update(rfqRef, {
        status: "negotiating",
        awaitingResponseFrom: otherRole(role),
        lastOffer: { price, quantity, by: role, notes, expiresAt: expiryFrom(now, validDays) },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        history: admin.firestore.FieldValue.arrayUnion(historyEntry),
      });
    });

    await notifyRfqParty(
      notifyId,
      data.rfqId,
      "New offer on a quote",
      `${productName || "Quote"}: ${quantity} × ${rupees(price)}. Valid for ${validDays} day${validDays === 1 ? "" : "s"}.`,
      "rfq_offer"
    );

    return { success: true };
  }
);

interface RespondToRfqOfferData {
  rfqId?: string;
  action?: "accept" | "reject";
  reason?: string;
}

export const respondToRfqOffer = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as RespondToRfqOfferData;

    if (data?.action !== "accept" && data?.action !== "reject") {
      throw new HttpsError("invalid-argument", "action must be 'accept' or 'reject'");
    }
    if (typeof data?.rfqId !== "string" || !data.rfqId) {
      throw new HttpsError("invalid-argument", "rfqId is required");
    }
    const action = data.action;
    const reason = action === "reject" ? validateNotes(data.reason) : null;

    const db = admin.firestore();
    const rfqRef = db.collection("rfqs").doc(data.rfqId);
    let notifyId = "";
    let productName = "";

    await db.runTransaction(async (tx) => {
      const rfqSnap = await tx.get(rfqRef);
      if (!rfqSnap.exists) {
        throw new HttpsError("not-found", "RFQ not found");
      }
      const rfq = rfqSnap.data() as {
        buyerId: string;
        sellerId: string;
        status: string;
        awaitingResponseFrom: RfqRole | null;
        lastOffer: {
          price: number;
          quantity: number;
          by: RfqRole;
          notes: string | null;
          expiresAt?: admin.firestore.Timestamp | null;
        } | null;
      };
      const role = roleOf(uid, rfq);

      if (rfq.status !== "pending" && rfq.status !== "negotiating") {
        throw new HttpsError("failed-precondition", "This RFQ is no longer open");
      }
      if (rfq.awaitingResponseFrom !== role) {
        throw new HttpsError("failed-precondition", "Waiting for the other party to respond");
      }

      const now = admin.firestore.Timestamp.now();
      notifyId = role === "buyer" ? rfq.sellerId : rfq.buyerId;
      productName = String((rfqSnap.data()?.product as { name?: string } | undefined)?.name || "");

      if (action === "accept") {
        if (!rfq.lastOffer) {
          throw new HttpsError(
            "failed-precondition",
            "There is no offer to accept yet — submit a price first"
          );
        }
        const expiresAt = rfq.lastOffer.expiresAt;
        if (expiresAt && expiresAt.toMillis() < now.toMillis()) {
          throw new HttpsError(
            "failed-precondition",
            "This offer has expired — send a new offer instead"
          );
        }
        const historyEntry: RfqHistoryEntry = {
          actor: role,
          action: "accept",
          price: rfq.lastOffer.price,
          quantity: rfq.lastOffer.quantity,
          notes: null,
          at: now,
        };
        tx.update(rfqRef, {
          status: "accepted",
          awaitingResponseFrom: null,
          finalPrice: rfq.lastOffer.price,
          finalQuantity: rfq.lastOffer.quantity,
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          history: admin.firestore.FieldValue.arrayUnion(historyEntry),
        });
      } else {
        const historyEntry: RfqHistoryEntry = {
          actor: role,
          action: "reject",
          price: null,
          quantity: null,
          notes: reason,
          at: now,
        };
        tx.update(rfqRef, {
          status: "rejected",
          awaitingResponseFrom: null,
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          history: admin.firestore.FieldValue.arrayUnion(historyEntry),
        });
      }
    });

    await notifyRfqParty(
      notifyId,
      data.rfqId,
      action === "accept" ? "Quote accepted" : "Quote declined",
      action === "accept"
        ? `${productName || "Your quote"} was accepted. The order can now be placed at the agreed price.`
        : `${productName || "Your quote"} was declined${reason ? `: ${reason}` : "."}`,
      action === "accept" ? "rfq_accepted" : "rfq_declined"
    );

    return { success: true, action };
  }
);

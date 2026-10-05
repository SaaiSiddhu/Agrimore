import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { DeliveryFeeSchedule, computeFeeFromSchedule } from "./deliveryFeeSchedule";
import { OrderPricingItemInput } from "./orderPricing";
import { distanceScheduleFingerprint, fingerprintDeliveryItems, hashDeliveryQuoteValue } from "./deliveryQuoteFingerprint";

type RoutePoint = { latitude: number; longitude: number };

function validCoordinatePair(lat: unknown, lng: unknown): RoutePoint | null {
  if (typeof lat !== "number" || !Number.isFinite(lat) || lat < -90 || lat > 90) return null;
  if (typeof lng !== "number" || !Number.isFinite(lng) || lng < -180 || lng > 180) return null;
  return { latitude: lat, longitude: lng };
}

// Fingerprint the client/persisted representation before range validation,
// matching the original order guard. Invalid numeric coordinates must not
// collapse to "no location" and accidentally match a quote with no location.
function numericCoordinatePair(lat: unknown, lng: unknown): RoutePoint | null {
  return typeof lat === "number" && typeof lng === "number" ? { latitude: lat, longitude: lng } : null;
}

export interface ValidateDeliveryQuoteInput {
  db: FirebaseFirestore.Firestore;
  tx: FirebaseFirestore.Transaction;
  uid: string;
  deliveryQuoteId?: string;
  deliveryAddress?: Record<string, unknown>;
  items: OrderPricingItemInput[];
  orderMode: string;
  deliveryCharge?: number;
  legacyDeliveryCharge?: number;
  sellerFeeSchedules: Map<string, DeliveryFeeSchedule>;
  sellerSnapshots: FirebaseFirestore.DocumentSnapshot[];
  expectedSellerIds: string[];
}

export async function validateDeliveryQuote(input: ValidateDeliveryQuoteInput): Promise<{
  ref: FirebaseFirestore.DocumentReference | null;
  snap: FirebaseFirestore.DocumentSnapshot | null;
  sellerDistanceMeters: Map<string, number> | undefined;
}> {
  const distanceSellerCount = [...input.sellerFeeSchedules.values()].filter((s) => s.type === "distance").length;
  if (!input.deliveryQuoteId) {
    if (distanceSellerCount > 0) {
      throw new HttpsError("failed-precondition", "Refresh delivery pricing before placing this order");
    }
    return { ref: null, snap: null, sellerDistanceMeters: undefined };
  }
  if (!/^[A-Za-z0-9_-]{1,150}$/.test(input.deliveryQuoteId)) {
    throw new HttpsError("failed-precondition", "Refresh delivery pricing before placing this order");
  }

  const ref = input.db.collection("delivery_fee_quotes").doc(input.deliveryQuoteId);
  const snap = await input.tx.get(ref);
  const quote = snap.data();
  const address = input.deliveryAddress ?? {};
  const addressId = typeof address.id === "string" ? address.id : "";
  const savedAddressSnap = addressId ? await input.tx.get(input.db.collection("addresses").doc(addressId)) : null;
  const savedAddress = savedAddressSnap?.data();
  const destination = numericCoordinatePair(address.latitude, address.longitude);
  const addressFingerprint = hashDeliveryQuoteValue({ addressId, destination });
  const savedDestination = numericCoordinatePair(savedAddress?.latitude, savedAddress?.longitude);
  const savedAddressFingerprint = hashDeliveryQuoteValue({ addressId, destination: savedDestination });
  const cartFingerprint = fingerprintDeliveryItems(input.items);
  const expiresAt = quote?.expiresAt as admin.firestore.Timestamp | undefined;
  const entries = Array.isArray(quote?.distanceEntries) ? quote.distanceEntries as Array<Record<string, unknown>> : [];
  const quoteSellerIds = [...(Array.isArray(quote?.sellerIds) ? quote.sellerIds as string[] : [])].sort();
  const expectedSellerIds = [...input.expectedSellerIds].sort();
  if (!snap.exists || !savedAddressSnap?.exists || savedAddress?.userId !== input.uid ||
      quote?.uid !== input.uid || quote?.addressId !== addressId ||
      quote?.addressFingerprint !== addressFingerprint || quote?.addressFingerprint !== savedAddressFingerprint ||
      quote?.cartFingerprint !== cartFingerprint || quote?.orderMode !== input.orderMode ||
      quote?.legacyDeliveryChargePaise !== Math.round((input.legacyDeliveryCharge ?? 0) * 100) ||
      JSON.stringify(quoteSellerIds) !== JSON.stringify(expectedSellerIds) ||
      !expiresAt || expiresAt.toMillis() <= Date.now() || quote?.consumedAt != null ||
      entries.length !== distanceSellerCount || !Number.isSafeInteger(quote?.deliveryChargePaise) ||
      Math.round((input.deliveryCharge ?? 0) * 100) !== quote?.deliveryChargePaise) {
    throw new HttpsError("failed-precondition", "Delivery pricing changed or expired. Please refresh checkout.");
  }

  const quoteScheduleFingerprints = quote?.scheduleFingerprints as Record<string, unknown> | undefined;
  const sellerById = new Map(input.sellerSnapshots.map((seller) => [seller.id, seller.data() ?? {}]));
  for (const [sellerId, schedule] of input.sellerFeeSchedules) {
    if (quoteScheduleFingerprints?.[sellerId] !== distanceScheduleFingerprint(schedule)) {
      throw new HttpsError("failed-precondition", "Seller delivery pricing changed. Please refresh checkout.");
    }
  }

  const sellerDistanceMeters = new Map<string, number>();
  for (const entry of entries) {
    const sellerId = entry.sellerId;
    const schedule = typeof sellerId === "string" ? input.sellerFeeSchedules.get(sellerId) : undefined;
    const seller = typeof sellerId === "string" ? sellerById.get(sellerId) ?? {} : {};
    const origin = validCoordinatePair(seller.latitude, seller.longitude);
    const originFingerprint = origin ? hashDeliveryQuoteValue(origin) : "";
    const radiusKm = seller.deliveryRadiusKm;
    const distanceMeters = entry.distanceMeters;
    if (typeof sellerId !== "string" || sellerDistanceMeters.has(sellerId) ||
        !schedule || schedule.type !== "distance" || !origin ||
        entry.policyFingerprint !== distanceScheduleFingerprint(schedule) ||
        entry.originFingerprint !== originFingerprint || entry.radiusKm !== radiusKm ||
        typeof radiusKm !== "number" || !Number.isFinite(radiusKm) || radiusKm <= 0 || radiusKm > 100 ||
        !Number.isSafeInteger(distanceMeters) || (distanceMeters as number) < 0 ||
        (distanceMeters as number) > Math.round(radiusKm * 1000) ||
        entry.feePaise !== Math.round(computeFeeFromSchedule(schedule, 0, distanceMeters as number) * 100)) {
      throw new HttpsError("failed-precondition", "Seller delivery pricing changed. Please refresh checkout.");
    }
    sellerDistanceMeters.set(sellerId as string, distanceMeters as number);
  }
  if (sellerDistanceMeters.size !== distanceSellerCount) {
    throw new HttpsError("failed-precondition", "Seller delivery pricing changed. Please refresh checkout.");
  }
  return { ref, snap, sellerDistanceMeters };
}

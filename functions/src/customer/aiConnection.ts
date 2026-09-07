// ============================================================
//  Callables: connectAiProvider / disconnectAiProvider
// ============================================================
//
// Phase AI-1 (first of an AI Marketplace Assistant programme; owner decision,
// chat 2026-09-07): a customer connects their OWN ChatGPT or Gemini API key,
// gated by a one-time ₹50 AgriMore wallet debit ("AI Wallet activation fee").
// This file is backend-only — no client UI, no call to the provider itself.
// That is AI-2/AI-3's job; this phase only makes the connection possible to
// establish and store safely.
//
// This restores, in spirit, the AI chat feature that packages/agrimore_services/
// lib/ai/ai_chat_service.dart already implements against Gemini, but which has
// been dormant since Phase 21 (2026-08-30, finding 19-B): its shared Gemini key
// was committed to git, shipped inside every Play build, and revoked by the
// owner. packages/agrimore_core/lib/config/gemini_config.dart's own comment
// already states the required shape for ever restoring it — a Cloud Function
// proxy, the key in Secret Manager via defineSecret, never a client constant.
// This phase follows that shape, but for a DIFFERENT key than before: not one
// AgriMore-managed Gemini key shared by every user, but each user's own
// provider key, encrypted at rest under a key this codebase controls.
//
// Debit-then-ledger shape mirrors requestEmployeePayout.ts's transactional
// style (db.runTransaction, tx.get/tx.set, FieldValue.increment()) and
// wallet.ts's wallet_transactions bookkeeping. Secret binding mirrors
// payment.ts's RAZORPAY_KEY_SECRET (defineSecret + secrets: [...] on every
// importer) — never a client constant, never in plain functions/.env.
//
// Chosen defaults (this session's own judgement calls, not owner-confirmed —
// flagged in the phase's completion report for the owner to overrule):
//   - "one-time per connection" means one-time per ACTIVE connection
//     lifetime, not per keystroke: calling connectAiProvider again while
//     already connected (e.g. to rotate a key, or switch provider) is a free
//     update, not a new charge.
//   - disconnectAiProvider deletes the stored key outright. A subsequent
//     connectAiProvider is then treated as a brand-new activation and is
//     charged again — the existence of ai_connections/{uid} is the single
//     source of truth for "has this been paid for".
//   - No refund on disconnect, ever — mirrors the Sales Associate onboarding
//     fee precedent (refunds are record-only, never automatic).
//   - No live call to the provider at connect time to validate the key
//     (would spend the user's own quota on an unproven key, and an external
//     HTTP call has no place inside a Firestore transaction). The key is
//     validated for real the first time AI-2's proxy actually uses it.
//
// Storage shape: TWO collections, not one, so the encrypted key is never
// exposed to any client read — not even the owner's own:
//   - ai_connections/{uid}      fully Cloud-Functions-only (rules: read,
//     write both `if false`). Holds the encrypted key material.
//   - ai_connection_status/{uid} a client-readable-by-owner projection with
//     NO key material at all (provider, connected, connectedAt) — what the
//     Settings -> AI Integration screen (AI-3) will actually read.
// This deliberately avoids touching users/{uid} and its
// ownerCannotChangePrivilegedFields() denylist at all, keeping this phase's
// diff off that heavily-tested, historically collision-prone rule block.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Registers the Secret Manager parameter. Binding it to a specific function's
// `secrets: [...]` array (below) is what actually grants that function access
// at deploy time and injects it into `process.env.AI_KEY_ENCRYPTION_SECRET`.
// Must be a base64-encoded 32-byte (256-bit) key — see
// functions/.secret.local.example for the local emulator placeholder.
export const AI_KEY_ENCRYPTION_SECRET = defineSecret("AI_KEY_ENCRYPTION_SECRET");

const ALGORITHM = "aes-256-gcm";
const GCM_IV_LENGTH = 12; // bytes; the standard, recommended IV length for GCM
const ACTIVATION_FEE = 50;
const ALLOWED_PROVIDERS = ["gemini", "chatgpt"] as const;
type AiProvider = (typeof ALLOWED_PROVIDERS)[number];
// FIX-16 precedent: bound every client-supplied string before it is used or
// stored. Real provider keys (Gemini "AIza...", OpenAI "sk-...") are well
// under 100 characters; 200 leaves headroom without inviting abuse.
const MAX_API_KEY_LENGTH = 200;

interface EncryptedPayload {
  ciphertext: string; // base64
  iv: string; // base64
  authTag: string; // base64
}

function getEncryptionKey(): Buffer {
  const raw = process.env.AI_KEY_ENCRYPTION_SECRET || "";
  const key = Buffer.from(raw, "base64");
  // Fail closed: a misconfigured or missing secret must never silently fall
  // back to a weaker/derived key.
  if (key.length !== 32) {
    throw new HttpsError(
      "failed-precondition",
      "AI key encryption is not configured correctly"
    );
  }
  return key;
}

export function encryptApiKey(plaintext: string): EncryptedPayload {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(GCM_IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  return {
    ciphertext: encrypted.toString("base64"),
    iv: iv.toString("base64"),
    authTag: authTag.toString("base64"),
  };
}

export function decryptApiKey(payload: EncryptedPayload): string {
  const key = getEncryptionKey();
  const decipher = crypto.createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(payload.iv, "base64")
  );
  decipher.setAuthTag(Buffer.from(payload.authTag, "base64"));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(payload.ciphertext, "base64")),
    decipher.final(),
  ]);
  return decrypted.toString("utf8");
}

interface ConnectAiProviderData {
  provider?: string;
  apiKey?: string;
}

export const connectAiProvider = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [AI_KEY_ENCRYPTION_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as ConnectAiProviderData;
    const provider = typeof data?.provider === "string" ? data.provider : "";
    const apiKey = typeof data?.apiKey === "string" ? data.apiKey : "";

    if (!(ALLOWED_PROVIDERS as readonly string[]).includes(provider)) {
      throw new HttpsError(
        "invalid-argument",
        `provider must be one of: ${ALLOWED_PROVIDERS.join(", ")}`
      );
    }
    if (apiKey.trim().length === 0) {
      throw new HttpsError("invalid-argument", "apiKey must not be empty");
    }
    if (apiKey.length > MAX_API_KEY_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `apiKey must be at most ${MAX_API_KEY_LENGTH} characters`
      );
    }

    const db = admin.firestore();
    const walletRef = db.collection("wallets").doc(uid);
    const connectionRef = db.collection("ai_connections").doc(uid);
    const statusRef = db.collection("ai_connection_status").doc(uid);
    const walletTransactionRef = db.collection("wallet_transactions").doc();

    // Encrypted outside the transaction: crypto.createCipheriv is pure CPU
    // work with no Firestore read/write of its own, so there is nothing to
    // gain from doing it inside the transaction's retry window, and doing it
    // outside keeps the transaction body limited to reads-then-writes.
    const encrypted = encryptApiKey(apiKey);

    const result = await db.runTransaction(async (tx) => {
      const [connectionSnap, walletSnap] = await Promise.all([
        tx.get(connectionRef),
        tx.get(walletRef),
      ]);
      const alreadyConnected = connectionSnap.exists;

      if (!alreadyConnected) {
        const currentBalance =
          (walletSnap.data()?.balance as number | undefined) ?? 0;
        if (currentBalance < ACTIVATION_FEE) {
          throw new HttpsError("failed-precondition", "Insufficient balance");
        }
        const balanceAfter = currentBalance - ACTIVATION_FEE;

        tx.set(
          walletRef,
          {
            balance: admin.firestore.FieldValue.increment(-ACTIVATION_FEE),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(walletTransactionRef, {
          walletId: uid,
          userId: uid,
          type: "debit",
          source: "aiActivation",
          amount: ACTIVATION_FEE,
          coins: 0,
          balanceAfter,
          coinsAfter: walletSnap.data()?.coins ?? 0,
          orderId: null,
          description: `AI Assistant activation (${provider})`,
          referenceId: connectionRef.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: null,
          metadata: { provider },
        });
      }

      const connectionUpdate: Record<string, unknown> = {
        uid,
        provider,
        encryptedKey: encrypted.ciphertext,
        iv: encrypted.iv,
        authTag: encrypted.authTag,
        algorithm: ALGORITHM,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      const statusUpdate: Record<string, unknown> = {
        provider,
        connected: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (!alreadyConnected) {
        connectionUpdate.connectedAt = admin.firestore.FieldValue.serverTimestamp();
        statusUpdate.connectedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      tx.set(connectionRef, connectionUpdate, { merge: true });
      tx.set(statusRef, statusUpdate, { merge: true });

      return { activated: !alreadyConnected, rotated: alreadyConnected };
    });

    return {
      success: true,
      provider: provider as AiProvider,
      activated: result.activated,
      rotated: result.rotated,
    };
  }
);

export const disconnectAiProvider = onCall(
  { minInstances: 0, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const db = admin.firestore();
    const connectionRef = db.collection("ai_connections").doc(uid);
    const statusRef = db.collection("ai_connection_status").doc(uid);

    const connectionSnap = await connectionRef.get();
    if (!connectionSnap.exists) {
      // Idempotent no-op: disconnecting when nothing was connected is not an
      // error (mirrors verifyWalletTopup's alreadyCredited-style idempotency
      // philosophy, adapted to a delete instead of a second credit).
      return { success: true, wasConnected: false };
    }

    // No refund is issued here, deliberately — see the file header.
    const batch = db.batch();
    batch.delete(connectionRef);
    batch.set(statusRef, {
      provider: null,
      connected: false,
      connectedAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return { success: true, wasConnected: true };
  }
);

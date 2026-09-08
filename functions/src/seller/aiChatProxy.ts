// ============================================================
//  Callable: sellerAiChatProxy
// ============================================================
//
// Phase AI-4B — the seller-side counterpart to functions/src/customer/
// aiChatProxy.ts (Phase AI-2). Structurally a clone of that file: this is
// ALSO a thin, stateless relay between the client and the Gemini REST API,
// using the caller's own key (connected via functions/src/seller/
// aiConnection.ts's connectSellerAiProvider, OR functions/src/customer/
// aiConnection.ts's connectAiProvider — both write the same uid-keyed
// ai_connections/{uid} doc, read here exactly as AI-2 reads it). It does
// NOT execute a tool call itself, exactly like AI-2 — when Gemini's
// response contains a functionCall, this returns {type:"functionCall",
// name, args} to the CLIENT, which is responsible for actually running the
// query and appending the result before calling this again.
//
// This is why the phase note's own framing ("the security-critical
// authorization boundary") does not describe THIS file: a thin relay that
// never reads product/order data itself cannot leak another seller's data
// through a crafted prompt or tool argument, no matter what TOOLS declares
// or what Gemini decides to call — the only Firestore read here is the
// caller's OWN ai_connections/{uid} doc, uid-scoped identically to AI-2's
// own callable. The real authorization-sensitive work is whichever CLIENT
// code eventually executes these tool calls (a later phase, out of scope
// here) — it must query with an explicit sellerId == request.auth.uid
// filter, relying on firestore.rules' own existing per-document ownership
// check on orders/{orderId} (line ~533: `resource.data.sellerId ==
// request.auth.uid`) exactly as a customer's own client code already
// relies on the userId branch of that same rule. products/{productId} is
// `allow read: if true` (public catalog) regardless of caller role, so a
// seller's own product tools need no scoping at all.
//
// Input-bounds constants and validateContents() below are duplicated from
// aiChatProxy.ts rather than imported, matching this codebase's own
// established "small, self-contained logic stays duplicated across a
// customer/seller split" convention (e.g. createOrder.ts vs.
// createOrderFromRfq.ts) rather than introducing a shared-module edit to a
// file this phase's own contract does not list under may_write. If either
// copy's bounds change, change both.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";
import { AI_KEY_ENCRYPTION_SECRET, decryptApiKey } from "../customer/aiConnection";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// Direct analogs of aiChatProxy.ts's own TOOLS, scoped to a seller's own
// data by NAME and DESCRIPTION only (Gemini is steered toward requesting
// seller-relevant functions) — getCategories/getAvailableCoupons are
// customer-facing promotional concepts with no seller-side equivalent, so
// they are simply omitted rather than reused.
const TOOLS = [
  {
    functionDeclarations: [
      {
        name: "getMySellerProducts",
        description: "Searches your own product catalog.",
        parameters: {
          type: "OBJECT",
          properties: {
            query: { type: "STRING", description: "Product search query" },
            limit: { type: "INTEGER", description: "Max results" },
          },
        },
      },
      {
        name: "getMySellerProductDetails",
        description: "Get detailed info about one of your own products.",
        parameters: {
          type: "OBJECT",
          properties: { productId: { type: "STRING", description: "Product ID" } },
          required: ["productId"],
        },
      },
      {
        name: "getMySellerOrders",
        description: "Fetch your own recent sales orders.",
        parameters: {
          type: "OBJECT",
          properties: {
            limit: { type: "INTEGER", description: "Number of orders" },
            status: { type: "STRING", description: "Order status filter" },
          },
        },
      },
      {
        name: "getMySellerOrderDetails",
        description: "Get details of one of your own sales orders.",
        parameters: {
          type: "OBJECT",
          properties: { orderId: { type: "STRING", description: "Order ID" } },
          required: ["orderId"],
        },
      },
      {
        name: "getMySellerProfile",
        description: "Get your own seller profile info.",
        parameters: { type: "OBJECT", properties: {} },
      },
    ],
  },
];

const MAX_CONTENTS_TURNS = 40;
const MAX_PART_TEXT_LENGTH = 4000;
const MAX_SERIALIZED_BYTES = 60_000;

interface GeminiPart {
  text?: string;
  functionCall?: { name: string; args: Record<string, unknown> };
  functionResponse?: { name: string; response: Record<string, unknown> };
}
interface GeminiContent {
  role: string;
  parts: GeminiPart[];
}

function validateContents(contents: unknown): GeminiContent[] {
  if (!Array.isArray(contents) || contents.length === 0) {
    throw new HttpsError("invalid-argument", "contents must be a non-empty array");
  }
  if (contents.length > MAX_CONTENTS_TURNS) {
    throw new HttpsError(
      "invalid-argument",
      `contents must have at most ${MAX_CONTENTS_TURNS} turns`
    );
  }
  if (Buffer.byteLength(JSON.stringify(contents), "utf8") > MAX_SERIALIZED_BYTES) {
    throw new HttpsError("invalid-argument", "contents payload is too large");
  }
  for (const turn of contents) {
    if (
      typeof turn !== "object" ||
      turn === null ||
      typeof (turn as GeminiContent).role !== "string" ||
      !Array.isArray((turn as GeminiContent).parts)
    ) {
      throw new HttpsError("invalid-argument", "each contents entry must be {role, parts}");
    }
    for (const part of (turn as GeminiContent).parts) {
      if (typeof part !== "object" || part === null) {
        throw new HttpsError("invalid-argument", "each part must be an object");
      }
      if (typeof part.text === "string" && part.text.length > MAX_PART_TEXT_LENGTH) {
        throw new HttpsError(
          "invalid-argument",
          `a text part must be at most ${MAX_PART_TEXT_LENGTH} characters`
        );
      }
    }
  }
  return contents as GeminiContent[];
}

async function buildSystemPrompt(uid: string): Promise<string> {
  let sellerName = "the seller";
  try {
    const sellerSnap = await admin.firestore().collection("sellers").doc(uid).get();
    const name = sellerSnap.data()?.businessName;
    if (typeof name === "string" && name.trim().length > 0) sellerName = name;
  } catch {
    // A profile lookup failure must not break the chat -- fall back
    // silently, mirroring aiChatProxy.ts's own identical behaviour.
  }
  return `You are Agrimore AI, a friendly, helpful assistant for sellers on the Agrimore marketplace.
Seller: ${sellerName}
Provide relevant insights about YOUR OWN products and sales orders only.
Follow these rules:
- Be concise
- Use markdown
- Use data from your database when asked about your own products or orders.
- Never discuss, imply, or attempt to access another seller's data.
- Do not mention AI or models.
- Assist with product performance, order status, and your own profile info.
- Always respond nicely and helpfully.
`;
}

interface SellerAiChatProxyData {
  contents?: unknown;
}

export const sellerAiChatProxy = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [AI_KEY_ENCRYPTION_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as SellerAiChatProxyData;
    const contents = validateContents(data?.contents);

    const db = admin.firestore();
    const connectionSnap = await db.collection("ai_connections").doc(uid).get();
    if (!connectionSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Connect an AI provider in Settings before using the AI Assistant"
      );
    }
    const connection = connectionSnap.data() as {
      provider: string;
      encryptedKey: string;
      iv: string;
      authTag: string;
    };

    // Only Gemini is implemented, mirroring aiChatProxy.ts's own identical
    // scope limit -- ChatGPT connections are stored (AI-1) but have no
    // proxy path yet, for either role.
    if (connection.provider !== "gemini") {
      throw new HttpsError(
        "failed-precondition",
        `AI chat is not yet available for provider "${connection.provider}"`
      );
    }

    const apiKey = decryptApiKey({
      ciphertext: connection.encryptedKey,
      iv: connection.iv,
      authTag: connection.authTag,
    });

    const systemPrompt = await buildSystemPrompt(uid);

    try {
      const response = await axios.post(
        GEMINI_URL,
        {
          contents,
          tools: TOOLS,
          systemInstruction: { parts: [{ text: systemPrompt }] },
        },
        {
          params: { key: apiKey },
          headers: { "Content-Type": "application/json" },
          timeout: 30_000,
        }
      );

      const candidate = response.data?.candidates?.[0];
      const part = candidate?.content?.parts?.[0];

      if (part?.functionCall?.name) {
        return {
          type: "functionCall",
          name: part.functionCall.name,
          args: part.functionCall.args || {},
        };
      }

      const text = typeof part?.text === "string" ? part.text : "";
      return {
        type: "text",
        text: text.length > 0 ? text : "Sorry, I could not process that request.",
      };
    } catch (e) {
      // NEVER log the raw error object here: axios attaches the full
      // request config to a thrown error, and the request URL carries
      // `key=<the seller's own decrypted API key>` as a query param --
      // logging it would put a live third-party credential into Cloud
      // Logging in plaintext. Mirrors aiChatProxy.ts's own identical
      // discipline.
      const status = axios.isAxiosError(e) ? e.response?.status : undefined;
      const providerMessage = axios.isAxiosError(e)
        ? e.response?.data?.error?.message
        : undefined;
      if (status === 400 || status === 403) {
        throw new HttpsError(
          "failed-precondition",
          "Your connected AI provider key was rejected. Reconnect it in Settings."
        );
      }
      throw new HttpsError(
        "internal",
        typeof providerMessage === "string"
          ? `AI provider error: ${providerMessage}`
          : "Failed to reach the AI provider"
      );
    }
  }
);

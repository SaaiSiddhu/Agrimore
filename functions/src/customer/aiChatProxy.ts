// ============================================================
//  Callable: aiChatProxy
// ============================================================
//
// Phase AI-2: the ONLY thing this function does is stand between the client
// and the Gemini REST API, using the caller's OWN key (connected via
// AI-1's connectAiProvider, stored encrypted in ai_connections/{uid}) so
// that key is never present on the client. It is deliberately a thin,
// stateless relay — it does NOT reimplement packages/agrimore_services/lib/
// ai/ai_chat_service.dart's product/order/category/coupon lookups. Those
// stay exactly where they already were (client-side, under firestore.rules,
// which already scope them correctly per-user) because they were never the
// problem: the ONLY thing Phase 21 (2026-08-30, finding 19-B) found exposed
// was the Gemini API key itself, hardcoded and shipped in every Play build.
//
// Shape: the client sends the FULL `contents` array in Gemini's own REST
// format (not the google_generative_ai SDK's Content objects, which cannot
// cross a Cloud Functions callable boundary as-is). This function appends
// nothing to that history and remembers nothing between calls — the CLIENT
// is responsible for building the next `contents` array (appending the
// model's function-call turn and the function's response turn) before
// calling this again for the two-call function-calling sequence documented
// in ai_chat_service.dart's handleGeminiResponse. This is a deliberate
// simplification over the original claim row's two-shape design (a plain
// `{contents}` request/response pair is enough; a separate `functionResult`
// payload shape would just be re-deriving the same thing less directly).
//
// Tool declarations are HARDCODED here, not accepted from the client — the
// codebase's standing rule that nothing client-supplied is ever trusted as
// authoritative applies exactly as much to "which functions the model may
// call" as it does to a price or a role claim.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";
import { AI_KEY_ENCRYPTION_SECRET, decryptApiKey } from "./aiConnection";

const GEMINI_MODEL = "gemini-2.5-flash"; // matches ai_chat_service.dart's model: 'gemini-2.5-flash'
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// Mirrors packages/agrimore_services/lib/ai/ai_chat_service.dart's `tools`
// field (lines ~16-72) exactly, translated from the google_generative_ai
// SDK's Tool/FunctionDeclaration/Schema classes into the plain JSON shape
// Gemini's REST API expects for the same concept. Any change to the seven
// handleXxx methods' arguments in ai_chat_service.dart must be mirrored here
// by hand — there is no shared source between the Dart and TypeScript
// copies of this schema.
const TOOLS = [
  {
    functionDeclarations: [
      {
        name: "searchProducts",
        description: "Searches around your query in the product catalog.",
        parameters: {
          type: "OBJECT",
          properties: {
            query: { type: "STRING", description: "Product search query" },
            categoryId: { type: "STRING", description: "Optional category filter" },
            limit: { type: "INTEGER", description: "Max results" },
          },
        },
      },
      {
        name: "getProductDetails",
        description: "Get detailed info about a specific product.",
        parameters: {
          type: "OBJECT",
          properties: { productId: { type: "STRING", description: "Product ID" } },
          required: ["productId"],
        },
      },
      {
        name: "getOrders",
        description: "Fetch the current user's recent orders.",
        parameters: {
          type: "OBJECT",
          properties: {
            limit: { type: "INTEGER", description: "Number of orders" },
            status: { type: "STRING", description: "Order status filter" },
          },
        },
      },
      {
        name: "getOrderDetails",
        description: "Get details of a specific order.",
        parameters: {
          type: "OBJECT",
          properties: { orderId: { type: "STRING", description: "Order ID" } },
          required: ["orderId"],
        },
      },
      {
        name: "getUserProfile",
        description: "Get your profile info.",
        parameters: { type: "OBJECT", properties: {} },
      },
      {
        name: "getCategories",
        description: "Get all product categories.",
        parameters: { type: "OBJECT", properties: {} },
      },
      {
        name: "getAvailableCoupons",
        description: "Fetch active coupons.",
        parameters: { type: "OBJECT", properties: {} },
      },
    ],
  },
];

// Input bounds (FIX-16 precedent: every client-supplied structure is bounded
// before use, never trusted to be reasonably sized just because it usually
// is). A real conversation in this app is a handful of short turns; these
// ceilings are a generous engineering margin, not a measured product limit.
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

// Mirrors ai_chat_service.dart's buildSystemPrompt() exactly, re-implemented
// server-side since the client no longer builds the request that needs it.
async function buildSystemPrompt(uid: string): Promise<string> {
  let userName = "the user";
  try {
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    const name = userSnap.data()?.name;
    if (typeof name === "string" && name.trim().length > 0) userName = name;
  } catch {
    // A profile lookup failure must not break the chat — fall back silently,
    // exactly as the Dart original does (userProfileCache stays null there).
  }
  return `You are Agrimore AI, a friendly, helpful assistant for agricultural products and orders.
User: ${userName}
Provide relevant product recommendations, order info, and answer general questions.
Follow these rules:
- Be concise
- Use markdown
- Use data from your database when asked about products, orders, or categories.
- Do not mention AI or models.
- Assist with online shopping, order tracking, coupons, and categories.
- Always respond nicely and helpfully.
`;
}

interface AiChatProxyData {
  contents?: unknown;
}

export const aiChatProxy = onCall(
  { minInstances: 0, memory: "256MiB", secrets: [AI_KEY_ENCRYPTION_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const data = request.data as AiChatProxyData;
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

    // Only Gemini is implemented in this phase. ChatGPT connections are
    // stored (AI-1) but have no proxy path yet — a deliberate, disclosed
    // scope limit, not an oversight.
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
      // NEVER log the raw error object here: axios attaches the full request
      // config to a thrown error, and the request URL carries `key=<the
      // user's own decrypted API key>` as a query param — logging it would
      // put a live third-party credential into Cloud Logging in plaintext.
      const status = axios.isAxiosError(e) ? e.response?.status : undefined;
      const providerMessage = axios.isAxiosError(e)
        ? e.response?.data?.error?.message
        : undefined;
      if (status === 400 || status === 403) {
        // Gemini's own shape for "your key is invalid/revoked/lacks access".
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

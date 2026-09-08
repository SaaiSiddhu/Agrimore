// Phase AI-4B: proves sellerAiChatProxy against a real emulator (Firestore
// + Auth), with the outbound Gemini HTTP call mocked at the axios boundary
// -- mirrors phase38_ai_chat_proxy_test.js's own pattern exactly (patching
// require('axios') before requiring the compiled function). Also proves
// the seller-scoped TOOLS/system-prompt divergence from AI-2's own
// customer proxy: 5 seller-named tool declarations (not the customer's 7),
// and a system prompt built from sellers/{uid}.businessName rather than
// users/{uid}.name.
// Run with: node scripts/phase46_seller_ai_chat_proxy_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.AI_KEY_ENCRYPTION_SECRET = Buffer.alloc(32, 9).toString("base64");

const axios = require("axios");
const mockResponses = [];
let capturedRequests = [];
const originalPost = axios.post.bind(axios);
axios.post = async (url, body, config) => {
  capturedRequests.push({ url, body, config });
  if (mockResponses.length === 0) return originalPost(url, body, config);
  const next = mockResponses.shift();
  if (next.reject) throw next.reject;
  return { data: next.data };
};

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const { sellerAiChatProxy } = require("../lib/seller/aiChatProxy");
const { encryptApiKey } = require("../lib/customer/aiConnection");

const wrapped = test.wrap(sellerAiChatProxy);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedApprovedSeller(db, uid) {
  await db.collection("sellers").doc(uid).set({ uid, status: "approved" }, { merge: true });
}

async function seedConnection(db, uid, provider, plaintextKey) {
  const encrypted = encryptApiKey(plaintextKey);
  await db.collection("ai_connections").doc(uid).set({
    uid,
    provider,
    encryptedKey: encrypted.ciphertext,
    iv: encrypted.iv,
    authTag: encrypted.authTag,
    algorithm: "aes-256-gcm",
    connectedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

const SAMPLE_CONTENTS = [{ role: "user", parts: [{ text: "how are my sales this week" }] }];

const EXPECTED_SELLER_TOOL_NAMES = [
  "getMySellerProducts",
  "getMySellerProductDetails",
  "getMySellerOrders",
  "getMySellerOrderDetails",
  "getMySellerProfile",
];

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};
  const record = (key, passed, detail) => {
    results[key] = passed;
    console.log(`${key}:`, passed ? `PASSED — ${detail}` : `FAILED — ${detail}`);
    if (!passed) allPassed = false;
  };

  console.log("=== PHASE AI-4B — sellerAiChatProxy ===");

  // Scenario 1: unauthenticated is rejected.
  {
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, undefined);
    record("scenario1_unauthenticated", !r.ok && r.code === "unauthenticated", `code=${r.code}`);
  }

  // Scenario 2: no connection at all -> failed-precondition pointing at Settings.
  {
    const uid = "phase46-seller-noconnection";
    await seedApprovedSeller(db, uid);
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario2_no_connection",
      !r.ok && r.code === "failed-precondition" && /Connect an AI provider/.test(r.message),
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 3: connected to chatgpt (not yet implemented) -> failed-precondition.
  {
    const uid = "phase46-seller-chatgpt";
    await seedApprovedSeller(db, uid);
    await seedConnection(db, uid, "chatgpt", "sk-fakeTestKeyPhase46");
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario3_chatgpt_unimplemented",
      !r.ok && r.code === "failed-precondition" && /not yet available/.test(r.message),
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 4 -- POSITIVE CONTROL: real connect->encrypt->store->decrypt->use
  // round trip, text response, seller-scoped tools sent, system prompt uses
  // the seller's own businessName.
  const uid4 = "phase46-seller-textresponse";
  const PLAINTEXT_KEY_4 = "AIzaFakeRoundTripTestKey0004Seller";
  {
    await db.collection("sellers").doc(uid4).set({ uid: uid4, businessName: "Green Valley Farms", status: "approved" });
    await seedConnection(db, uid4, "gemini", PLAINTEXT_KEY_4);
    mockResponses.push({
      data: { candidates: [{ content: { role: "model", parts: [{ text: "Your sales are up 12% this week!" }] } }] },
    });
    capturedRequests = [];
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid: uid4, token: {} });
    let s, detail;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.type !== "text" || r.result.text !== "Your sales are up 12% this week!") {
        throw new Error(`unexpected result: ${JSON.stringify(r.result)}`);
      }
      if (capturedRequests.length !== 1) throw new Error(`expected exactly 1 outbound call, got ${capturedRequests.length}`);
      const sentKey = capturedRequests[0].config?.params?.key;
      if (sentKey !== PLAINTEXT_KEY_4) {
        throw new Error(`round-trip mismatch: connected with "${PLAINTEXT_KEY_4}", proxy sent "${sentKey}" to Gemini`);
      }
      const sentTools = capturedRequests[0].body?.tools;
      const sentNames = sentTools?.[0]?.functionDeclarations?.map((f) => f.name) || [];
      const namesMatch =
        sentNames.length === EXPECTED_SELLER_TOOL_NAMES.length &&
        EXPECTED_SELLER_TOOL_NAMES.every((n) => sentNames.includes(n));
      if (!namesMatch) {
        throw new Error(`expected exactly the 5 seller tool names, got ${JSON.stringify(sentNames)}`);
      }
      const systemPromptText = capturedRequests[0].body?.systemInstruction?.parts?.[0]?.text || "";
      if (!systemPromptText.includes("Green Valley Farms")) {
        throw new Error(`expected the system prompt to include the seller's own businessName, got: ${systemPromptText}`);
      }
      if (systemPromptText.toLowerCase().includes("customer")) {
        throw new Error(`system prompt unexpectedly reads as customer-oriented: ${systemPromptText}`);
      }
      s = true;
      detail = `text response returned, key round-tripped, exactly 5 seller-scoped tools sent, prompt personalised to "Green Valley Farms"`;
    } catch (e) {
      s = false;
      detail = e.message;
    }
    record("scenario4_text_response_roundtrip_seller_scoped", s, detail);
  }

  // Scenario 5: functionCall response is relayed as-is, naming a seller tool.
  {
    const uid = "phase46-seller-functioncall";
    await seedApprovedSeller(db, uid);
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario5");
    mockResponses.push({
      data: {
        candidates: [
          {
            content: {
              role: "model",
              parts: [{ functionCall: { name: "getMySellerOrders", args: { limit: 5 } } }],
            },
          },
        ],
      },
    });
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario5_function_call_relay",
      r.ok && r.result.type === "functionCall" && r.result.name === "getMySellerOrders" && r.result.args.limit === 5,
      `result=${JSON.stringify(r.result)}`
    );
  }

  // Scenario 6: empty contents is rejected.
  {
    const uid = "phase46-seller-emptycontents";
    await seedApprovedSeller(db, uid);
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario6");
    const r = await callAndCapture({ contents: [] }, { uid, token: {} });
    record("scenario6_empty_contents", !r.ok && r.code === "invalid-argument", `code=${r.code}`);
  }

  // Scenario 7: oversized contents (too many turns) is rejected.
  {
    const uid = "phase46-seller-oversized";
    await seedApprovedSeller(db, uid);
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario7");
    const tooMany = Array.from({ length: 50 }, (_, i) => ({
      role: i % 2 === 0 ? "user" : "model",
      parts: [{ text: `turn ${i}` }],
    }));
    const r = await callAndCapture({ contents: tooMany }, { uid, token: {} });
    record("scenario7_oversized_contents", !r.ok && r.code === "invalid-argument", `code=${r.code}`);
  }

  // Scenario 8: a Gemini 403 (invalid/revoked key) never leaks the actual
  // key value into the thrown error message.
  {
    const uid = "phase46-seller-invalidkey";
    const CONNECTED_TEST_KEY_8 = "AIzaSuperSecretPhase46Scenario8DoNotLeak";
    await seedApprovedSeller(db, uid);
    await seedConnection(db, uid, "gemini", CONNECTED_TEST_KEY_8);
    const axiosError = new Error("Request failed with status code 403");
    axiosError.isAxiosError = true;
    axiosError.response = { status: 403, data: { error: { message: "API key not valid" } } };
    axiosError.config = { url: "https://generativelanguage.googleapis.com/...", params: { key: CONNECTED_TEST_KEY_8 } };
    mockResponses.push({ reject: axiosError });
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario8_no_key_leak_on_error",
      !r.ok && r.code === "failed-precondition" && !r.message.includes(CONNECTED_TEST_KEY_8),
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 9: a seller carrying the `seller` custom claim (no
  // sellers/{uid} doc at all -- a plausible real state right after
  // approval, before any business details are filled in) still gets a
  // working chat (fallback name), proving buildSystemPrompt's own
  // try/catch degrades gracefully exactly like aiChatProxy.ts's original,
  // AND that requireApprovedSeller's claim-first branch is genuinely
  // sufficient on its own (no Firestore doc needed).
  {
    const uid = "phase46-seller-noprofiledoc";
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario9");
    mockResponses.push({
      data: { candidates: [{ content: { role: "model", parts: [{ text: "Sure, happy to help." }] } }] },
    });
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: { seller: true } });
    record(
      "scenario9_missing_profile_doc_degrades_gracefully",
      r.ok && r.result.type === "text",
      `ok=${r.ok} result=${JSON.stringify(r.result)}`
    );
  }

  // ==================================================================
  // Security-lane finding, self-caught before VERIFY: request.auth plus a
  // connected ai_connections/{uid} doc alone proves only "some authenticated
  // user who has connected SOME AI provider" -- not "an approved seller".
  // Since AI-1's own connectAiProvider (customer-side, wallet-funded)
  // writes the IDENTICAL ai_connections/{uid} doc, without
  // requireApprovedSeller a plain customer could call this seller-scoped
  // proxy and receive seller-oriented tools/prompt.
  // ==================================================================

  // Scenario 10: an authenticated user with NO sellers/{uid} doc and NO
  // seller claim -- i.e. a plain customer -- is rejected outright, even
  // with a fully valid, connected Gemini key.
  {
    const uid = "phase46-not-a-seller";
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario10");
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario10_rejects_non_seller_even_with_valid_connection",
      !r.ok && r.code === "permission-denied",
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 11: the exact cross-namespace case the finding describes -- a
  // customer who connected via AI-1's OWN connectAiProvider (not the
  // seller funding path) still cannot reach the seller-scoped proxy.
  {
    const uid = "phase46-real-customer-ai1";
    // Mirrors exactly what connectAiProvider itself writes -- same
    // collection, same shape, seeded directly since this test only needs
    // to prove the DOWNSTREAM authorization check, not re-prove AI-1's own
    // wallet-debit flow (already covered by phase37_ai_wallet_connection_test.js).
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario11");
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario11_rejects_customer_side_ai1_connection",
      !r.ok && r.code === "permission-denied",
      `code=${r.code} message="${r.message}"`
    );
  }

  // Scenario 12: a PENDING (not yet approved) seller is rejected too --
  // doc existence alone is not enough, mirroring AI-4's own equivalent
  // scenario for createSellerAiActivationOrder/connectSellerAiProvider.
  {
    const uid = "phase46-pending-seller";
    await db.collection("sellers").doc(uid).set({ uid, status: "pending" });
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase46Scenario12");
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    record(
      "scenario12_rejects_pending_seller",
      !r.ok && r.code === "permission-denied",
      `code=${r.code} message="${r.message}"`
    );
  }

  console.log("=== PHASE AI-4B SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v ? "PASSED" : "FAILED");
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase46 seller AI chat proxy test:", e);
  process.exit(1);
});

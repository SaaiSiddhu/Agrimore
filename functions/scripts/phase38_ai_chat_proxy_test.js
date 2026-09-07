// Phase AI-2: proves aiChatProxy against a real emulator (Firestore + Auth),
// with the outbound Gemini HTTP call mocked at the axios boundary — mirrors
// phase9_wallet_topup_test.js's pattern of patching require('axios') BEFORE
// requiring the compiled function, since axios is a CommonJS singleton.
// Also proves the full encrypt-store-decrypt-use round trip end to end by
// seeding a REAL encrypted connection via aiConnection.ts's own
// encryptApiKey, then asserting the exact plaintext key aiChatProxy sends to
// (mocked) Gemini matches what was originally connected.
// Run with: node scripts/phase38_ai_chat_proxy_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
process.env.AI_KEY_ENCRYPTION_SECRET = Buffer.alloc(32, 9).toString("base64");

const axios = require("axios");
const mockResponses = []; // queue of {status, data} or {reject: error} consumed in order
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
const { aiChatProxy } = require("../lib/customer/aiChatProxy");
const { encryptApiKey } = require("../lib/customer/aiConnection");

const wrapped = test.wrap(aiChatProxy);

async function callAndCapture(payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
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

const SAMPLE_CONTENTS = [{ role: "user", parts: [{ text: "show me tomato seeds" }] }];

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE AI-2 — aiChatProxy ===");

  // Scenario 1: unauthenticated is rejected.
  {
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, undefined);
    results.scenario1_unauthenticated =
      !r.ok && r.code === "unauthenticated"
        ? `PASSED — rejected as expected. code=${r.code}`
        : `FAILED — expected unauthenticated, got ok=${r.ok} code=${r.code}`;
    if (!results.scenario1_unauthenticated.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 1:", results.scenario1_unauthenticated);
  }

  // Scenario 2: no connection at all -> failed-precondition pointing at Settings.
  {
    const uid = "phase38-user-noconnection";
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    let s;
    if (r.ok) {
      s = "FAILED — chat succeeded with no AI connection at all";
    } else if (r.code !== "failed-precondition" || !/Connect an AI provider/.test(r.message)) {
      s = `FAILED — expected failed-precondition pointing at Settings, got code=${r.code} message="${r.message}"`;
    } else {
      s = `PASSED — rejected as expected. message="${r.message}"`;
    }
    results.scenario2_no_connection = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: connected to chatgpt (not yet implemented) -> failed-precondition.
  {
    const uid = "phase38-user-chatgpt";
    await seedConnection(db, uid, "chatgpt", "sk-fakeTestKeyPhase38");
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    let s;
    if (r.ok) {
      s = "FAILED — chat succeeded for an unimplemented provider";
    } else if (r.code !== "failed-precondition" || !/not yet available/.test(r.message)) {
      s = `FAILED — expected failed-precondition 'not yet available', got code=${r.code} message="${r.message}"`;
    } else {
      s = `PASSED — rejected as expected. message="${r.message}"`;
    }
    results.scenario3_chatgpt_unimplemented = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: real connect->encrypt->store->decrypt->use round trip, text response.
  const uid4 = "phase38-user-textresponse";
  const PLAINTEXT_KEY_4 = "AIzaFakeRoundTripTestKey0004";
  {
    await seedConnection(db, uid4, "gemini", PLAINTEXT_KEY_4);
    mockResponses.push({
      data: { candidates: [{ content: { role: "model", parts: [{ text: "Here are some tomato seeds!" }] } }] },
    });
    capturedRequests = [];
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid: uid4, token: {} });
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.type !== "text" || r.result.text !== "Here are some tomato seeds!") {
        throw new Error(`unexpected result: ${JSON.stringify(r.result)}`);
      }
      if (capturedRequests.length !== 1) throw new Error(`expected exactly 1 outbound call, got ${capturedRequests.length}`);
      const sentKey = capturedRequests[0].config?.params?.key;
      if (sentKey !== PLAINTEXT_KEY_4) {
        throw new Error(`round-trip mismatch: connected with "${PLAINTEXT_KEY_4}", proxy sent "${sentKey}" to Gemini`);
      }
      const sentTools = capturedRequests[0].body?.tools;
      if (!Array.isArray(sentTools) || sentTools[0]?.functionDeclarations?.length !== 7) {
        throw new Error(`expected all 7 hardcoded tool declarations sent, got ${JSON.stringify(sentTools)}`);
      }
      s = `PASSED — text response returned, key round-tripped correctly (connected "${PLAINTEXT_KEY_4}" -> sent "${sentKey}"), 7 tools sent`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
    }
    results.scenario4_text_response_roundtrip = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 4:", s);
  }

  // Scenario 5: functionCall response is relayed as-is for the client to execute.
  {
    const uid = "phase38-user-functioncall";
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase38Scenario5");
    mockResponses.push({
      data: {
        candidates: [
          {
            content: {
              role: "model",
              parts: [{ functionCall: { name: "searchProducts", args: { query: "tomato" } } }],
            },
          },
        ],
      },
    });
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    let s;
    if (!r.ok) {
      s = `FAILED — expected success, got code=${r.code} message=${r.message}`;
    } else if (r.result.type !== "functionCall" || r.result.name !== "searchProducts" || r.result.args.query !== "tomato") {
      s = `FAILED — unexpected result: ${JSON.stringify(r.result)}`;
    } else {
      s = `PASSED — functionCall relayed correctly: ${JSON.stringify(r.result)}`;
    }
    results.scenario5_function_call_relay = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: empty contents is rejected.
  {
    const uid = "phase38-user-emptycontents";
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase38Scenario6");
    const r = await callAndCapture({ contents: [] }, { uid, token: {} });
    const s =
      !r.ok && r.code === "invalid-argument"
        ? `PASSED — rejected as expected. message="${r.message}"`
        : `FAILED — expected invalid-argument, got ok=${r.ok} code=${r.code}`;
    results.scenario6_empty_contents = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 6:", s);
  }

  // Scenario 7: oversized contents (too many turns) is rejected.
  {
    const uid = "phase38-user-oversized";
    await seedConnection(db, uid, "gemini", "AIzaFakeTestKeyPhase38Scenario7");
    const tooMany = Array.from({ length: 50 }, (_, i) => ({
      role: i % 2 === 0 ? "user" : "model",
      parts: [{ text: `turn ${i}` }],
    }));
    const r = await callAndCapture({ contents: tooMany }, { uid, token: {} });
    const s =
      !r.ok && r.code === "invalid-argument"
        ? `PASSED — rejected as expected. message="${r.message}"`
        : `FAILED — expected invalid-argument, got ok=${r.ok} code=${r.code}`;
    results.scenario7_oversized_contents = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 7:", s);
  }

  // Scenario 8: a Gemini 403 (invalid/revoked key) never leaks the actual key
  // value into the thrown error message.
  {
    const uid = "phase38-user-invalidkey";
    const CONNECTED_TEST_KEY_8 = "AIzaSuperSecretPhase38Scenario8DoNotLeak";
    await seedConnection(db, uid, "gemini", CONNECTED_TEST_KEY_8);
    const axiosError = new Error("Request failed with status code 403");
    axiosError.isAxiosError = true;
    axiosError.response = {
      status: 403,
      data: { error: { message: "API key not valid" } },
    };
    axiosError.config = { url: "https://generativelanguage.googleapis.com/...", params: { key: CONNECTED_TEST_KEY_8 } };
    mockResponses.push({ reject: axiosError });
    const r = await callAndCapture({ contents: SAMPLE_CONTENTS }, { uid, token: {} });
    let s;
    if (r.ok) {
      s = "FAILED — expected a rejection for an invalid key";
    } else if (r.code !== "failed-precondition") {
      s = `FAILED — expected failed-precondition, got code=${r.code}`;
    } else if (r.message.includes(CONNECTED_TEST_KEY_8)) {
      s = "FAILED — THE API KEY LEAKED INTO THE ERROR MESSAGE";
    } else {
      s = `PASSED — rejected without leaking the key. message="${r.message}"`;
    }
    results.scenario8_no_key_leak_on_error = s;
    if (!s.startsWith("PASSED")) allPassed = false;
    console.log("Scenario 8:", s);
  }

  console.log("=== PHASE AI-2 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase38 AI chat proxy test:", e);
  process.exit(1);
});

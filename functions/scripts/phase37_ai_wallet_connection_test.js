// Phase AI-1: proves connectAiProvider/disconnectAiProvider against a real
// emulator (not mocked Firestore) — the wallet debit, the ledger entry, the
// encrypted-at-rest storage, the free-rotate-while-connected path, the
// re-charge-after-full-disconnect path, and the encryption module's own
// round-trip correctness. Mirrors phase9_wallet_topup_test.js's structure
// (seed fixtures, wrap with firebase-functions-test, PASS/FAIL per scenario).
// Run with: node scripts/phase37_ai_wallet_connection_test.js
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = "agrimore-66a4e";
// Same key set in this worktree's functions/.secret.local — the emulator
// does not auto-inject defineSecret() values into process.env the way a
// deployed Cloud Function does, so this test (like phase9's manual
// RAZORPAY_KEY_ID/SECRET) sets it directly before requiring the compiled
// module. Fixed here (not read from .secret.local) so this suite is
// reproducible without depending on that file's contents.
process.env.AI_KEY_ENCRYPTION_SECRET = Buffer.alloc(32, 7).toString("base64");

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "agrimore-66a4e" });

const test = require("firebase-functions-test")({ projectId: "agrimore-66a4e" });
const {
  connectAiProvider,
  disconnectAiProvider,
  encryptApiKey,
  decryptApiKey,
} = require("../lib/customer/aiConnection");

const wrappedConnect = test.wrap(connectAiProvider);
const wrappedDisconnect = test.wrap(disconnectAiProvider);

async function callAndCapture(wrapped, payload, auth) {
  try {
    const result = await wrapped({ data: payload, auth });
    return { ok: true, result };
  } catch (e) {
    return { ok: false, code: e.code, message: e.message };
  }
}

async function seedWallet(db, uid, balance) {
  await db.collection("wallets").doc(uid).set({
    userId: uid,
    balance,
    coins: 0,
    lifetimeEarnings: 0,
    lifetimeSpent: 0,
    lifetimeCoinsEarned: 0,
    lifetimeCoinsUsed: 0,
    referralCode: `AI${uid.slice(-6).toUpperCase()}`,
    referredBy: null,
    referralCount: 0,
    isActive: true,
    signupBonusCredited: true,
  });
}

async function getWalletBalance(db, uid) {
  const snap = await db.collection("wallets").doc(uid).get();
  return snap.data()?.balance ?? null;
}

async function countAiActivationTx(db, uid) {
  const snap = await db
    .collection("wallet_transactions")
    .where("userId", "==", uid)
    .where("source", "==", "aiActivation")
    .get();
  return snap.size;
}

async function main() {
  const db = admin.firestore();
  let allPassed = true;
  const results = {};

  console.log("=== PHASE AI-1 — connectAiProvider / disconnectAiProvider ===");

  // Scenario 1: unauthenticated call is rejected.
  {
    const r = await callAndCapture(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaFakeTestKeyScenario1" },
      undefined
    );
    let s;
    if (r.ok) {
      s = "FAILED — an unauthenticated call to connectAiProvider succeeded";
      allPassed = false;
    } else if (r.code !== "unauthenticated") {
      s = `FAILED — expected code unauthenticated, got ${r.code}`;
      allPassed = false;
    } else {
      s = `PASSED — rejected as expected. code=${r.code}`;
    }
    results.scenario1_unauthenticated = s;
    console.log("Scenario 1:", s);
  }

  // Scenario 2: invalid provider is rejected.
  {
    const uid = "phase37-user-badprovider";
    await seedWallet(db, uid, 1000);
    const r = await callAndCapture(
      wrappedConnect,
      { provider: "claude", apiKey: "some-fake-key-value" },
      { uid, token: {} }
    );
    let s;
    if (r.ok) {
      s = "FAILED — an unsupported provider name was accepted";
      allPassed = false;
    } else if (r.code !== "invalid-argument") {
      s = `FAILED — expected code invalid-argument, got ${r.code}`;
      allPassed = false;
    } else {
      const balanceAfter = await getWalletBalance(db, uid);
      if (balanceAfter !== 1000) {
        s = `FAILED — wallet balance changed on a rejected call: ${balanceAfter}`;
        allPassed = false;
      } else {
        s = `PASSED — rejected as expected, wallet untouched. code=${r.code} message="${r.message}"`;
      }
    }
    results.scenario2_invalid_provider = s;
    console.log("Scenario 2:", s);
  }

  // Scenario 3: empty and oversized apiKey are both rejected.
  {
    const uid = "phase37-user-badkey";
    await seedWallet(db, uid, 1000);
    const empty = await callAndCapture(
      wrappedConnect,
      { provider: "gemini", apiKey: "" },
      { uid, token: {} }
    );
    const oversized = await callAndCapture(
      wrappedConnect,
      { provider: "gemini", apiKey: "x".repeat(500) },
      { uid, token: {} }
    );
    let s;
    if (empty.ok || empty.code !== "invalid-argument") {
      s = `FAILED — empty apiKey was not rejected with invalid-argument (got ok=${empty.ok} code=${empty.code})`;
      allPassed = false;
    } else if (oversized.ok || oversized.code !== "invalid-argument") {
      s = `FAILED — oversized apiKey was not rejected with invalid-argument (got ok=${oversized.ok} code=${oversized.code})`;
      allPassed = false;
    } else {
      const balanceAfter = await getWalletBalance(db, uid);
      if (balanceAfter !== 1000) {
        s = `FAILED — wallet balance changed on a rejected call: ${balanceAfter}`;
        allPassed = false;
      } else {
        s = "PASSED — both empty and oversized apiKey rejected, wallet untouched";
      }
    }
    results.scenario3_bad_key_shape = s;
    console.log("Scenario 3:", s);
  }

  // Scenario 4: insufficient balance is rejected, with zero side effects.
  {
    const uid = "phase37-user-poor";
    await seedWallet(db, uid, 10); // below the 50 activation fee
    const r = await callAndCapture(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaFakeTestKeyScenario4" },
      { uid, token: {} }
    );
    let s;
    if (r.ok) {
      s = "FAILED — connected despite insufficient balance — THIS WOULD BE A REAL FRAUD HOLE";
      allPassed = false;
    } else if (r.code !== "failed-precondition" || r.message !== "Insufficient balance") {
      s = `FAILED — expected failed-precondition "Insufficient balance", got code=${r.code} message="${r.message}"`;
      allPassed = false;
    } else {
      const balanceAfter = await getWalletBalance(db, uid);
      const connectionSnap = await db.collection("ai_connections").doc(uid).get();
      const txCount = await countAiActivationTx(db, uid);
      if (balanceAfter !== 10) {
        s = `FAILED — wallet balance changed despite rejection: ${balanceAfter}`;
        allPassed = false;
      } else if (connectionSnap.exists) {
        s = "FAILED — ai_connections doc was created despite a rejected connect";
        allPassed = false;
      } else if (txCount !== 0) {
        s = `FAILED — a wallet_transactions row was created despite a rejected connect: ${txCount}`;
        allPassed = false;
      } else {
        s = "PASSED — rejected as expected, no wallet debit, no connection doc, no ledger entry";
      }
    }
    results.scenario4_insufficient_balance = s;
    console.log("Scenario 4:", s);
  }

  // Scenario 5: first-time connect with sufficient balance succeeds and
  // debits exactly once.
  const uid5 = "phase37-user-firstconnect";
  {
    await seedWallet(db, uid5, 100);
    const r = await callAndCapture(
      wrappedConnect,
      { provider: "gemini", apiKey: "AIzaRealShapedTestKeyScenario5" },
      { uid: uid5, token: {} }
    );
    let s;
    try {
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.activated !== true || r.result.rotated !== false) {
        throw new Error(`expected activated=true rotated=false, got ${JSON.stringify(r.result)}`);
      }
      const balanceAfter = await getWalletBalance(db, uid5);
      if (balanceAfter !== 50) throw new Error(`expected wallet balance 50 after a ₹50 debit from 100, got ${balanceAfter}`);
      const txCount = await countAiActivationTx(db, uid5);
      if (txCount !== 1) throw new Error(`expected exactly 1 aiActivation wallet_transactions row, got ${txCount}`);
      const connectionSnap = await db.collection("ai_connections").doc(uid5).get();
      if (!connectionSnap.exists) throw new Error("ai_connections doc was not created");
      const connection = connectionSnap.data();
      if (connection.provider !== "gemini") throw new Error(`expected provider gemini, got ${connection.provider}`);
      if (connection.encryptedKey === "AIzaRealShapedTestKeyScenario5") {
        throw new Error("the stored key is the PLAINTEXT key — encryption did not happen");
      }
      const statusSnap = await db.collection("ai_connection_status").doc(uid5).get();
      if (!statusSnap.exists) throw new Error("ai_connection_status doc was not created");
      const status = statusSnap.data();
      if (status.connected !== true || status.provider !== "gemini") {
        throw new Error(`unexpected status doc: ${JSON.stringify(status)}`);
      }
      if ("encryptedKey" in status || "iv" in status || "authTag" in status) {
        throw new Error("ai_connection_status leaked key material — THIS WOULD BE A REAL SECRET EXPOSURE");
      }
      s = `PASSED — activated, balance=${balanceAfter}, 1 ledger row, key encrypted, status has no key material`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario5_first_connect = s;
    console.log("Scenario 5:", s);
  }

  // Scenario 6: the encryption module's own round-trip correctness,
  // independent of the callable flow.
  {
    let s;
    try {
      const plaintext = "AIzaSyD-this-is-not-a-real-key-0123456789";
      const encrypted = encryptApiKey(plaintext);
      if (encrypted.ciphertext === plaintext) throw new Error("ciphertext equals plaintext");
      const decrypted = decryptApiKey(encrypted);
      if (decrypted !== plaintext) throw new Error(`round-trip mismatch: got "${decrypted}"`);
      // A tampered auth tag must fail closed (GCM's whole point), not
      // silently return corrupted plaintext.
      let tamperRejected = false;
      try {
        decryptApiKey({ ...encrypted, authTag: Buffer.alloc(16, 1).toString("base64") });
      } catch (e) {
        tamperRejected = true;
      }
      if (!tamperRejected) throw new Error("decryptApiKey did not reject a tampered authTag");
      s = "PASSED — encrypt/decrypt round-trip correct, tampered ciphertext rejected";
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario6_encryption_roundtrip = s;
    console.log("Scenario 6:", s);
  }

  // Scenario 7: reconnecting while already connected rotates the key for
  // FREE — no second debit.
  {
    let s;
    try {
      const balanceBefore = await getWalletBalance(db, uid5);
      const r = await callAndCapture(
        wrappedConnect,
        { provider: "chatgpt", apiKey: "sk-fakeTestKeyScenario7ROTATED" },
        { uid: uid5, token: {} }
      );
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.activated !== false || r.result.rotated !== true) {
        throw new Error(`expected activated=false rotated=true, got ${JSON.stringify(r.result)}`);
      }
      const balanceAfter = await getWalletBalance(db, uid5);
      if (balanceAfter !== balanceBefore) {
        throw new Error(`expected NO second debit (balance unchanged at ${balanceBefore}), got ${balanceAfter} — DOUBLE-CHARGED`);
      }
      const txCount = await countAiActivationTx(db, uid5);
      if (txCount !== 1) throw new Error(`expected still exactly 1 aiActivation row after a rotate, got ${txCount}`);
      const connectionSnap = await db.collection("ai_connections").doc(uid5).get();
      const connection = connectionSnap.data();
      if (connection.provider !== "chatgpt") throw new Error(`expected provider rotated to chatgpt, got ${connection.provider}`);
      const statusSnap = await db.collection("ai_connection_status").doc(uid5).get();
      if (statusSnap.data().provider !== "chatgpt") throw new Error("status doc's provider did not follow the rotate");
      s = `PASSED — rotated to ${connection.provider} with no additional charge (balance stays ${balanceAfter}, 1 ledger row total)`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario7_free_rotate = s;
    console.log("Scenario 7:", s);
  }

  // Scenario 8: disconnect removes the connection, reflects in status, and
  // issues no refund.
  {
    let s;
    try {
      const balanceBefore = await getWalletBalance(db, uid5);
      const r = await callAndCapture(wrappedDisconnect, {}, { uid: uid5, token: {} });
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.wasConnected !== true) throw new Error(`expected wasConnected=true, got ${JSON.stringify(r.result)}`);
      const connectionSnap = await db.collection("ai_connections").doc(uid5).get();
      if (connectionSnap.exists) throw new Error("ai_connections doc still exists after disconnect");
      const statusSnap = await db.collection("ai_connection_status").doc(uid5).get();
      const status = statusSnap.data();
      if (status.connected !== false || status.provider !== null) {
        throw new Error(`expected connected=false provider=null, got ${JSON.stringify(status)}`);
      }
      const balanceAfter = await getWalletBalance(db, uid5);
      if (balanceAfter !== balanceBefore) throw new Error(`expected no refund (balance unchanged), got ${balanceBefore} -> ${balanceAfter}`);
      s = `PASSED — connection removed, status reflects disconnected, no refund (balance stays ${balanceAfter})`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario8_disconnect = s;
    console.log("Scenario 8:", s);
  }

  // Scenario 9: disconnecting again (already disconnected) is an idempotent
  // no-op, not an error.
  {
    const r = await callAndCapture(wrappedDisconnect, {}, { uid: uid5, token: {} });
    let s;
    if (!r.ok) {
      s = `FAILED — disconnecting an already-disconnected user errored: code=${r.code} message=${r.message}`;
      allPassed = false;
    } else if (r.result.wasConnected !== false) {
      s = `FAILED — expected wasConnected=false, got ${JSON.stringify(r.result)}`;
      allPassed = false;
    } else {
      s = "PASSED — idempotent no-op as expected";
    }
    results.scenario9_disconnect_idempotent = s;
    console.log("Scenario 9:", s);
  }

  // Scenario 10: reconnecting AFTER a full disconnect is a brand-new
  // activation and IS charged again.
  {
    let s;
    try {
      const balanceBefore = await getWalletBalance(db, uid5); // 50, from scenario 5
      const r = await callAndCapture(
        wrappedConnect,
        { provider: "gemini", apiKey: "AIzaFakeTestKeyScenario10Reconnect" },
        { uid: uid5, token: {} }
      );
      if (!r.ok) throw new Error(`expected success, got code=${r.code} message=${r.message}`);
      if (r.result.activated !== true || r.result.rotated !== false) {
        throw new Error(`expected a fresh activation (activated=true, rotated=false), got ${JSON.stringify(r.result)}`);
      }
      const balanceAfter = await getWalletBalance(db, uid5);
      if (balanceAfter !== balanceBefore - 50) {
        throw new Error(`expected a NEW ₹50 debit (${balanceBefore} -> ${balanceBefore - 50}), got ${balanceAfter}`);
      }
      const txCount = await countAiActivationTx(db, uid5);
      if (txCount !== 2) throw new Error(`expected exactly 2 aiActivation rows total (one per activation), got ${txCount}`);
      s = `PASSED — reconnect after full disconnect re-charged as a new activation (balance ${balanceBefore} -> ${balanceAfter}, 2 ledger rows total)`;
    } catch (e) {
      s = `FAILED — ${e.message}`;
      allPassed = false;
    }
    results.scenario10_recharge_after_disconnect = s;
    console.log("Scenario 10:", s);
  }

  console.log("=== PHASE AI-1 SUMMARY ===");
  for (const [k, v] of Object.entries(results)) console.log(`${k}:`, v);
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error("FATAL ERROR running phase37 AI wallet connection test:", e);
  process.exit(1);
});

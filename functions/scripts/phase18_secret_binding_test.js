// ============================================================
//  Phase 18, Workstream 7 — secret binding static analysis
// ============================================================
//
// Secret Manager bindings can't be tested against a real emulator (the
// emulator resolves secrets from functions/.secret.local, which this test
// never populates with anything, and the whole point here is to check the
// SOURCE declares the right bindings regardless of whether a local value
// exists). This is a static scan over the TypeScript SOURCE files
// (functions/src, not the compiled functions/lib) — a regex-based scan is
// the right tool for "does this function's options object contain this
// secret reference", and it genuinely catches Trap 1/2/3 because those are
// exactly the kind of "looks right, isn't" mistakes a scan over the
// declared bindings (not the runtime behaviour) can catch.
//
// Run with: node scripts/phase18_secret_binding_test.js (no emulator
// needed — this never touches Firestore/Functions/Secret Manager).

const fs = require("fs");
const path = require("path");

const SRC = path.join(__dirname, "..", "src");

function read(relPath) {
  return fs.readFileSync(path.join(SRC, relPath), "utf8");
}

// Extracts the source text of ONE exported function/const declaration by
// name, from its `export const NAME = ...(` up to the matching close paren
// of the outermost call — good enough for this codebase's consistent
// `export const X = onCall(\n  { ...options... },\n  async (...) => {...}\n);`
// shape (and the v1 `.runWith({...}).https.onRequest(...)` variant).
function extractDeclaration(source, exportName) {
  const marker = `export const ${exportName} =`;
  const start = source.indexOf(marker);
  if (start === -1) return null;
  // Grab a generous window — every options object in this codebase is well
  // under 2000 chars from its `export const` to the end of the options
  // block; this is a heuristic window, not a full parse.
  return source.slice(start, start + 2500);
}

function optionsObjectOf(declText) {
  // First `{ ... }` after the export marker, up to (not including) the
  // first top-level `async` that follows it — i.e. the options object
  // passed as the first argument to onCall/onRequest/onSchedule/runWith.
  const braceStart = declText.indexOf("{");
  if (braceStart === -1) return "";
  let depth = 0;
  for (let i = braceStart; i < declText.length; i++) {
    if (declText[i] === "{") depth++;
    if (declText[i] === "}") {
      depth--;
      if (depth === 0) return declText.slice(braceStart, i + 1);
    }
  }
  return declText.slice(braceStart);
}

function main() {
  let allPassed = true;
  const results = [];

  function check(label, condition, detail) {
    results.push({ label, pass: !!condition, detail });
    if (!condition) allPassed = false;
  }

  console.log("=== PHASE 18, WORKSTREAM 7 — secret binding static analysis ===");

  // ---------------------------------------------------------------
  // payment.ts
  // ---------------------------------------------------------------
  {
    const src = read("customer/payment.ts");
    check(
      "payment.ts declares RAZORPAY_KEY_SECRET via defineSecret",
      /export const RAZORPAY_KEY_SECRET\s*=\s*defineSecret\(\s*["']RAZORPAY_KEY_SECRET["']\s*\)/.test(src),
      "expected `export const RAZORPAY_KEY_SECRET = defineSecret(\"RAZORPAY_KEY_SECRET\")`"
    );
    check(
      "getRazorpayCredentials() body unchanged (still plain process.env reads)",
      /keyId:\s*process\.env\.RAZORPAY_KEY_ID/.test(src) && /keySecret:\s*process\.env\.RAZORPAY_KEY_SECRET/.test(src),
      "getRazorpayCredentials() must not be modified — only the declaration changes"
    );

    for (const fn of ["createRazorpayOrder", "verifyRazorpayPayment"]) {
      const decl = extractDeclaration(src, fn);
      const opts = decl ? optionsObjectOf(decl) : "";
      check(
        `payment.ts: ${fn} declares secrets: [RAZORPAY_KEY_SECRET]`,
        /secrets:\s*\[[^\]]*RAZORPAY_KEY_SECRET[^\]]*\]/.test(opts),
        `options object was: ${opts.replace(/\s+/g, " ").slice(0, 200)}`
      );
      check(
        `payment.ts: ${fn} preserves minInstances/memory`,
        /minInstances:\s*0/.test(opts) && /memory:\s*["']256MiB["']/.test(opts),
        "adding `secrets` must not drop existing options"
      );
    }
  }

  // ---------------------------------------------------------------
  // wallet.ts — Trap 3
  // ---------------------------------------------------------------
  {
    const src = read("customer/wallet.ts");
    const vwt = optionsObjectOf(extractDeclaration(src, "verifyWalletTopup") || "");
    check(
      "wallet.ts: verifyWalletTopup declares secrets: [RAZORPAY_KEY_SECRET]",
      /secrets:\s*\[[^\]]*RAZORPAY_KEY_SECRET[^\]]*\]/.test(vwt)
    );

    for (const fn of ["redeemReferralCode", "creditSignupBonus"]) {
      const opts = optionsObjectOf(extractDeclaration(src, fn) || "");
      check(
        `wallet.ts: ${fn} declares NO secrets (Trap 3)`,
        !/secrets\s*:/.test(opts),
        `${fn} must not receive the Razorpay grant it doesn't need — found options: ${opts}`
      );
    }
  }

  // ---------------------------------------------------------------
  // employee/razorpayOnboardingWebhook.ts — needs BOTH Razorpay secrets
  // ---------------------------------------------------------------
  {
    const src = read("employee/razorpayOnboardingWebhook.ts");
    const opts = optionsObjectOf(extractDeclaration(src, "razorpayOnboardingWebhook") || "");
    check(
      "razorpayOnboardingWebhook declares RAZORPAY_KEY_SECRET (Trap 2 — reached via getRazorpayCredentials)",
      /secrets:\s*\[[^\]]*RAZORPAY_KEY_SECRET\b[^\]]*\]/.test(opts)
    );
    check(
      "razorpayOnboardingWebhook declares RAZORPAY_WEBHOOK_SECRET",
      /secrets:\s*\[[^\]]*RAZORPAY_WEBHOOK_SECRET[^\]]*\]/.test(opts)
    );
    check(
      "razorpayOnboardingWebhook preserves cors:false",
      /cors:\s*false/.test(opts)
    );
  }

  // ---------------------------------------------------------------
  // employee/createAssociateOnboardingPayment.ts — Trap 2
  // ---------------------------------------------------------------
  {
    const src = read("employee/createAssociateOnboardingPayment.ts");
    const opts = optionsObjectOf(extractDeclaration(src, "createAssociateOnboardingPayment") || "");
    check(
      "createAssociateOnboardingPayment declares RAZORPAY_KEY_SECRET (Trap 2)",
      /secrets:\s*\[[^\]]*RAZORPAY_KEY_SECRET[^\]]*\]/.test(opts)
    );
  }

  // ---------------------------------------------------------------
  // employee/reconcileStaleOnboardingPayments.ts — Trap 2, scheduled trigger
  // ---------------------------------------------------------------
  {
    const src = read("employee/reconcileStaleOnboardingPayments.ts");
    const opts = optionsObjectOf(extractDeclaration(src, "reconcileStaleOnboardingPayments") || "");
    check(
      "reconcileStaleOnboardingPayments declares RAZORPAY_KEY_SECRET (Trap 2, onSchedule trigger)",
      /secrets:\s*\[[^\]]*RAZORPAY_KEY_SECRET[^\]]*\]/.test(opts)
    );
    check(
      "reconcileStaleOnboardingPayments preserves its schedule",
      /schedule:\s*["']every 15 minutes["']/.test(opts)
    );
  }

  // ---------------------------------------------------------------
  // v1 functions — sendPhoneOTP, verifyPhoneOTP (Trap 1), sendEmailOTP
  // ---------------------------------------------------------------
  {
    const src = read("common/sendPhoneOTP.ts");
    check(
      "sendPhoneOTP uses v1 runWith({secrets: [...]}) with string names",
      /\.runWith\(\s*\{\s*secrets:\s*\[\s*["']TWOFACTOR_API_KEY["']\s*,\s*["']OTP_ENCRYPTION_KEY["']\s*\]\s*\}\s*\)\s*\n?\s*\.https\.onRequest/.test(
        src
      ),
      "expected functions.runWith({ secrets: [\"TWOFACTOR_API_KEY\", \"OTP_ENCRYPTION_KEY\"] }).https.onRequest(...)"
    );
  }
  {
    const src = read("common/verifyPhoneOTP.ts");
    check(
      "verifyPhoneOTP declares TWOFACTOR_API_KEY (Trap 1 — the whole point of this test)",
      /\.runWith\(\s*\{\s*secrets:\s*\[\s*["']TWOFACTOR_API_KEY["']\s*\]\s*\}\s*\)/.test(src),
      "TRAP 1: verifyPhoneOTP never sends anything, but its module-level PHONE_OTP_ENABLED gate reads " +
        "process.env.TWOFACTOR_API_KEY at cold start — without this binding the gate is permanently false " +
        "and phone login breaks even with the key correctly configured elsewhere."
    );
  }
  {
    const src = read("common/sendEmailOTP.ts");
    check(
      "sendEmailOTP declares RESEND_API_KEY",
      /\.runWith\(\s*\{\s*secrets:\s*\[\s*["']RESEND_API_KEY["']\s*\]\s*\}\s*\)/.test(src)
    );
  }

  // ---------------------------------------------------------------
  // Helper modules must declare NOTHING — they're not functions
  // ---------------------------------------------------------------
  for (const relPath of ["common/smsProvider.ts", "common/emailProvider.ts"]) {
    const src = read(relPath);
    check(
      `${relPath} declares no secret binding (it's a helper module, not an exported function)`,
      !/defineSecret\(/.test(src) && !/\.runWith\(/.test(src) && !/secrets\s*:\s*\[/.test(src)
    );
  }

  // ---------------------------------------------------------------
  // verifyEmailOTP.ts / verifyEmailForProfile.ts need NO Resend binding
  // ---------------------------------------------------------------
  for (const relPath of ["common/verifyEmailOTP.ts", "customer/verifyEmailForProfile.ts"]) {
    const src = read(relPath);
    check(
      `${relPath} needs no Resend binding (verifies a hash only, never sends)`,
      !/RESEND/.test(src) && !/sendEmailViaResend/.test(src)
    );
  }

  // ---------------------------------------------------------------
  // RAZORPAY_KEY_ID / RESEND_FROM_EMAIL must NEVER appear in a secrets array
  // ---------------------------------------------------------------
  {
    const filesToScan = [
      "customer/payment.ts",
      "customer/wallet.ts",
      "employee/razorpayOnboardingWebhook.ts",
      "employee/createAssociateOnboardingPayment.ts",
      "employee/reconcileStaleOnboardingPayments.ts",
      "common/sendPhoneOTP.ts",
      "common/verifyPhoneOTP.ts",
      "common/sendEmailOTP.ts",
    ];
    for (const relPath of filesToScan) {
      const src = read(relPath);
      // Find every `secrets: [...]` array in the file and confirm neither
      // non-secret name appears inside ANY of them.
      const secretsArrays = src.match(/secrets:\s*\[[^\]]*\]/g) || [];
      const joined = secretsArrays.join(" | ");
      check(
        `${relPath}: no secrets array contains RAZORPAY_KEY_ID`,
        !joined.includes("RAZORPAY_KEY_ID"),
        `found in: ${joined}`
      );
      check(
        `${relPath}: no secrets array contains RESEND_FROM_EMAIL`,
        !joined.includes("RESEND_FROM_EMAIL"),
        `found in: ${joined}`
      );
    }
  }

  // ---------------------------------------------------------------
  // aiConnection.ts — Phase AI-1's new secret (extends this suite the same
  // way payment.ts's block above proves RAZORPAY_KEY_SECRET's binding).
  // ---------------------------------------------------------------
  {
    const src = read("customer/aiConnection.ts");
    check(
      "aiConnection.ts declares AI_KEY_ENCRYPTION_SECRET via defineSecret",
      /export const AI_KEY_ENCRYPTION_SECRET\s*=\s*defineSecret\(\s*["']AI_KEY_ENCRYPTION_SECRET["']\s*\)/.test(src),
      'expected `export const AI_KEY_ENCRYPTION_SECRET = defineSecret("AI_KEY_ENCRYPTION_SECRET")`'
    );

    const connectOpts = optionsObjectOf(extractDeclaration(src, "connectAiProvider") || "");
    check(
      "aiConnection.ts: connectAiProvider declares secrets: [AI_KEY_ENCRYPTION_SECRET]",
      /secrets:\s*\[[^\]]*AI_KEY_ENCRYPTION_SECRET[^\]]*\]/.test(connectOpts),
      `options object was: ${connectOpts.replace(/\s+/g, " ").slice(0, 200)}`
    );

    const disconnectOpts = optionsObjectOf(extractDeclaration(src, "disconnectAiProvider") || "");
    check(
      "aiConnection.ts: disconnectAiProvider declares NO secrets (it never decrypts anything)",
      !/secrets\s*:/.test(disconnectOpts),
      `disconnectAiProvider must not receive a grant it doesn't need — found options: ${disconnectOpts}`
    );
  }

  // ---------------------------------------------------------------
  // deliveryRoute.ts — Phase DLV-3B's Google Routes key (D-DLV-ROUTES):
  // bound to the one function that calls Google, read only via .value().
  // ---------------------------------------------------------------
  {
    const src = read("delivery/deliveryRoute.ts");
    check(
      "deliveryRoute.ts declares GOOGLE_ROUTES_API_KEY via defineSecret",
      /export const GOOGLE_ROUTES_API_KEY\s*=\s*defineSecret\(\s*["']GOOGLE_ROUTES_API_KEY["']\s*\)/.test(src),
      'expected `export const GOOGLE_ROUTES_API_KEY = defineSecret("GOOGLE_ROUTES_API_KEY")`'
    );
    const opts = src.slice(src.indexOf("export const refreshDeliveryRoute"), src.indexOf("async (event)"));
    check(
      "deliveryRoute.ts: refreshDeliveryRoute declares secrets: [GOOGLE_ROUTES_API_KEY]",
      /secrets:\s*\[[^\]]*GOOGLE_ROUTES_API_KEY[^\]]*\]/.test(opts),
      `options were: ${opts.replace(/\s+/g, " ").slice(0, 200)}`
    );
    check(
      "deliveryRoute.ts never reads the key from process.env (only the bound secret)",
      !/process\.env\.GOOGLE_ROUTES_API_KEY/.test(src),
      "found process.env.GOOGLE_ROUTES_API_KEY"
    );
  }

  console.log("");
  for (const r of results) {
    console.log(`${r.pass ? "PASSED" : "FAILED"} — ${r.label}${r.pass ? "" : ` :: ${r.detail || ""}`}`);
  }
  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main();

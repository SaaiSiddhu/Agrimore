// ============================================================
//  Phase 18, Workstream 5 — pre-deploy secret verification
// ============================================================
//
// Nothing today prevents a `firebase deploy --only functions` that is
// missing a required Secret Manager secret — the failure mode is silent
// and production-breaking (see the Phase 18 completion report's "why this
// phase exists" section). This script is meant to gate a deploy: run it
// first, and only deploy if it exits 0.
//
// VALUE-SAFE BY CONSTRUCTION: this script calls `firebase
// functions:secrets:get <NAME>`, which the Firebase CLI documents as
// returning secret METADATA (name, creation time, version list, IAM
// bindings) — never the secret payload. This is the GCP Secret Manager API
// distinction between `secrets.get` (metadata) and `secrets.versions.access`
// (payload) — this script never calls the latter, and never will. It
// prints only the secret NAME and a present/missing verdict, nothing else
// captured from the command's output is ever printed.
//
// Run with: node scripts/verify_secrets.js
// Exits 0 if every required secret exists in Secret Manager for project
// agrimore-66a4e, non-zero otherwise (including on a credential/auth
// failure — see the honesty note in checkOneSecret() below).

const { spawnSync } = require("child_process");

const PROJECT_ID = "agrimore-66a4e";

// The five secrets Workstreams 1/2 bind, and exactly which functions need
// each — kept in sync with phase18_secret_binding_test.js's own list;
// changing one without the other is a bug.
const REQUIRED_SECRETS = [
  {
    name: "RAZORPAY_KEY_SECRET",
    neededBy: [
      "createRazorpayOrder",
      "verifyRazorpayPayment",
      "verifyWalletTopup",
      "createAssociateOnboardingPayment",
      "reconcileStaleOnboardingPayments",
      "razorpayOnboardingWebhook",
    ],
  },
  {
    name: "RAZORPAY_WEBHOOK_SECRET",
    neededBy: ["razorpayOnboardingWebhook"],
  },
  {
    name: "TWOFACTOR_API_KEY",
    neededBy: ["sendPhoneOTP", "verifyPhoneOTP"],
  },
  {
    name: "OTP_ENCRYPTION_KEY",
    neededBy: ["sendPhoneOTP"],
  },
  {
    name: "RESEND_API_KEY",
    neededBy: ["sendEmailOTP"],
  },
];

function checkOneSecret(name) {
  const result = spawnSync(
    "firebase",
    ["functions:secrets:get", name, "--project", PROJECT_ID],
    { encoding: "utf8", timeout: 30_000 }
  );

  if (result.error) {
    // spawnSync itself failed (e.g. `firebase` binary not on PATH) — not a
    // verdict about the secret at all.
    return { name, status: "ERROR", detail: `could not run firebase CLI: ${result.error.message}` };
  }

  if (result.status === 0) {
    return { name, status: "PRESENT" };
  }

  // Non-zero exit: could genuinely mean "secret does not exist" OR a
  // credential/auth failure (no ADC, not logged in, wrong project access).
  // Conflating these would be dishonest — a credential failure must never
  // be reported as "secret missing", since that's a different problem with
  // a different fix. We only ever inspect stderr for known
  // credential-failure signatures; we never print stderr itself, since a
  // future CLI version could in principle echo something value-adjacent
  // into an error message and this script must stay value-safe even then.
  const stderr = (result.stderr || "").toLowerCase();
  const looksLikeAuthFailure =
    stderr.includes("could not load the default credentials") ||
    stderr.includes("application default credentials") ||
    stderr.includes("not logged in") ||
    stderr.includes("permission") ||
    stderr.includes("unauthenticated") ||
    stderr.includes("failed to authenticate");

  if (looksLikeAuthFailure) {
    return {
      name,
      status: "AUTH_ERROR",
      detail: "credentials unavailable or insufficient — this is NOT a verdict on whether the secret exists",
    };
  }

  return { name, status: "MISSING" };
}

function main() {
  console.log(`=== Phase 18 — verifying ${REQUIRED_SECRETS.length} required secrets for project ${PROJECT_ID} ===`);
  console.log("(printing NAMES and verdicts only — never a value)");
  console.log("");

  let allPresent = true;
  let anyAuthError = false;

  for (const secret of REQUIRED_SECRETS) {
    const result = checkOneSecret(secret.name);
    console.log(`${secret.name}: ${result.status}${result.detail ? ` (${result.detail})` : ""}`);
    console.log(`  needed by: ${secret.neededBy.join(", ")}`);

    if (result.status === "AUTH_ERROR") anyAuthError = true;
    if (result.status !== "PRESENT") allPresent = false;
  }

  console.log("");
  if (anyAuthError) {
    console.log(
      "❌ Could not verify one or more secrets due to a credentials/authentication problem — " +
        "this is NOT the same as a missing secret. Fix credentials (e.g. `gcloud auth application-default login` " +
        "or ensure this environment has access to project " + PROJECT_ID + ") and re-run before trusting this report."
    );
    process.exit(1);
  }

  if (!allPresent) {
    console.log("❌ One or more required secrets are missing from Secret Manager. Do NOT deploy.");
    process.exit(1);
  }

  console.log("✅ All required secrets present. Safe to proceed with the functions deploy.");
  process.exit(0);
}

main();

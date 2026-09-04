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
// ------------------------------------------------------------------------
// Phase 19, Workstream 4 — also gate functions/.env
// ------------------------------------------------------------------------
// Phase 18, Workstream 3 put the two ordinary, non-secret config values
// (RAZORPAY_KEY_ID, RESEND_FROM_EMAIL) in plain functions/.env rather than
// Secret Manager, but nothing ever checked that file exists before a
// deploy — a missing functions/.env silently ships RAZORPAY_KEY_ID="" and
// createRazorpayOrder's own `!RAZORPAY_KEY_ID` guard kills checkout. This
// script now gates BOTH halves of Phase 18's config model: secrets in
// Secret Manager (above), and non-secret config in functions/.env (below).
//
// VALUE-SAFE BY CONSTRUCTION, same discipline as the secrets check above:
// this script only ever parses functions/.env for variable NAMES (the text
// left of `=` on each line), via the same `^[A-Za-z_][A-Za-z0-9_]*=`
// technique used in the Phase 19 guard test — it never reads, logs, or
// prints anything to the right of an `=` sign.
//
// Run with: node scripts/verify_secrets.js
// Exits 0 if every required secret exists in Secret Manager for project
// agrimore-66a4e AND functions/.env exists with both required config keys,
// non-zero otherwise (including on a credential/auth failure — see the
// honesty note in checkOneSecret() below).

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const PROJECT_ID = "agrimore-66a4e";
const ENV_FILE = path.join(__dirname, "..", ".env");
const ENV_EXAMPLE_FILE = "functions/.env.example";

// The two ordinary, non-secret config keys Phase 18/19 decided belong in
// functions/.env — kept in sync with their read sites (payment.ts,
// emailProvider.ts) and with functions/.env.example; changing one without
// the others is a bug.
const REQUIRED_ENV_KEYS = [
  { name: "RAZORPAY_KEY_ID", neededBy: ["createRazorpayOrder (payment.ts)"] },
  { name: "RESEND_FROM_EMAIL", neededBy: ["sendEmailOTP (emailProvider.ts)"] },
];

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

// Extracts variable NAMES ONLY from an env-style file — everything left of
// the first `=` on each non-comment, non-blank line. Never returns or
// touches anything to the right of `=`; a reader auditing this script for
// value-safety only needs to check that this function's return value is
// used, never `line` or `line.split("=")[1]` etc.
function parseEnvKeyNames(fileContents) {
  return fileContents
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=/);
      return match ? match[1] : null;
    })
    .filter(Boolean);
}

function checkEnvFile() {
  if (!fs.existsSync(ENV_FILE)) {
    return {
      status: "MISSING_FILE",
      detail: `functions/.env does not exist — copy ${ENV_EXAMPLE_FILE} to functions/.env and fill in real (non-secret) values`,
    };
  }

  const keyNames = parseEnvKeyNames(fs.readFileSync(ENV_FILE, "utf8"));

  const missingRequired = REQUIRED_ENV_KEYS.filter((k) => !keyNames.includes(k.name));

  const secretManagerNames = REQUIRED_SECRETS.map((s) => s.name);
  const regressedSecrets = keyNames.filter((name) => secretManagerNames.includes(name));

  return { status: "CHECKED", missingRequired, regressedSecrets };
}

function main() {
  console.log(`=== Phase 18/19 — verifying required secrets + config for project ${PROJECT_ID} ===`);
  console.log("(printing NAMES and verdicts only — never a value)");
  console.log("");

  console.log(`--- Secret Manager (${REQUIRED_SECRETS.length} required secrets) ---`);
  let allSecretsPresent = true;
  let anyAuthError = false;

  for (const secret of REQUIRED_SECRETS) {
    const result = checkOneSecret(secret.name);
    console.log(`${secret.name}: ${result.status}${result.detail ? ` (${result.detail})` : ""}`);
    console.log(`  needed by: ${secret.neededBy.join(", ")}`);

    if (result.status === "AUTH_ERROR") anyAuthError = true;
    if (result.status !== "PRESENT") allSecretsPresent = false;
  }

  console.log("");
  console.log("--- functions/.env (non-secret config) ---");
  const envResult = checkEnvFile();
  let envOk = false;

  if (envResult.status === "MISSING_FILE") {
    console.log(`functions/.env: MISSING FILE (${envResult.detail})`);
  } else {
    if (envResult.missingRequired.length === 0) {
      console.log("functions/.env: all required config keys present");
    } else {
      for (const k of envResult.missingRequired) {
        console.log(`functions/.env: MISSING KEY ${k.name} (needed by: ${k.neededBy.join(", ")})`);
      }
    }
    if (envResult.regressedSecrets.length > 0) {
      console.log(
        `functions/.env: TRAP F REGRESSION — declares Secret Manager secret name(s) as plain config: ${envResult.regressedSecrets.join(", ")}. ` +
          "Remove them from functions/.env immediately; they belong ONLY in Secret Manager."
      );
    }
    envOk = envResult.missingRequired.length === 0 && envResult.regressedSecrets.length === 0;
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

  if (!allSecretsPresent && !envOk) {
    console.log("❌ FAILED — both halves: one or more Secret Manager secrets are missing, AND functions/.env is incomplete/regressed. Do NOT deploy.");
    process.exit(1);
  }
  if (!allSecretsPresent) {
    console.log("❌ FAILED — Secret Manager half: one or more required secrets are missing from Secret Manager. Do NOT deploy.");
    process.exit(1);
  }
  if (!envOk) {
    console.log("❌ FAILED — functions/.env half: the config file is missing or incomplete/regressed. Do NOT deploy.");
    process.exit(1);
  }

  console.log("✅ All required secrets present AND functions/.env is complete. Safe to proceed with the functions deploy.");
  process.exit(0);
}

main();

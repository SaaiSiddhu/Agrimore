// ============================================================
//  Phase 19 — client secret exposure regression guard
// ============================================================
//
// Nothing in this repository would have caught the `.env` asset
// declaration (finding 19-A: RAZORPAY_KEY_SECRET and SMTP_PASS shipped
// inside the published 1.0.7 Android app because four pubspec.yaml files
// declared `- .env` as a Flutter asset, which copies the whole file
// verbatim into the APK/AAB) — and nothing would catch it being re-added.
// This is a static scan over SOURCE files (pubspec.yaml, .dart files, env
// files) — plain Node, no emulator, no network, no framework, runnable in
// under a second.
//
// VALUE-SAFE BY CONSTRUCTION: check 6 below parses env files for variable
// NAMES ONLY (everything left of the first `=` on a line), via the same
// `^[A-Za-z_][A-Za-z0-9_]*=` technique verify_secrets.js uses. It never
// reads, logs, compares, or otherwise touches anything to the right of an
// `=` sign — a reader auditing this file for value-safety only needs to
// check that `parseEnvKeyNames()`'s return value (an array of names) is
// what every downstream comparison uses.
//
// Run with: node scripts/phase19_client_secret_guard_test.js (no emulator
// needed — this never touches Firestore/Functions/Secret Manager).

const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.join(__dirname, "..", "..");
const APPS = ["marketplace", "admin", "seller", "delivery", "employee"];

function read(relPath) {
  return fs.readFileSync(path.join(REPO_ROOT, relPath), "utf8");
}

function exists(relPath) {
  return fs.existsSync(path.join(REPO_ROOT, relPath));
}

// Recursively collects every file under `relDir` whose name ends with
// `.dart`, skipping build/generated directories that would otherwise
// balloon the scan for no benefit.
function findDartFiles(relDir) {
  const SKIP_DIRS = new Set([".dart_tool", "build", "ios", "android", ".git"]);
  const absDir = path.join(REPO_ROOT, relDir);
  if (!fs.existsSync(absDir)) return [];

  const results = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        if (SKIP_DIRS.has(entry.name)) continue;
        walk(path.join(dir, entry.name));
      } else if (entry.isFile() && entry.name.endsWith(".dart")) {
        results.push(path.join(dir, entry.name));
      }
    }
  }
  walk(absDir);
  return results;
}

// Extracts variable NAMES ONLY from an env-style file's text — see the
// value-safety note at the top of this file. Mirrors verify_secrets.js's
// parseEnvKeyNames() exactly; kept duplicated (not imported) so this guard
// test has zero dependency on the file it's partly guarding.
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

const SECRET_MANAGER_NAMES = [
  "RAZORPAY_KEY_SECRET",
  "RAZORPAY_WEBHOOK_SECRET",
  "TWOFACTOR_API_KEY",
  "OTP_ENCRYPTION_KEY",
  "RESEND_API_KEY",
];

// ------------------------------------------------------------------------
// Phase 20, Workstream 2 — widen check 6 beyond Secret Manager names
// ------------------------------------------------------------------------
// SECRET_MANAGER_NAMES (above) is the set of names Secret Manager itself
// binds — kept as its own constant because other tooling (verify_secrets.js)
// reasons about exactly that set and no more. FORBIDDEN_ENV_NAMES is a
// STRICT SUPERSET for check 6 only: every SECRET_MANAGER_NAMES entry, plus
// the SMTP_* config that carries the live Gmail app password, plus
// GEMINI_API_KEY. Do not conflate the two — a caller that needs "what does
// Secret Manager bind" must keep using SECRET_MANAGER_NAMES.
const FORBIDDEN_ENV_NAMES = [
  ...SECRET_MANAGER_NAMES,
  // SMTP_PASS is a live Gmail app password — one of the two credentials
  // that actually shipped inside the published 1.0.7 APK/AAB (finding #5 /
  // 19-A). The other five SMTP_* names are its supporting config and carry
  // no standalone secrecy value, but a client `.env` has no legitimate
  // reason to hold any of them (nothing sends email from the client) — so
  // all six are forbidden together rather than picking SMTP_PASS alone.
  "SMTP_HOST",
  "SMTP_PORT",
  "SMTP_USER",
  "SMTP_PASS",
  "SMTP_FROM_NAME",
  "SMTP_FROM_EMAIL",
  // GEMINI_API_KEY is a live, billable Generative Language API key — see
  // finding 19-B (check 9 below) and packages/agrimore_core/lib/config/
  // gemini_config.dart. It is intentionally NOT read from any `.env` file
  // today (it is hardcoded in gemini_config.dart instead), so its presence
  // in a client `.env` would be a second, redundant copy of a credential
  // that is already tracked as its own finding — forbid it here too.
  "GEMINI_API_KEY",
];

function main() {
  let allPassed = true;
  const results = [];

  function check(label, condition, detail) {
    results.push({ label, pass: !!condition, detail });
    if (!condition) allPassed = false;
  }

  console.log("=== PHASE 19 — client secret exposure regression guard ===");

  // ---------------------------------------------------------------
  // Check 1 — no app's pubspec.yaml declares `.env` as a Flutter asset
  // ---------------------------------------------------------------
  for (const app of APPS) {
    const relPath = `apps/${app}/pubspec.yaml`;
    if (!exists(relPath)) {
      check(`${relPath} exists`, false, "expected pubspec.yaml to exist for every app in APPS");
      continue;
    }
    const src = read(relPath);
    const hasEnvAsset = /^\s*-\s*\.env\s*$/m.test(src);
    check(
      `${relPath} does not declare \`.env\` as an asset`,
      !hasEnvAsset,
      "a `.env` asset ships server credentials inside the APK — this is finding 19-A, do not re-add it."
    );
  }

  // ---------------------------------------------------------------
  // Check 2 — env_config.dart does not exist
  // ---------------------------------------------------------------
  check(
    "packages/agrimore_core/lib/config/env_config.dart does not exist",
    !exists("packages/agrimore_core/lib/config/env_config.dart"),
    "EnvConfig was deleted in Phase 19 because it was dead code with a client-side accessor for RAZORPAY_KEY_SECRET"
  );

  // ---------------------------------------------------------------
  // Check 3 — the barrel no longer exports config/env_config.dart
  // ---------------------------------------------------------------
  {
    const barrelPath = "packages/agrimore_core/lib/agrimore_core.dart";
    const barrelSrc = exists(barrelPath) ? read(barrelPath) : "";
    check(
      `${barrelPath} does not export config/env_config.dart`,
      !/export\s+['"]config\/env_config\.dart['"]/.test(barrelSrc),
      "the barrel must not re-export a deleted file"
    );
  }

  // ---------------------------------------------------------------
  // Check 4 — no .dart file under apps/ or packages/ references
  // dotenv or EnvConfig
  // ---------------------------------------------------------------
  {
    const dartFiles = [...findDartFiles("apps"), ...findDartFiles("packages")];
    const offenders = [];
    for (const absFile of dartFiles) {
      const src = fs.readFileSync(absFile, "utf8");
      if (/\bdotenv\b/.test(src) || /\bEnvConfig\b/.test(src)) {
        offenders.push(path.relative(REPO_ROOT, absFile));
      }
    }
    check(
      "no .dart file under apps/ or packages/ references dotenv or EnvConfig",
      offenders.length === 0,
      `found references in: ${offenders.join(", ")}`
    );
  }

  // ---------------------------------------------------------------
  // Check 5 — no .dart file contains a live server-secret literal
  // ---------------------------------------------------------------
  {
    const LITERALS = ["RAZORPAY_KEY_SECRET", "SMTP_PASS", "RESEND_API_KEY"];
    const dartFiles = [...findDartFiles("apps"), ...findDartFiles("packages")];
    const offenders = [];
    for (const absFile of dartFiles) {
      const src = fs.readFileSync(absFile, "utf8");
      for (const literal of LITERALS) {
        if (src.includes(literal)) {
          offenders.push(`${path.relative(REPO_ROOT, absFile)} :: ${literal}`);
        }
      }
    }
    check(
      "no .dart file under apps/ or packages/ contains RAZORPAY_KEY_SECRET, SMTP_PASS, or RESEND_API_KEY",
      offenders.length === 0,
      `found: ${offenders.join(", ")}`
    );
  }

  // ---------------------------------------------------------------
  // Check 6 — every EXISTING apps/*/.env and Agrimore-main/.env declares
  // NONE of FORBIDDEN_ENV_NAMES (names only — see value-safety note).
  // Widened in Phase 20 from SECRET_MANAGER_NAMES alone — stripping only
  // RAZORPAY_KEY_SECRET would have left SMTP_PASS (a live Gmail app
  // password that actually shipped) completely unguarded.
  // ---------------------------------------------------------------
  {
    const candidateEnvFiles = [".env", ...APPS.map((a) => `apps/${a}/.env`)];
    for (const relPath of candidateEnvFiles) {
      if (!exists(relPath)) {
        // Correct, expected state for admin/seller/delivery — skip, don't fail.
        continue;
      }
      const keyNames = parseEnvKeyNames(read(relPath));
      const regressed = keyNames.filter((name) => FORBIDDEN_ENV_NAMES.includes(name));
      check(
        `${relPath}: no forbidden secret/config name declared (names scanned only, no value read)`,
        regressed.length === 0,
        `found key name(s): ${regressed.join(", ")}`
      );
    }
  }

  // ---------------------------------------------------------------
  // Check 7 — functions/.env.example exists and never declares
  // RAZORPAY_KEY_SECRET
  // ---------------------------------------------------------------
  {
    const relPath = "functions/.env.example";
    if (!exists(relPath)) {
      check(`${relPath} exists`, false, "Phase 19, Workstream 3 must create this file");
    } else {
      const keyNames = parseEnvKeyNames(read(relPath));
      check(
        `${relPath} does not declare RAZORPAY_KEY_SECRET`,
        !keyNames.includes("RAZORPAY_KEY_SECRET"),
        "Trap F: a Secret-Manager-bound secret must never appear as a key in the non-secret config example"
      );
    }
  }

  // ---------------------------------------------------------------
  // Check 8 — Phase 18's binding test still exists (re-run it separately;
  // this guard does not reimplement its checks)
  // ---------------------------------------------------------------
  check(
    "functions/scripts/phase18_secret_binding_test.js still exists",
    exists("functions/scripts/phase18_secret_binding_test.js"),
    "Phase 18's nine secret bindings must still be verified — run that script separately"
  );

  // ---------------------------------------------------------------
  // Check 9 — Phase 20, Workstream 3: no unallowlisted hardcoded Google
  // API key literal in any .dart file under apps/ or packages/.
  //
  // NEVER print a matched key: on a hit, only the file path and a redacted
  // "AIza…<redacted>" marker are reported — never the literal itself. A
  // guard that leaks the thing it guards is worse than no guard.
  //
  // The allowlist is three NAMED files plus one basename rule — never a
  // directory or wildcard, so a new committed key can't hide behind an
  // existing allowlist entry:
  //   - any `firebase_options.dart` (3 of them) — Firebase client API keys
  //     are documented by Google as not secret by design.
  //   - packages/agrimore_core/lib/config/maps_config.dart — accepted
  //     owner decision; a client-compiled key can't be hidden, mitigation
  //     is provider-side key restriction, not code.
  //   - packages/agrimore_core/lib/config/gemini_config.dart — TRACKED
  //     EXCEPTION, finding 19-B. A live, billable Generative Language API
  //     key, committed to git since c024b3e, read at
  //     ai_chat_service.dart:164 and reachable from ai_chat_screen.dart /
  //     chat_history_screen.dart. Cannot be deleted here without breaking
  //     a shipped feature — the fix is a Cloud Function proxy, planned as
  //     Phase 21. REMOVE THIS ALLOWLIST ENTRY WHEN PHASE 21 LANDS.
  // ---------------------------------------------------------------
  {
    const GOOGLE_API_KEY_PATTERN = /['"](AIza[A-Za-z0-9_\-]{20,})['"]/;

    const ALLOWLISTED_EXACT_PATHS = new Set([
      "packages/agrimore_core/lib/config/maps_config.dart",
      "packages/agrimore_core/lib/config/gemini_config.dart", // finding 19-B — remove when Phase 21 lands
    ]);
    function isAllowlisted(relPath) {
      if (path.basename(relPath) === "firebase_options.dart") return true;
      return ALLOWLISTED_EXACT_PATHS.has(relPath);
    }

    const dartFiles = [...findDartFiles("apps"), ...findDartFiles("packages")];
    const offenders = [];
    for (const absFile of dartFiles) {
      const relPath = path.relative(REPO_ROOT, absFile).split(path.sep).join("/");
      if (isAllowlisted(relPath)) continue;
      const src = fs.readFileSync(absFile, "utf8");
      const match = GOOGLE_API_KEY_PATTERN.exec(src);
      if (match) {
        const value = match[1];
        const redacted = `${value.slice(0, 4)}…<redacted, ${value.length} chars>`;
        offenders.push(`${relPath} :: ${redacted}`);
      }
    }
    check(
      "no unallowlisted .dart file under apps/ or packages/ contains a hardcoded Google API key literal",
      offenders.length === 0,
      `found in: ${offenders.join(", ")} — add a named, commented allowlist entry only if this is a documented exception (see finding 19-B for the pattern)`
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

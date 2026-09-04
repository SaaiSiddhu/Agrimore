// ============================================================
//  Phase 23 (SEC-1) — deploy-bundle credential regression guard
// ============================================================
//
// Nothing in this repository would have caught `create_admin.js` (finding
// A-1: a working admin email + password hardcoded at module scope, with
// `admin.auth().updateUser({ password })` below it, sitting in
// `functions/scripts/` — a directory that `firebase.json`'s functions
// `ignore` list did NOT exclude, so the file was uploaded inside every
// functions deploy bundle). It is the same class as `fix_admin.js`, which
// reached GCP repeatedly and was deleted in `8fd06b2`. Deleting one file
// does not stop the next one, so this guard fixes the *shape* of the
// problem in three independent ways:
//
//   1. that specific file is gone,
//   2/3. `functions/scripts/` is excluded from the upload at all,
//   4. no file anywhere under `functions/` carries a module-scope
//      credential literal of that class, whatever it is named.
//
// Static scan over source files — plain Node, no emulator, no network, no
// framework, no Firebase Admin SDK, runs in well under a second.
//
// VALUE-SAFE BY CONSTRUCTION: check 4 detects the *shape* of a credential
// assignment and reports only `path:line` and the IDENTIFIER name (the text
// left of the `=`). It never reads, logs, stores or compares anything to
// the right of the `=` — a reader auditing this file for value-safety only
// needs to confirm that `scanCredentialLiterals()` pushes `rel`, the line
// number and the captured identifier, and never the remainder of the line.
// This mirrors the same guarantee phase19_client_secret_guard_test.js makes
// for env files.
//
// Run with: node scripts/phase23_deploy_bundle_guard_test.js  (from
// `functions/`; no emulator needed — this never touches Firestore,
// Functions, Auth or Secret Manager).

const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.join(__dirname, "..", "..");

function abs(relPath) {
  return path.join(REPO_ROOT, relPath);
}

function exists(relPath) {
  return fs.existsSync(abs(relPath));
}

// The one file finding A-1 was raised against. Named explicitly (rather than
// only relying on check 4's shape scan) so the guard states the specific
// regression it exists to prevent.
const A1_FILE = "functions/scripts/create_admin.js";

// `functions[0].ignore` entries that must be present as BARE DIRECTORY
// NAMES. `node_modules` is the load-bearing precedent: it is a bare name in
// firebase-tools' own default ignore list and provably excludes that whole
// directory from the upload, so a bare `scripts` entry has identical form
// and identical effect. This guard deliberately does NOT re-implement
// firebase-tools' glob matcher — asserting "same form as the entry that is
// known to work" is a claim this repository can actually prove.
const REQUIRED_IGNORE_DIRS = ["node_modules", "scripts"];

// Directories under `functions/` that are build output or third-party code.
const SCAN_SKIP_DIRS = new Set(["node_modules", "lib", ".git", "coverage"]);

// The shapes of "a credential written as a string literal", plus the
// identifier test applied to all of them. Widened twice:
//
//   SEC-2 (2026-09-04) closed finding NB-1 — the original pair matched only
//   a COLUMN-0 const/let/var whose identifier contained
//   [Pp]assword|[Pp]asswd|[Pp]wd, while being LABELLED as covering module-
//   scope password literals generally. It missed `adminPass`, `ADMIN_PWD`,
//   indented assignments, object-literal properties and `apiToken`.
//
//   SEC-2 amend — the VERIFY probe then showed the widened form STILL
//   missed the two most idiomatic TypeScript shapes: `export const NAME =`
//   (73 occurrences across 41 of 48 files in functions/src, the code that
//   actually ships) and `const NAME: Type =` (50 occurrences), plus class
//   fields and property assignment. A label broader than the behaviour is a
//   false PASS waiting to happen — the worst failure mode for a guard.
//
// The identifier is captured WHOLE and tested separately rather than folded
// into one regex. The one-regex form is easy to get wrong: requiring a
// leading `[A-Za-z_$]` before the alternation silently fails to match a
// constant named exactly `password` — the very shape finding A-1 was made of.
//
// Every pattern below was measured against all .js/.ts under functions/
// before being adopted; each produced zero false positives except the two
// documented ALLOWLIST entries.

// `export const NAME: Type = "lit"` and every simpler form of it.
const DECLARATION = /^\s*(?:export\s+)?(?:declare\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?::\s*[^=]+?)?\s*=\s*["'`]/;

// A property inside an object literal: at line start, or right after `{` or
// `,` so an INLINE `{ name: "lit" }` is caught too. Anchoring only at line
// start (the first SEC-2 attempt) missed every inline literal — found by the
// decoy probe, not by reading the regex.
const OBJECT_LITERAL_PROPERTY = /(?:^|[{,])\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*:\s*["'`]/;

// A class field carrying an access modifier: `private password = "lit"`.
// A modifier is required — a bare `name = "lit"` inside a class body is
// indistinguishable from ordinary reassignment and would add noise.
//
// KNOWN LIMIT, stated rather than papered over: this is anchored to line
// start, so a whole class written on ONE line
// (`class C { private password = "lit"; }`) is not matched. Measured at
// SEC-2: there are zero single-line class declarations under functions/ and
// zero class declarations of any kind in functions/src, so this costs
// nothing today. If classes ever appear in shipping code, re-measure.
const CLASS_FIELD = /^\s*(?:(?:public|private|protected|readonly|static|abstract)\s+)+([A-Za-z_$][A-Za-z0-9_$]*)\s*(?::\s*[^=]+?)?\s*=\s*["'`]/;

// `obj.name = "lit"` / `this.name = "lit"`.
const PROPERTY_ASSIGNMENT = /^\s*([A-Za-z_$][A-Za-z0-9_$.]*)\.([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*["'`]/;

// KNOWN, DELIBERATE HOLE: `process.env.X = "..."` is excluded. It is the
// standard way the emulator suites stub a provider key before requiring a
// module, and all six occurrences under functions/ are exactly that. The
// cost of the exclusion is that a credential hidden in that exact form is
// not caught; the mitigation is that those files live in functions/scripts/,
// which SEC-1 removed from the deploy bundle (checks 2/3 above). Do not
// widen this to functions/src without re-measuring.
const ENV_STUB_TARGET = /^process\.env$/;

const CREDENTIAL_NAME = /pass(word|wd)?|pwd|secret|token|credential|apikey|api_key/i;

// Documented exceptions, keyed by exact path AND identifier so a different
// offender in the same file is still caught (verified: the same identifier
// at another path still fails the check). Follow the
// phase19_client_secret_guard_test.js precedent — add an entry ONLY for a
// documented exception, never to silence a real finding.
const ALLOWLIST = [
  // A local HMAC fixture driving razorpayOnboardingWebhook. A test input,
  // not a live credential; lives in functions/scripts/, which SEC-1 excluded
  // from the bundle; the identifier appears nowhere in functions/src.
  { path: "functions/scripts/phase16a_webhook_test.js", identifier: "TEST_SECRET" },
  // Phase 16B-4's fee-templating placeholder, literally "{{fee}}". Matched
  // only because the widened name list contains "token". It is interpolated
  // into user-facing copy and is not a credential of any kind.
  { path: "functions/src/employee/onboardingConfig.ts", identifier: "FEE_TOKEN" },
];

function isAllowlisted(rel, identifier) {
  return ALLOWLIST.some((a) => a.path === rel && a.identifier === identifier);
}

function scanCredentialLiterals() {
  const offenders = [];
  const root = abs("functions");

  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        if (SCAN_SKIP_DIRS.has(entry.name)) continue;
        walk(path.join(dir, entry.name));
      } else if (entry.isFile() && /\.(js|ts|mjs|cjs)$/.test(entry.name)) {
        const full = path.join(dir, entry.name);
        const rel = path.relative(REPO_ROOT, full);
        const lines = fs.readFileSync(full, "utf8").split("\n");
        lines.forEach((line, i) => {
          let identifier = null;
          const assign = line.match(PROPERTY_ASSIGNMENT);
          if (assign && !ENV_STUB_TARGET.test(assign[1])) {
            identifier = assign[2];
          } else if (!assign) {
            const m =
              line.match(DECLARATION) ||
              line.match(CLASS_FIELD) ||
              line.match(OBJECT_LITERAL_PROPERTY);
            if (m) identifier = m[1];
          }
          if (!identifier) return;
          // VALUE-SAFE: only the path, the line number and the IDENTIFIER
          // ever leave this function. The string literal to the right of the
          // `=` or `:` is never read, logged, stored or compared.
          if (CREDENTIAL_NAME.test(identifier) && !isAllowlisted(rel, identifier)) {
            offenders.push(`${rel}:${i + 1} (identifier \`${identifier}\`)`);
          }
        });
      }
    }
  }

  if (fs.existsSync(root)) walk(root);
  return offenders;
}

function main() {
  let allPassed = true;
  const results = [];

  function check(label, condition, detail) {
    results.push({ label, pass: !!condition, detail });
    if (!condition) allPassed = false;
  }

  console.log("=== PHASE 23 (SEC-1) — deploy-bundle credential regression guard ===");

  // ---------------------------------------------------------------
  // Check 1 — the finding A-1 file is gone
  // ---------------------------------------------------------------
  check(
    `${A1_FILE} does not exist (finding A-1)`,
    !exists(A1_FILE),
    `${A1_FILE} is present again — it hardcodes an admin credential and would ship in the functions deploy bundle. ` +
      "Do not re-add it: bootstrap an admin with a Firestore console edit of users/{uid}.role plus the deployed refreshUserRoleClaims callable."
  );

  // ---------------------------------------------------------------
  // Checks 2 and 3 — functions/scripts/ is never uploaded
  // ---------------------------------------------------------------
  const firebaseJson = JSON.parse(fs.readFileSync(abs("firebase.json"), "utf8"));
  const functionsConfigs = Array.isArray(firebaseJson.functions)
    ? firebaseJson.functions
    : firebaseJson.functions
      ? [firebaseJson.functions]
      : [];

  check(
    "firebase.json declares at least one functions codebase",
    functionsConfigs.length > 0,
    "firebase.json has no `functions` entry — this guard cannot verify the upload set"
  );

  for (const cfg of functionsConfigs) {
    const codebase = cfg.codebase || cfg.source || "(unnamed)";
    const ignore = Array.isArray(cfg.ignore) ? cfg.ignore : [];
    for (const dir of REQUIRED_IGNORE_DIRS) {
      check(
        `functions codebase '${codebase}' ignores '${dir}' as a bare directory name`,
        ignore.includes(dir),
        `ignore = [${ignore.join(", ")}] — '${dir}' is missing, so everything under functions/${dir}/ is uploaded with every ` +
          "functions deploy. Add the bare name, exactly like the node_modules entry."
      );
    }
  }

  // ---------------------------------------------------------------
  // Check 4 — no module-scope credential literal anywhere under functions/
  // ---------------------------------------------------------------
  const offenders = scanCredentialLiterals();
  check(
    "no .js/.ts file under functions/ (excluding node_modules, lib) assigns a string literal to a declaration " +
      "(incl. `export const` and typed `const x: T =`), an object-literal property, a modifier-carrying class field, " +
      "or an `obj.prop` assignment, where the name contains pass/password/passwd/pwd/secret/token/credential/apikey " +
      "(case-insensitive, any indentation) — except `process.env.X = ...` test stubs and the documented ALLOWLIST",
    offenders.length === 0,
    `found at: ${offenders.join(", ")} — a credential must never be a top-level constant in this tree. ` +
      "Read it from Secret Manager or pass it in at run time; if this is a one-off owner script, it does not belong under functions/."
  );

  console.log("");
  for (const r of results) {
    console.log(`${r.pass ? "PASSED" : "FAILED"} — ${r.label}${r.pass ? "" : ` :: ${r.detail || ""}`}`);
  }
  console.log("");
  console.log(allPassed ? "ALL PASSED" : "SOME FAILED");
  process.exit(allPassed ? 0 : 1);
}

main();

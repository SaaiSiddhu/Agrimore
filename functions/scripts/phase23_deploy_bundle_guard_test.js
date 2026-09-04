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
// needs to confirm that `scanCredentialLiterals()` pushes `rel`, `lineNo`
// and `match[2]` (the identifier) and never the remainder of the line.
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

// A module-scope `const|let|var <name> = "<literal>"`. Anchored to column 0
// so an indented (in-function, derived, or generated) assignment is not
// matched — those are legitimate, e.g. createSellerByAdmin.ts /
// createEmployeeByAdmin.ts build a password inside a function and never as
// a top-level constant.
//
// The identifier is captured WHOLE and then tested against
// CREDENTIAL_NAME separately, rather than being pattern-matched in one
// regex. The one-regex form is easy to get wrong: requiring a leading
// `[A-Za-z_$]` before the `password` alternation silently fails to match a
// constant named exactly `password` (the very case finding A-1 is made of),
// which is a false PASS — the worst possible failure mode for a guard.
const MODULE_SCOPE_STRING_ASSIGNMENT = /^(const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*["'`]/;
const CREDENTIAL_NAME = /[Pp]assword|[Pp]asswd|[Pp]wd/;

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
          const m = line.match(MODULE_SCOPE_STRING_ASSIGNMENT);
          // VALUE-SAFE: only the path, the line number and m[2] (the
          // identifier name) ever leave this function. The string literal on
          // the right of the `=` is never read, logged or compared.
          if (m && CREDENTIAL_NAME.test(m[2])) {
            offenders.push(`${rel}:${i + 1} (identifier \`${m[2]}\`)`);
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
    "no module-scope password literal in any .js/.ts file under functions/ (excluding node_modules, lib)",
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

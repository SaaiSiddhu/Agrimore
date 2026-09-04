#!/usr/bin/env node
/**
 * validate-branch-dispositions.mjs — re-derives branch facts from git and checks them against
 * docs/active/BRANCH_DISPOSITIONS.md (phase GOV-3, 2026-09-04).
 *
 * Checks:
 *   1. Every live local branch has a row in the "## Branches" table.
 *   2. Every row's branch still exists locally.
 *   3. Every non-ENVIRONMENT, non-ACTIVE row's recorded SHA still matches that branch's tip (an ACTIVE branch moves by design; its SHA is filled at merge).
 *   4. Every `PRESERVED_REFERENCE` row is an ancestor of neither `develop` nor `main`.
 *   5. Every `MERGED_DEVELOP` row IS an ancestor of `develop`; every `MERGED` row IS an ancestor of `main`.
 *   6. `staging` and `main` are each an ancestor of `develop` (fast-forward model; a commit that
 *      `develop` lacks means the model was bypassed).
 *   7. `staging` is an ancestor of `develop` and `main` is an ancestor of `staging` (promotion order).
 *
 * EXIT CODE IS ALWAYS 0 — warnings for a human, never a build gate. Run from anywhere:
 *   node scripts/governance/validate-branch-dispositions.mjs
 * No dependencies beyond Node ≥ 18 and git.
 */
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const LEDGER = "docs/active/BRANCH_DISPOSITIONS.md";
const ENV_BRANCHES = ["develop", "staging", "main"];

function git(args) {
  return execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();
}
function isAncestor(sha, ref) {
  try {
    execFileSync("git", ["merge-base", "--is-ancestor", sha, ref], { cwd: ROOT, stdio: "pipe" });
    return true;
  } catch (e) {
    return e.status === 1 ? false : "error";
  }
}
function parseRows(src) {
  const lines = src.split("\n");
  const start = lines.findIndex((l) => l.trim() === "## Branches");
  if (start === -1) return [];
  const rows = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    const line = lines[i];
    if (line.startsWith("## ")) break;
    if (!line.trim().startsWith("|") || /^\|\s*-+\s*\|/.test(line)) continue;
    const cells = line.split("|").slice(1, -1).map((c) => c.trim());
    if (cells.length < 3 || cells[0] === "Branch") continue;
    const tick = (c) => { const m = c.match(/`([^`]+)`/); return m ? m[1] : null; };
    const branch = tick(cells[0]);
    if (!branch) continue;
    rows.push({ branch, sha: tick(cells[1]), status: tick(cells[2]), line: i + 1 });
  }
  return rows;
}
function liveBranches() {
  const map = new Map();
  for (const l of git(["branch", "--format=%(refname:short) %(objectname)"]).split("\n")) {
    if (!l.trim()) continue;
    const i = l.indexOf(" ");
    map.set(l.slice(0, i), l.slice(i + 1).trim());
  }
  return map;
}

const warnings = [];
let src = null;
try { src = readFileSync(resolve(ROOT, LEDGER), "utf8"); } catch { /* handled below */ }

if (src === null) {
  warnings.push(`${LEDGER} does not exist — no branch has a disposition; every merge is unauthorised by the ledger's own rule.`);
} else {
  const rows = parseRows(src);
  const live = liveBranches();
  const recorded = new Set(rows.map((r) => r.branch));
  for (const [name] of live) {
    if (!recorded.has(name)) warnings.push(`No disposition row for live branch "${name}" — it must not be merged. Add a row (claim protocol).`);
  }
  for (const r of rows) {
    const tip = live.get(r.branch);
    if (tip === undefined) { warnings.push(`${LEDGER}:${r.line} records "${r.branch}", which no longer exists locally.`); continue; }
    const isEnv = r.status === "ENVIRONMENT" || ENV_BRANCHES.includes(r.branch);
    if (!isEnv && r.status !== "ACTIVE" && r.sha && !tip.startsWith(r.sha) && !r.sha.startsWith(tip)) {
      warnings.push(`${LEDGER}:${r.line} records "${r.branch}" at ${r.sha}, live tip is ${tip.slice(0, 9)} — stale row (update your own row; flag someone else's).`);
    }
    if (r.status === "MERGED_DEVELOP" && isAncestor(tip, "develop") === false) {
      warnings.push(`${LEDGER}:${r.line} marks "${r.branch}" MERGED_DEVELOP but ${tip.slice(0, 9)} is NOT an ancestor of develop.`);
    }
    if (r.status === "MERGED" && isAncestor(tip, "main") === false) {
      warnings.push(`${LEDGER}:${r.line} marks "${r.branch}" MERGED (legacy) but ${tip.slice(0, 9)} is NOT an ancestor of main.`);
    }
    if (r.status === "PRESERVED_REFERENCE") {
      const merged = isAncestor(tip, "main") === true || isAncestor(tip, "develop") === true;
      if (merged) warnings.push(`INCIDENT PATTERN: ${LEDGER}:${r.line} marks "${r.branch}" PRESERVED_REFERENCE but it IS contained in main/develop. Escalate to the owner; do not edit the Status yourself.`);
    }
  }
  for (const env of ["staging", "main"]) {
    const sha = live.get(env);
    if (!sha) { warnings.push(`environment branch "${env}" does not exist locally — the develop → staging → main model needs all three.`); continue; }
    if (isAncestor(sha, "develop") === false) warnings.push(`PROMOTION MODEL: "${env}" (${sha.slice(0, 9)}) has commits develop lacks — promotion is fast-forward only.`);
  }
  const mainSha = live.get("main"), stagingSha = live.get("staging");
  if (mainSha && stagingSha && isAncestor(mainSha, "staging") === false) {
    warnings.push(`PROMOTION ORDER: main (${mainSha.slice(0, 9)}) has commits staging lacks — main moves only by ff from staging.`);
  }
}

if (warnings.length === 0) {
  console.log(`✓ validate:branch-dispositions — ${LEDGER} is consistent with the live repository (exit 0 always).`);
} else {
  console.log(`⚠ validate:branch-dispositions — ${warnings.length} warning(s), exit 0 always; act on them:\n`);
  for (const w of warnings) console.log(`  • ${w}`);
}
process.exit(0);

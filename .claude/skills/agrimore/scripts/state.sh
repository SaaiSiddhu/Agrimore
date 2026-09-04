#!/usr/bin/env bash
# state.sh — read/write ~/.agrimore/run/<programme>/state.json and rewrite STATUS.md. Node does the JSON work.
# Usage:
#   state.sh init <programme> [<base_develop_sha>]        create the programme (fails if it exists)
#   state.sh show <programme>                              print a compact view
#   state.sh get  <programme> <dot.path>                   print a value as JSON
#   state.sh set  <programme> <dot.path> <json-value>      set a value (creates intermediate objects)
#   state.sh phase-add <programme> <json-phase-object>     append a phase (needs id, title, contract)
#   state.sh phase-set <programme> <phaseId> <field> <json-value>
#   state.sh tick <programme> <phaseId> <step> <result>    append a tick-log line, bump counters
#   state.sh stop <programme> <reason>                     set stop (the next run tick ends the loop)
#   state.sh status <programme>                            rewrite STATUS.md from state.json
set -euo pipefail
ROOT="${AGRIMORE_RUN_ROOT:-$HOME/.agrimore/run}"; cmd="${1:-}"; prog="${2:-}"
[ -n "$cmd" ] && [ -n "$prog" ] || { sed -n '2,13p' "$0"; exit 2; }
DIR="$ROOT/$prog"; FILE="$DIR/state.json"
export DIR FILE cmd
node - "$@" <<'JS'
const fs = require("fs"), path = require("path");
const [cmd, prog, ...rest] = process.argv.slice(2);
const DIR = process.env.DIR, FILE = process.env.FILE; const now = () => new Date().toISOString();
const load = () => JSON.parse(fs.readFileSync(FILE, "utf8"));
const save = (s) => fs.writeFileSync(FILE, JSON.stringify(s, null, 2) + "\n");
const getPath = (o, p) => p.split(".").reduce((a, k) => (a == null ? undefined : a[k]), o);
const setPath = (o, p, v) => { const ks = p.split("."); let c = o; for (const k of ks.slice(0, -1)) { if (typeof c[k] !== "object" || c[k] === null) c[k] = {}; c = c[k]; } c[ks.at(-1)] = v; };
const parse = (v) => { try { return JSON.parse(v); } catch { return v; } };
if (cmd === "init") {
  if (fs.existsSync(FILE)) { console.error(`exists: ${FILE}`); process.exit(1); }
  fs.mkdirSync(path.join(DIR, "logs"), { recursive: true });
  save({ programme: prog, created: now(), base_develop: rest[0] || null,
    config: { push_develop: false, max_ticks: 400, max_hours: 72, max_ticks_per_phase: 60, wake_seconds: 300, allow_emulator: true, allow_device_run: false },
    phases: [], promotions: [], deploy_handover: [], ticks: 0, started: null, stop: null, tick_log: [] });
  console.log(`created ${FILE}`); process.exit(0);
}
const s = load();
switch (cmd) {
  case "show": {
    console.log(`${s.programme}  ticks=${s.ticks}  started=${s.started || "-"}  stop=${s.stop ? s.stop.reason : "-"}  base_develop=${s.base_develop || "-"}  push_develop=${s.config.push_develop}`);
    for (const p of s.phases) console.log(`  ${p.id.padEnd(8)} ${String(p.state).padEnd(15)} step=${p.step || "-"} ticks=${p.ticks || 0} branch=${p.branch || "-"} deploy=${p.deploy_consequence || "?"}${p.blocked_reason ? "  BLOCKED: " + p.blocked_reason : ""}`);
    if (s.tick_log.length) { console.log("  last ticks:"); for (const t of s.tick_log.slice(-5)) console.log(`    ${t.t} ${t.phase} ${t.step} → ${t.result}`); }
    break; }
  case "get": console.log(JSON.stringify(getPath(s, rest[0]) ?? null)); break;
  case "set": setPath(s, rest[0], parse(rest[1])); save(s); console.log("ok"); break;
  case "phase-add": { const p = parse(rest[0]); if (!p || !p.id) { console.error("phase needs an id"); process.exit(1); }
    if (s.phases.some(x => x.id === p.id)) { console.error("duplicate phase id"); process.exit(1); }
    s.phases.push({ state: "PLANNED", step: "collision-check", ticks: 0, evidence: {}, blocked_reason: null, depends_on: [], deploy_consequence: "NONE", ...p }); save(s); console.log(`added ${p.id}`); break; }
  case "phase-set": { const p = s.phases.find(x => x.id === rest[0]); if (!p) { console.error("no such phase"); process.exit(1); }
    p[rest[1]] = parse(rest[2]); save(s); console.log("ok"); break; }
  case "tick": { const [id, step, result] = rest; const p = s.phases.find(x => x.id === id);
    s.ticks += 1; s.started ||= now(); if (p) p.ticks = (p.ticks || 0) + 1;
    s.tick_log.push({ t: now(), phase: id, step, result: (result || "").slice(0, 300) }); s.tick_log = s.tick_log.slice(-500); save(s); console.log(`tick ${s.ticks}`); break; }
  case "stop": s.stop = { at: now(), reason: rest.join(" ") }; save(s); console.log("stop set"); break;
  case "status": {
    const elapsedH = s.started ? ((Date.now() - Date.parse(s.started)) / 36e5).toFixed(1) : "0";
    const cur = s.phases.find(p => !["MERGED_DEVELOP", "E2E_DEVELOP", "STOPPED", "BLOCKED"].includes(p.state));
    const lines = [`# ${s.programme} — STATUS`, ``, `updated: ${now()}  ·  ticks: ${s.ticks}/${s.config.max_ticks}  ·  elapsed: ${elapsedH}h/${s.config.max_hours}h  ·  base develop: ${s.base_develop || "-"}`,
      `stop: ${s.stop ? s.stop.reason + " (" + s.stop.at + ")" : "none"}`, ``, `## Current`, cur ? `${cur.id} — ${cur.title}: **${cur.state}**, next step \`${cur.step}\`, ticks ${cur.ticks || 0}` : "no active phase", ``,
      `## Phases`, `| id | title | state | step | ticks | branch | deploy consequence | blocked |`, `|---|---|---|---|---|---|---|---|`,
      ...s.phases.map(p => `| ${p.id} | ${p.title} | ${p.state} | ${p.step || ""} | ${p.ticks || 0} | ${p.branch || ""} | ${p.deploy_consequence || ""} | ${p.blocked_reason || ""} |`), ``,
      `## Deploy handover for the owner (never run by the loop)`, ...(s.deploy_handover.length ? s.deploy_handover.map(x => `- ${x}`) : ["- none yet"]), ``,
      `## Promotions`, ...(s.promotions.length ? s.promotions.map(x => `- ${x.at} ${x.target} ← ${x.source} @ ${x.sha} pushed=${x.pushed}`) : ["- none"]), ``,
      `## Last ticks`, ...s.tick_log.slice(-10).map(t => `- ${t.t} ${t.phase} \`${t.step}\` → ${t.result}`)];
    fs.writeFileSync(path.join(DIR, "STATUS.md"), lines.join("\n") + "\n"); console.log(`wrote ${path.join(DIR, "STATUS.md")}`); break; }
  default: console.error(`unknown command ${cmd}`); process.exit(2);
}
JS

# `run` mode — the self-paced loop (`/loop /agrimore run`)

One tick = **one bounded step** of the current phase, evidence written to disk, state advanced,
next wake scheduled. Never one whole phase per tick. Never an unbounded step.

## 1. Where the truth lives (never in the conversation)

```
~/.agrimore/run/<programme>/state.json    the programme: contracts, phase states, evidence paths, config, budgets, tick log
~/.agrimore/run/<programme>/STATUS.md     human heartbeat, rewritten every tick (the owner reads this)
~/.agrimore/run/<programme>/logs/         gate tables, probe outputs, per-tick notes
the repository                            branches, ledger rows, commits — the only durable record of work
```

Every tick **starts** with `pwd`, `scripts/state.sh show <programme>`, `git -C <worktree> status
--porcelain | wc -l`, `git -C <worktree> log -1`, and `git rev-parse develop`. In the single folder the
porcelain count is never 0 — the standing WIP is expected; compare it against the known dirty set.
If the conversation and the disk disagree, the disk wins. Context compaction is expected; it must
never change what happens next.

## 2. `state.json` shape

```json
{
  "programme": "<name>", "created": "<iso>", "base_develop": "<sha>",
  "config": { "push_develop": false, "max_ticks": 400, "max_hours": 72, "max_ticks_per_phase": 60,
              "wake_seconds": 60, "allow_emulator": true, "allow_device_run": false },
  "phases": [ { "id": "X-1", "title": "…", "state": "PLANNED|CLAIMED|BUILT|SELF_GATED|LANES_PASSED|VERIFIED|MERGED_DEVELOP|E2E_DEVELOP|BLOCKED|STOPPED",
                "branch": "agrimore/x1-…", "worktree": "…/Agrimore-x1", "depends_on": [], "contract": { …SKILL §2.2… },
                "step": "<next step id>", "ticks": 0, "evidence": { "gate": "logs/…", "lanes": {…}, "merge": "…" },
                "deploy_consequence": "NONE | functions:a,functions:b | firestore:rules | firestore:indexes",
                "blocked_reason": null } ],
  "promotions": [], "ticks": 0, "started": "<iso>", "stop": null, "tick_log": [ {"t":"<iso>","phase":"X-1","step":"…","result":"…"} ]
}
```

`wake_seconds: 60` is the working default (owner decision, 2026-09-07) — not a theoretical starting point.
Long-running commands inside a tick (an emulator sweep, `npm ci`, an 8-package `pub get`) already run
to completion before the wake fires, so 60s mostly governs the gap between ticks once a tick's own
work is done, not how often the loop interrupts real work.

## 3. The tick

1. Load state. If `stop` is set → call the loop's stop (`ScheduleWakeup stop`) and end.
2. Budget check: `ticks ≥ max_ticks` or elapsed ≥ `max_hours` or the phase's `ticks ≥
   max_ticks_per_phase` → `STOPPED(budget)`.
3. Pick the current phase: the first phase not in a terminal state whose `depends_on` are all
   `MERGED_DEVELOP`/`E2E_DEVELOP`. `BLOCKED` phases are skipped while an independent one remains;
   if none remains → `STOPPED(all remaining phases blocked)`.
4. Execute **one** step for its state (table below), using the mode's reference.
5. Write evidence paths, advance `state`/`step`, append the tick log, rewrite `STATUS.md`
   (`scripts/state.sh status`).
6. `ScheduleWakeup` with `delaySeconds` = `config.wake_seconds` (long-running commands run to
   completion inside the tick; the wake is for the next step, not for polling), `noop:false` when
   anything changed, `reason` naming phase and step.

| State | Step(s) — one per tick unless trivially small |
|---|---|
| PLANNED | collision check (three sources) → worktree add from `base` → `npm ci` + `flutter pub get` ×8 → identity check → claim row commit → `CLAIMED` |
| CLAIMED | `gate.sh --baseline` → read contract files in full → `BUILT` begins: one workstream per tick (commit each, typed, deploy consequence in the message) |
| BUILT | `gate.sh` after the last commit (five apps if `packages/**` moved) → `SELF_GATED` (or fix one red per tick; two consecutive reds on the same check → `STOPPED`) |
| SELF_GATED | one lane per tick (`security` → `uiux` → `feedback`), each writing its report to `logs/` → `LANES_PASSED` (any `BLOCKING` → fix in ≤ 2 ticks or `BLOCKED`) |
| LANES_PASSED | VERIFY per `cto.md` §2 with fresh evidence (revert-and-watch, may_write diff, emulator probes for rules/functions) → `VERIFIED` or back to `BUILT` with findings |
| VERIFIED | `merge-develop.sh` → inspect → `--commit` → checks → ledger bookkeeping → worktree removal → `MERGED_DEVELOP` |
| MERGED_DEVELOP | from the worktree holding `develop`: `gate.sh --emulator` (fresh emulator, ports free) for a rules/functions phase; `flutter run -d web-server` (`.claude/launch.json` marketplace-web) or the AVD for a screen phase, when `allow_device_run`; record what was seen and not seen → `E2E_DEVELOP` |

## 4. Hard stop conditions (write the reason to `STATUS.md`, set `stop`, end the loop)

- an owner decision is required and no independent phase remains
- the same gate or suite is red on two consecutive ticks for the same step
- an unattributed change appears in a worktree the loop uses, or `develop` moved by a commit the
  loop did not make and the contract's `may_write` overlaps it
- a permission is denied, a command hangs past its time box (default 45 min), or disk headroom
  drops below 15 GB (`df -h /`)
- another `ACTIVE` claim or a topically overlapping branch appears for the current scope
- a merge conflict lands in a file the phase does not own — `firestore.rules` and
  `functions/src/index.ts` are the historical collision files; a conflict there is a stop, not a fix
- any secret-shaped value is encountered in a diff, a log, an env dump, or a test fixture
- an emulator port (8080 / 5001 / 9099 / 4000) is held by a process the loop did not start
- any step would require `firebase deploy`, `firebase functions:delete`, a write to `agrimore-66a4e`
  (an Admin-SDK script, `--apply`, a console-equivalent), a push, a real OTP send, or a Play upload
- the programme is complete (every phase `E2E_DEVELOP`) → `stop` with a completion summary and the
  deploy handover (`promote.md` §4) for the owner

`BLOCKED` (not stop): a phase needs an owner decision, a Firebase-side action (a settings document,
a webhook URL, a Secret Manager entry, a release), or a fix outside its `may_write`. Record the
reason, move on if something independent remains.

## 5. What the loop may and may never do

**May:** create/remove phase worktrees (porcelain commands only) · commit on phase branches · merge
into `develop` inside the worktree holding it · run `flutter analyze` / `flutter test` / `flutter build`
(debug) / `npm run build` / the Node suites / `firebase emulators:exec` on free ports · read the cloud
with `firebase functions:list`, `firebase firestore:indexes`, `node scripts/verify_secrets.js` ·
open the browser preview · write under `~/.agrimore/run/` and the phase worktree.

**Never:** `firebase deploy` (any target) · `firebase functions:delete` · any write to
`agrimore-66a4e` · push anything · gate or commit while `main`/`staging` is checked out · clear the
single folder's standing WIP ·
`rm -rf` a worktree, `git clean`, `reset --hard`, `update-ref`, delete a branch · stop or restart an
emulator it did not start · send a real OTP (the client base URL is production) · run
`functions/scripts/phase16_profile_backfill.js` or any migration with `--apply` · install or
upgrade toolchain (`flutter upgrade`, global npm, JDKs) · widen permissions · change `config`
values it did not start with · continue after a stop condition.

## 6. Permissions for unattended operation

The loop only runs unattended when the harness will not prompt. Run the session in auto mode and
keep the project allowlist (`.claude/settings.local.json`, untracked) covering the loop's safe
command set: `git -C * worktree add|remove|prune *`, `git -C * merge *`, `git -C * commit *`,
`git -C * fetch . *`, `flutter analyze|test|pub get|build apk --debug|run -d web-server *`,
`dart run melos *`, `npm ci`, `npm run build`, `node scripts/*`, `node functions/scripts/phase*_test.js`,
`firebase emulators:exec *`, `firebase functions:list *`, `firebase firestore:indexes *`,
`bash .claude/skills/agrimore/scripts/*`, `lsof *`, `df -h *`. **Never allowlist** `firebase deploy*`,
`firebase functions:delete*`, `firebase functions:secrets:set*`, `git push*`, `rm -rf*`,
`git reset*`, `git clean*`, `node * --apply`, `flutter upgrade`.

## 7. Starting, watching, stopping

```
/agrimore plan: <the whole ask>      → writes state.json with the phase contracts; changes nothing in the repo
/loop /agrimore run                  → self-paced ticks until DONE or STOP
cat ~/.agrimore/run/<programme>/STATUS.md
/agrimore run stop                   → sets stop; the next tick ends the loop (or ScheduleWakeup stop immediately)
```

`STATUS.md` carries: programme · tick count and elapsed · current phase/state/step · last evidence
paths · blocked phases with reasons · promotions · the deploy consequences accumulated for the owner
· the last 10 tick-log lines · the stop reason.

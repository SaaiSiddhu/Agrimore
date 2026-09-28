# AgriMore Delivery Partner App — Handover Report

This is the canonical, durable handover document for `apps/delivery`. It is designed to be useful
without access to any chat history. It cross-references, rather than duplicates,
`~/.agrimore/run/delivery-ui-redesign/` (`state.json` — per-workstream investigation detail,
`coverage.csv` — per-canonical-phase screenshot/test matrix, `decisions.md` — locked
`OWNER_DECISION`s, `closure_matrix.md` — the C1–C7 release-acceptance tracker) and
`docs/active/BRANCH_DISPOSITIONS.md` (the one branch-disposition authority — every phase named
below has its own full row there with exact evidence).

---

## A. Snapshot

- **Date**: 2026-09-28 (IST).
- **Final integrated `develop` revision at the time of this report**: `9386c37a` (ledger
  bookkeeping commit recording DLVC5's own merge at `836d1ddd`).
- **Scope of this pass**: an owner-authorized integration, handover and disk-cleanup pass —
  merge completed/verified delivery-app work into `develop`, remove redundant now-integrated
  delivery worktrees once verified safe, produce this report, and reclaim disk space on a
  machine that had become critically full (see §H). No new feature development was performed
  beyond what was already in flight when this pass began (DLVC1–DLVC5, all completed and
  integrated as part of this same pass).
- **Tested revision**: the same `9386c37a` — `flutter test` (437/437), `flutter analyze` (0
  error-level lines, all five apps), and `functions npm run build` (exit 0) were all re-run on
  this exact revision as the final step of this pass (§G).
- **Integration vs. deployment status**: everything below is integrated into `develop` only.
  **Nothing was deployed.** No `firebase deploy` of any kind was run; no Play Store/App Store
  artifact was built or uploaded; no remote branch was pushed. `staging`/`main` are untouched.
  Several already-integrated phases (from before and during this session) carry their own
  documented, **not-yet-run** deploy consequences — see `docs/active/
  ADMIN_FINANCE_SUPPORT_RELEASE_MANIFEST.md` for the admin/finance side (unrelated to delivery,
  produced concurrently by other work on this same `develop`) and the per-phase rows below for
  delivery's own.

---

## B. Completed work, by canonical phase

The 32 canonical UI phases live at `apps/delivery/assets/ui-mockups/01-brand-visual-identity`
through `32-accessibility-interaction-behaviour`. `coverage.csv` (140 rows) is the existing,
maintained per-phase matrix; this section summarizes its current distribution and this session's
own additions rather than re-deriving all 140 rows from scratch (that full re-derivation was last
done in the DLVQ1 audit, 2026-09-26, cited below with its own method disclosed).

**DLVQ1 coverage re-audit (2026-09-26), the most recent full pass across all 140 rows** — method:
every row's implementing file(s) and test file(s) read directly, cross-checked against on-device
screenshots, with a representative sample additionally checked against the original mockup PNGs
side-by-side with the code:

| Result | Rows | Meaning |
|---|---|---|
| `verified_code_and_screenshot` | 51 | Implemented, behaviour-tested, and a personally-inspected on-device screenshot exists |
| `code_verified_no_screenshot` | 69 | Implemented and behaviour-tested; no screenshot on file |
| `partially_verified` | 10 | Real, non-trivial gap found and disclosed per row (see `state.json`'s `dlvq1_coverage_reaudit.new_gaps_found_this_pass` and the 9-gap tracking entry below) |
| `p0_fix_verified` | 1 | The `DeliveryOtpField` 4-vs-6-digit regression, found and fixed same phase |
| `genuine_gaps_or_unknowns` | 9 | Real, named gaps — tracked individually, not glossed over |

**Of the original 9 gaps** (`state.json`'s `dlvq1_9_gaps_status_2026-09-27`), 7 are now closed by
phases built after DLVQ1 (dashboard screenshot, support-access-from-active-delivery, assignment
recovery, stale-location banner — each with its own merged phase and test evidence). 2 remain
genuinely open:
- **Phase 32, image 02 (screen-reader labels)**: real `Semantics` structuring was added (DLVACC1)
  but never run through an actual TalkBack/VoiceOver pass or an accessibility scanner — an
  environment/hardware blocker, not unbuilt scope. See C5 below.
- **Phase 18 (dashboard earnings summary)**: reopened as a *bigger* item than first described —
  the current `_buildEarningsCard`/`_moneyStats` layout is a materially different, simpler design
  than mockup 18.4's Today/This-week toggle card with 4 named component states (Loading/Empty/
  Stale/Failed). Not fixed; explicitly scoped as its own future phase or an owner decision to keep
  the simpler layout deliberately.

**This session's own additions (DLVC1 through DLVC5, all merged into `develop`)** — these are the
first genuinely *connected* (real emulator, real widgets, real callables) proofs for several flows
that were previously only unit/widget-tested or backend-tested in isolation:

| Phase | What it closed | Branch tip (pre-merge) | Merge commit |
|---|---|---|---|
| DLVC1 | C1 §4.2: statement-pagination footer wording (found+fixed: cap-paused vs. genuinely-exhausted were visually identical) and a text-scale scroll-into-view bug (found+fixed: fixed-pixel row-extent jump undershot under 2x text scale) | `e1d68352` | `24b7e76d` |
| DLVC2 | First connected document-review journey (submit→reject→resubmit→approve, real Storage+Firestore+Functions+Auth emulators); found+fixed an FCM hang, a `RiderProfileScreen` auth race (worked around in the test only at this point — see DLVC3), a below-fold scroll gap; found+fixed a real notification-routing gap (`document_review_approved`/`rejected` went nowhere) | `e6a63b61` | `31b421a2` |
| DLVC3 | Fixed the `RiderProfileScreen` auth race **in production code** (`_UidBoundStream`, 7 new tests, 3 confirmed via revert-and-watch); assessed FCM token registration (confirmed non-blocking, added a bounded timeout); built exact-submission document-review and exact-report incident notification destinations (`DocumentSubmissionScreen`, `IncidentStatusScreen`/`MyIncidentsScreen`); compiled the full notification destination table | `f26b329b`, `c28da7cd` | `54ed5770` |
| DLVC4 | First connected support-ticket journey on a real Android emulator (submit+attachment→restart→admin seen/close→exact-ticket notification, plus 8+ named edge cases); found+fixed a wrong-string bug in `SupportRequestStatusScreen` and a missing injection seam in `HelpSupportScreen` | `4a846260` | `174f6b3c` |
| DLVC5 | C3 platform readiness: provisioned a working iOS Simulator on this machine for the first time (Xcode/CoreSimulator/CocoaPods were each incomplete or missing); found+fixed a real iOS build-readiness gap (deployment target too low for `google_maps_flutter_ios`) | `57af370b` | `836d1ddd` |

Full narrative evidence for every phase above (exact commands run, exact test counts, exact
revert-and-watch results) is in `docs/active/BRANCH_DISPOSITIONS.md` under each phase's own row —
this report does not reproduce it verbatim to stay readable.

**Distinguishing the maturity levels the owner asked to track**, as of this report:

| Flow | Implemented | Behaviour tested | Backend integrated | Connected journey tested | Visually inspected | Android verified | iOS verified | Deployed |
|---|---|---|---|---|---|---|---|---|
| History/search (C1, §4.1–4.2) | ✅ | ✅ | ✅ | n/a (no backend round-trip needed beyond Firestore reads already covered) | partial (screenshots exist for the sheet; not every state) | ✅ | not attempted | ❌ |
| Document review (C2 §5.1) | ✅ | ✅ | ✅ | ✅ (DLVC2) | not this session | ✅ (`emulator-5560`) | not attempted | ❌ |
| Support tickets (C2 §5.2) | ✅ | ✅ | ✅ | ✅ (DLVC4) | not this session | ✅ (`emulator-5554`) | not attempted | ❌ |
| Profile auth lifecycle | ✅ | ✅ (7 targeted tests) | n/a (client-side fix) | ✅ (re-ran DLVC2's own journey post-fix, no regression) | not this session | ✅ | not attempted | ❌ |
| Incident notifications | ✅ | ✅ | ✅ | not as its own dedicated connected journey (proven via unit/widget tests + a real-emulator backend assertion) | not this session | not this session | not attempted | ❌ |
| FCM push **transport** (not registration) | n/a | n/a | n/a | ❌ **BLOCKED** — needs an authorized non-production Firebase project + device | n/a | n/a | n/a | ❌ |
| iOS build (debug, simulator) | ✅ (config fixed) | n/a | n/a | ❌ **not completed** — `pod install` proven; full compile hit this machine's own disk exhaustion, not a code defect | n/a | n/a | ❌ (see C3) | ❌ |
| Android release build (signed) | n/a | n/a | n/a | ❌ **BLOCKED(owner action)** — real keystore, owner's own machine/decision | n/a | n/a | n/a | ❌ |

---

## C. Remaining work (C1–C7, from `closure_matrix.md`)

- **C1 — History and search readiness**: **PASS.** Every §4.1/§4.2 item closed this session
  (DLVC1) or previously (DLVH-series), including the two real defects DLVC1 found and fixed. One
  low-priority item left explicitly `OPEN`: no dedicated large-N statement-pagination throughput
  benchmark exists (correctness is proven via cursor-based paging + a hard page cap; throughput is
  not measured). Not a blocker.
- **C2 — Connected document/support/notification workflows**: **PASS** for document review,
  support tickets, Profile's auth lifecycle, FCM token registration, and every notification type
  that has a real destination. **BLOCKED**, disclosed, not silently dropped: real push **transport**
  (foreground/background/cold-start tap handling) for every notification type identically — this
  needs an authorized non-production Firebase project wired to a real or emulator device; the
  connected tests built this session prove inbox-tap routing and destination-screen correctness,
  never that an actual push notification was received by a killed/backgrounded app. Next concrete
  action: the owner authorizes a specific non-prod Firebase project (or a scoped test config on
  the existing one) for this one check.
- **C3 — Android/iOS platform readiness**: see the fully updated table in `closure_matrix.md`
  (reproduced in outline in §B's maturity table above). Android debug: **PASS**. Android release
  signing: **BLOCKED(owner action)** — real keystore, owner must run it. iOS toolchain + `pod
  install`: **PASS**, fixed this session. iOS full compile: **not completed**, blocked by this
  machine's own disk exhaustion (now resolved, see §H) rather than by any code issue — the next
  concrete action is simply retrying `flutter build ios --simulator --no-codesign` in a worktree
  with the fixed Podfile/pbxproj (already on `develop`). iOS release signing: **BLOCKED(owner
  action)** — needs a real Apple Developer account/certificates.
- **C4 — Canonical visual coverage**: **OPEN — not started this session.** `coverage.csv`'s own
  140-row matrix (§B) is the existing evidence; this block's own job (re-walking it against light/
  dark/system theme, small/large phones, large text, keyboard-visible-forms requirements
  specifically) has not been done as its own pass. Next action: a dedicated visual-coverage sweep,
  likely via the existing screenshot-tour harness (`integration_test/screens_tour_test.dart`) run
  across each required configuration.
- **C5 — Accessibility**: **OPEN, partially evidenced.** Automated `Semantics` widget tests exist
  (DLVACC1) and are real, not superficial. The one item that cannot be closed by more coding is a
  manual TalkBack (Android) / VoiceOver (iOS) pass, or an automated accessibility-scanner run — no
  phase this session had a device/tooling setup available for this. Next action: owner runs (or
  authorizes time on a device for) one real screen-reader pass; do not let this block the rest of
  C5 (per the brief's own instruction not to block a whole section for one manual-only check) —
  every other accessibility item this codebase can self-verify should be re-walked independently.
- **C6 — Startup performance**: **OPEN — prior data (2026-09-25/26, 3 runs, debug build, emulator
  only) is insufficient per the brief's own standard** (≥5 comparable runs, profile/release
  builds, no artificial delays, no emulator-timings-as-physical-device claims). Next action: once
  a physical device or a profile/release build pipeline is available, re-measure signed-out/
  signed-in/offline cold-start ≥5× each.
- **C7 — Final connected regression**: **OPEN — blocked on C3–C6.** DLVR2's own connected
  evidence (reassignment, release, completion, account-switch) remains valid and reusable; it will
  not be rerun unless a C3–C6 change touches that behaviour. Next action: once C3–C6 close or are
  formally accepted as blocked, run the full regression pass and produce the final 12-item
  handover this report's own closing section does not replace (that is a *release-acceptance*
  sign-off; this report is an *integration/cleanup* handover — the two are related but distinct,
  and C7 is what would produce the former).

**Unfinished parallel UI/UX work, named separately so it is not lost or confused with release
acceptance** (per the owner's own instruction):
- Dashboard earnings-summary redesign (phase 18) — a real, disclosed, materially-sized visual gap
  against mockup 18.4, deliberately deferred (see §B).
- History's coarse status filter (only `all/delivered/cancelled/returned`, no separate date-range
  search beyond what DLVC1 built) — not a defect, just less granular than some mockups imply.
- The nav-shell vs. mockup-07 conflict (`state.json`'s `dlvnav1_mockup_conflict`) — a deliberate,
  disclosed `OWNER_DECISION` favouring a persistent 5-tab shell over the mockup's own linear
  "Dashboard is home, everything else pushes on top" design; not revisited this session.

---

## D. Decisions (preserved, not reopened)

From `~/.agrimore/run/delivery-ui-redesign/decisions.md` (the locked `OWNER_DECISION` record —
read it directly for full detail; this is a pointer, not a copy):

- **D2** — Burnt Orange `#C2410C` brand palette and full dark-theme parity, including the
  single-border (never a halo) keyboard-focus treatment.
- **D1** — The delivery app owns its own design system (`apps/delivery/lib/design_system/`),
  deliberately not sharing `agrimore_ui` beyond what already existed.
- **D4** — No artificial splash delay on the startup critical path.
- **D5** — Preserve existing business logic and widget-test contracts; redesign is visual/IA, not
  a rewrite of already-correct logic.
- **D6 (2026-09-28)** — No rider compensation for returned orders; current `HistoryDetail`/
  `riderMoney.ts` behaviour is correct as-is. **Do not reopen.**
- **Five-tab persistent bottom navigation** (`state.json`'s `dlvnav1_shell`/
  `dlvnav1_mockup_conflict`) — an explicit `OWNER_DECISION` overriding mockup 07's own linear,
  no-bottom-nav design, because the session's own governing brief explicitly and repeatedly
  demanded a persistent 5-tab shell (Home/Deliveries/Earnings/Inbox/Profile).
- **Flutter, Android + iOS** — the platform choice for this app is a foundational, unchanged fact
  of the repository, not a decision made or revisited this pass.
- **Production changes require explicit owner authorization** — reaffirmed throughout this pass:
  no `firebase deploy`, no keystore access, no remote push. See §A/§H.

---

## E. Integration inventory

| Branch/workstream | Original commit(s) | Merge into `develop` | Validation performed | Preserved unfinished work |
|---|---|---|---|---|
| `agrimore/dlvc1-closure-c1-history-search` | `e1d68352` | `24b7e76d` | `flutter test`, `flutter analyze` x5, revert-and-watch on both fixes | none — fully closed |
| `agrimore/dlvc2-connected-document-review` | `e6a63b61` | `31b421a2` | connected-emulator journey run to pass, `flutter test`, `flutter analyze` x5 | none — fully closed (FCM registration/lifecycle gaps it surfaced were closed by DLVC3) |
| `agrimore/dlvc3-profile-lifecycle-notification-destinations` | `f26b329b`, `c28da7cd` | `54ed5770` | 18 new tests incl. 3 revert-and-watch-confirmed, `flutter test` 433/433, `flutter analyze` x5, re-ran DLVC2's journey unchanged | none — fully closed |
| `agrimore/dlvc4-support-connected-journey` | `2de08817`, `4a846260` | `174f6b3c` | connected-emulator+real-device journey run to pass (`EXIT=0`), `flutter test` 435/435, `flutter analyze` x5 | none — fully closed |
| `agrimore/dlvc5-ios-build-readiness` | `57af370b` | `836d1ddd` | `pod install` before/after proof, real simulator boot, `flutter analyze` x5 | iOS full-compile verification — disk-blocked, not code-blocked; see §C/§H |

Worktrees for all five branches above, plus `agrimore/dlvhome1-canonical-color-home-redesign`
(a sixth, already-merged-by-a-different-session delivery worktree found during this pass's own
inventory — confirmed via `git merge-base --is-ancestor` to already be fully integrated, not
"unrelated" as an earlier note in this session had it), were removed in §H below. Their branches
were deleted with `git branch -d` (git's own safe-delete, which refuses on unmerged work) after
each was independently confirmed to be a true ancestor of `develop`.

---

## F. Environment and setup

**Required tooling** (all confirmed present/working on this machine as of this pass):
- Flutter 3.44.8, Dart (bundled), stable channel.
- Node 26.5.1 / npm 11.17.0 (`functions/`).
- `firebase-tools` 15.28.1, logged in as `agrimorein@gmail.com`, `firebase use` → `agrimore-66a4e`.
- JDK 21 at `/opt/homebrew/opt/openjdk@21` — **required** for the Firebase emulator suite; the
  default JDK on this machine is too old (`firebase-tools` refuses Java < 21). Set
  `JAVA_HOME=/opt/homebrew/opt/openjdk@21` and prepend its `bin` to `PATH` before running
  `firebase emulators:start`.
- Xcode 27.0 (`/Applications/Xcode.app`), CoreSimulator framework, iOS 27.0 (24A434) simulator
  runtime, CocoaPods 1.17.0 (`brew install cocoapods`) — **all provisioned this session**; were
  either missing or incomplete before.
- Android SDK platform-tools (`~/Library/Android/sdk/platform-tools/adb` — not on `PATH` by
  default in this shell; invoke by full path or add it). AVD `Pixel_8_API_35` is the canonical
  delivery-app test device.

**Emulator/test configuration**:
- Firebase emulators for a connected test: **do not use the default ports** — Docker Desktop
  permanently holds `8080` on this host. Use an alternate set (this session used
  `8580`/`9699`/`5301`/`9599` for Firestore/Auth/Functions/Storage) by temporarily editing the
  worktree's own `firebase.json`, then **reverting it** after (`git checkout -- firebase.json` is
  safe here specifically because it is a clean revert of your *own* temporary edit, confirmed via
  `git diff --stat` empty before and after — this is not the same as a blanket revert of someone
  else's work).
- Android emulator connects to the host's Firebase emulators via `10.0.2.2`, not `localhost`.
- Sign-in for a connected test is always via a custom token minted by a Node fixture script
  (`functions/scripts/phaseDLVC*_*_fixtures.js`), never the real phone-OTP UI — this repository
  has its own recorded near-miss from partial emulator isolation triggering a real OTP.
- Admin actions in a connected test go through a **second**, independently-signed-in
  `Firebase.initializeApp(name: ...)` instance calling the real admin callable — never the admin
  Flutter app's own UI, never a raw Firestore write for a callable-gated action.
- `google-services.json` (Android) is untracked/gitignored and must be manually copied from the
  primary checkout into any **new** worktree before an Android build/test can run there — this is
  a non-secret-by-design file (Google client keys), but each copy into a new worktree still needs
  the owner's own fresh, explicit authorization (a prior grant for one worktree does not carry to
  another).
- `apps/delivery/ios/Podfile` and `Podfile.lock` are now tracked in git for the first time (as of
  DLVC5) — do not let a future `flutter pub get` silently regenerate over the `platform :ios,
  '14.0'` line.
- `android/key.properties` + `android/upload-key.jks` (the real Play signing keystore) exist only
  in the primary checkout and are never to be copied anywhere without the owner's own explicit,
  narrowly-scoped authorization — treat this the same as any other production secret, not like
  `google-services.json`.

**Known platform/signing/deployment dependencies**: see §C (C3) and the release-manifest doc
(`docs/active/ADMIN_FINANCE_SUPPORT_RELEASE_MANIFEST.md`, admin/finance side, unrelated to
delivery but on the same `develop`) for what else in this repository is merged-but-undeployed.

---

## G. Evidence

- **Tests**: `apps/delivery` `flutter test` — 437/437 passing on the final integrated revision
  (`9386c37a`). `flutter analyze` — 0 error-level lines in all five apps (marketplace/admin carry
  pre-existing, unrelated info/warning-level debt; delivery itself shows "No issues found!").
  `functions npm run build` — exit 0.
- **Connected journey logs**: not preserved as separate files this pass (each connected test run's
  own pass/fail output was inspected live during DLVC2/DLVC4); the tests themselves
  (`integration_test/document_review_connected_test.dart`,
  `integration_test/support_connected_test.dart`) are the reproducible evidence — rerun them per
  §F's own setup instructions to reproduce.
- **Screenshots**: `screenshots/android/` (referenced throughout `state.json`/`coverage.csv`);
  none newly captured this pass (this was an integration/cleanup pass, not a visual pass — that is
  C4's own job).
- **Coverage matrix**: `~/.agrimore/run/delivery-ui-redesign/coverage.csv` (140 rows).
- **Startup measurements**: last taken 2026-09-25/26 (3 runs, debug, emulator only) — explicitly
  insufficient per C6's own standard; not re-measured this pass (out of this pass's own scope).
- **Known verification limitations**, stated plainly: FCM push transport is unverified (C2);
  iOS full-compile is unverified this pass (disk-blocked); Android/iOS release signing is
  unverified (owner-scoped secrets); a manual screen-reader pass has never been performed (C5);
  visual coverage across theme/size/text-scale/keyboard-visible-form configurations has not been
  freshly re-walked (C4).

---

## H. Cleanup and recovery

**Disk measurements**:
- **Before this pass's cleanup**: `df -h /` showed as low as **245MB**, then **~1GB**, free on a
  460GB volume (99%→93% reported capacity — the low "Used" figure relative to volume size reflects
  APFS container-wide space shared with other volumes/snapshots on this machine, not a metric this
  pass can fully explain or control).
- **After**: **22GB** free.
- Caveat, stated per the owner's own instruction: this is a **shared, multi-project machine** with
  continuous concurrent activity from other sessions/tools during this pass (a live ChatGPT/Codex
  process with write access to the primary checkout was found running; several unrelated
  admin-app phases merged into `develop` concurrently throughout). The ~21GB delta is a real,
  measured before/after difference, not a precise accounting of what this pass alone removed.

**Worktrees removed** (all six confirmed, via `git merge-base --is-ancestor`, to be true ancestors
of `develop` before removal — not squash-merge guesses):

| Worktree | Branch | Why safe | Unique content preserved |
|---|---|---|---|
| `Agrimore-dlvc1` | `agrimore/dlvc1-closure-c1-history-search` | ancestor of `develop`; dirty state was only the recurring, confirmed-byte-identical CocoaPods `#include` noise + an untracked template `Podfile` | none — nothing unique existed |
| `Agrimore-dlvc2` | `agrimore/dlvc2-connected-document-review` | same | none |
| `Agrimore-dlvc3` | `agrimore/dlvc3-profile-lifecycle-notification-destinations` | same | none |
| `Agrimore-dlvc4` | `agrimore/dlvc4-support-connected-journey` | same (also carried the same noise for employee/seller apps, a side effect of an earlier 5-app `flutter analyze` sweep) | none |
| `Agrimore-dlvc5` | `agrimore/dlvc5-ios-build-readiness` | its one genuine piece of unique work (the iOS deployment-target fix) was committed and merged into `develop` *before* removal | none — fix is on `develop` |
| `Agrimore-dlvhome1` | `agrimore/dlvhome1-canonical-color-home-redesign` | ancestor of `develop` (already merged by a different session; an earlier note in this same session's own record had incorrectly called it "unrelated, unmerged" — corrected in `docs/active/BRANCH_DISPOSITIONS.md`'s DLVC5 row and here) | none |

Removed via `git worktree remove --force` (the supported git-native mechanism; `--force` was
needed only to bypass git's own refusal over the confirmed-trivial dirty files above — never used
to bypass understanding them) followed by `git branch -d` (git's own *safe* delete, which itself
refuses on any not-yet-merged branch — a second, independent confirmation these were safe).

**Also reaped**: 3 orphaned `flutter_tester` processes (parent PID 1 — their original driver
processes were long dead), one tied to `Agrimore-dlvhome1` (2h29m old) and two tied to worktree
paths that no longer exist at all (`Agrimore-dlvsup1`, `Agrimore-dlvp1`, 1–2 days old). Killing a
`ppid=1` orphan is inherently safe — by definition nothing is still waiting on it.

**Left deliberately untouched**:
- The primary checkout (`/Users/saai_siddharth/Projects/Clients/Agrimore`) — a live, actively-used
  ChatGPT/Codex process holds write access to it.
- `/Users/saai_siddharth/.codex/worktrees/delivery-visual/Agrimore` — that same other tool's own
  worktree.
- `Agrimore-dlvmap3` — the worktree holding `develop`; the one used for every merge in this pass.
- `Agrimore-sredesign` (seller-app UI, an unrelated concurrent session's own work) — not this
  pass's to touch or judge.
- Any other client project under `Projects/Clients/` (RetroClub, Jai-Gold, Rangaa Roots, Clinic,
  Theni-Jobs variants, etc.) and their own build caches — out of scope, not inspected for content,
  not touched.
- Global caches (Gradle/Pub/npm/Xcode DerivedData for other projects) — not wiped.
- `android/key.properties`/`upload-key.jks` and every other secret named in `CLAUDE.md` §2.7 —
  no access attempted.

**Restoration**: nothing here needs restoring — every removed worktree's content is confirmed,
by real ancestry (not assertion), to already exist on `develop` at `9386c37a`. If a fresh worktree
for further delivery work is needed: `git worktree add ../Agrimore-<slug> -b
agrimore/<id>-<slug> develop` from `Agrimore-dlvmap3`, then copy `google-services.json` from the
primary checkout (fresh owner authorization required) before any Android build/test.

---

## I. Resume instructions

1. **Start from**: `develop` @ `9386c37a` (or later — check `git log -1 develop` first; this is a
   heavily concurrent repository and other sessions continue to merge unrelated admin-app work).
2. **Read first**: this report, then `closure_matrix.md` for the exact C1–C7 state, then
   `state.json`/`coverage.csv` if working on a specific canonical phase (C4 especially).
3. **What remains**, in the brief's own priority order: C4 (visual coverage sweep), C5 (one manual
   screen-reader pass — the rest of C5 can proceed independently), C6 (≥5 profile/release-build
   startup measurements), C7 (final regression, blocked on C3–C6), plus FCM push-transport
   verification (needs an authorized non-prod Firebase project) and the iOS full-compile retry
   (code-ready, just needs to actually be run now that disk headroom exists).
4. **Commands that reproduce the current baseline**:
   ```bash
   cd apps/delivery && flutter analyze && flutter test   # expect 0 errors, 437/437
   cd functions && npm run build                          # expect exit 0
   ```
   For a connected-emulator test, see §F's own setup notes (JDK 21, alternate ports, `10.0.2.2`,
   custom-token sign-in) before attempting one.
5. **Approvals/access still required**:
   - An authorized non-production Firebase project (or scoped config) for real FCM push-transport
     verification.
   - The owner's own machine/keystore for any Android release build.
   - A real Apple Developer account for any iOS release build/signing.
   - Fresh, per-worktree authorization to copy `google-services.json` into any new delivery
     worktree (never carries over from a prior grant).
   - A real device or accessibility-scanner session for C5's manual screen-reader pass.
   - A physical device (or a profile/release build pipeline) for C6's startup measurements.

**This delivery app is not fully complete.** Its release-acceptance criteria (C1–C7) are: C1 PASS,
C2 PASS except push-transport (BLOCKED, external dependency), C3 PASS for what code can fix
(BLOCKED for owner-only secrets, not-yet-retried for the disk-blocked iOS compile), C4/C5/C6/C7
still open. Do not represent this report as a "done" signal for the app as a whole — it is a
integration-and-cleanup checkpoint, accurately reflecting real, substantial progress and equally
real, named remaining work.

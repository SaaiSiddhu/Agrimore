# Hazards and standing rules — read before gates, greps, merges, installs, emulators

Every item here cost real time in this repository, most more than once. Measured facts carry the
commit they were measured at. **Not a substitute for measuring again.**

## Environment

- **`cd` does not persist between tool calls** ("Shell cwd was reset to …" is printed). `pwd` before
  every relative path; prefer `git -C <dir>` and absolute paths. `flutter test` reporting "Test
  directory not found" means you are in the wrong directory, not that the suite is gone.
- **The permission layer blocks one large chained destructive command** but allows the same work as
  smaller individual commands. Prefer small, individually scoped destructive commands.
- `bash` is 3.2: no `declare -A`, no `${var,,}`, no `mapfile`. `timeout` is not on this Mac.
- Three Agrimore-shaped directories exist on disk; only `Projects/Clients/Agrimore` (+ its
  `Agrimore-*` sibling worktrees) is real. `Projects/Clients/Clone/Agrimore*` are copies with stale
  `firestore.rules` (37 KB) and a live `fix_admin.js`; never edit, never `firebase` from them.
- `melos` is not on PATH — `dart run melos <cmd>` from the root (6.3.3). `melos run analyze` loops
  the packages but its exit code is meaningless (see below).

## Worktrees and checkouts

- The primary checkout `Projects/Clients/Agrimore` holds `main`. Never build, merge, commit or run
  gates there; phases live in `../Agrimore-<slug>`, integration in `../Agrimore-develop`.
- A fresh worktree has no `node_modules`, no `.dart_tool`, no `functions/lib`, no `functions/.env`,
  no `.secret.local`, no `google-services.json`, no `debug.keystore`. `npm ci` + `flutter pub get`
  ×8 first (~1 GB); the emulator needs the two env files copied in (never committed, never printed);
  a device run needs the two Android files per app (`Run` below).
- `git worktree add` fails if the branch is checked out elsewhere — never send its output to
  `/dev/null`. Worktree lifecycle has four steps (`merge.md` §4); a merged phase that leaves its
  worktree standing is `PARTIAL`. Never `rm -rf` a worktree; `df -h` before/after.
- One prunable stale record exists (`claude/bold-spence-01813b` → the old nested path). Leave it
  (D-PRUNE). The directory it points at (under `Clone/`) is not a worktree of this repository any more.

## Git, commits, index

- **`git add -A` and `git add .` are banned** — the shared index swept 43 files from another
  session into a commit with a false message (`444491d`, amended to `5b308c9`). Stage explicit paths
  and commit in the same shell command: `git add <new> && git commit -m "…" -- <paths>`.
  `git commit -- <paths>` alone cannot commit a brand-new file. `-m` precedes `--`.
- `git diff --cached` proves nothing about what a concurrent session will commit. Verify the
  COMMIT with `git show --stat HEAD`, never the tree.
- `git commit --amend --only -m` is safe to fix a message while others edit (ignores index and tree).
- Provenance after a bundle commit: the in-file `Phase NN` comments, never the commit message.
- The identity was unset for 69 commits (`.local` email) — verify `git log -1 --format='%an <%ae>'`
  after the first commit in every new worktree. No hooks exist to catch a bad message or a trailer.
- **A conflict-free merge is not proof; ancestry is not content** — check the result tree for the
  retired paths (`merge.md` §2). `firestore.rules` and `functions/src/index.ts` are the historical
  collision files: every concurrent-session incident touched both.
- Never stage `_env`, `.env`, `functions/.env`, `functions/.secret.local`, `google-services*.json`,
  `*.jks`, `key.properties`, `AGRIMORE_PLAYSTORE_AND_SECRET_KEYS_BACKUP*`, `build/`, `functions/lib/`.

## Measuring and greps

- **`flutter analyze` exits 1 on zero errors** whenever any info/warning exists — only
  `apps/employee` exits 0. Count `error •` lines. **The severity column is right-aligned**: `warning`
  has no leading spaces, `info` has three — `grep -c "^   warning"` returns 0 on a 175-warning app.
  Use `grep -cE '^ *error •'` etc. Baseline at `c8f6f30`: marketplace 0/175/342 (517), admin 0/92/524
  (616), seller 0/7/58 (65), delivery 0/3/30 (33), employee 0/0/0.
- **Never trust a piped exit code** (`cmd | tail` → tail's). Redirect to a file, then `echo $?` on
  the very next line — a later `echo` in the same sequence shadows `$?`.
- A real, non-piped `exit 0` + "Deploy complete!" was still wrong once (indexes no-op, 2026-09-03):
  verify cloud state by a read-only re-read, never by the summary line.
- `firebase functions:list` output includes a header row named `Function` — subtract it.
- Count live call expressions, not grep lines; read the context; a JSDoc mention is not a caller.
  `ls` for a filename is not a search for a symbol (`reconcileProductCreditBalances` lives in
  `productCreditExpiry.ts`). `unused_field` from the analyzer is not always dead (`_deliveryNote`).
- **Two `createOrder` call sites** (`payment_method_screen.dart`, `mobile_cart_screen.dart`); a prompt
  naming one was wrong. `orderMode` ≠ `orderType`; `status` mirrors `orderStatus` and the seller
  panel writes only `status`.
- An audit finding is a claim from its own moment: the M-9 audit item was wrong on 3 of 4 points
  (`record`/`audioplayers` back a live voice-note feature; the web deps back a real web build).

## Tests, gates, emulator

- **A gate never observed failing is not a gate.** Revert the fix and watch its own test fail.
- **`npm run build && node scripts/<suite>.js` as ONE command as the last action before committing** —
  a suite against a stale `lib/` reached `master` red twice (D-3, 16B-4).
- **The emulator refuses the default JDK 17**: `export JAVA_HOME=/opt/homebrew/opt/openjdk@21` (the
  Android Studio JBR 25 also works). `/usr/libexec/java_home -V` does not list the Homebrew 21.
- **Suites are not idempotent** (fixed doc ids, one-shot coupons, expired holds): a sweep needs a fresh
  emulator (`firebase emulators:exec` gives one per command). A failure on a reused emulator is not a
  regression until re-run clean.
- **Ports 8080 / 5001 / 9099 / 4000 are routinely held by a concurrent session**; orphaned
  `functionsEmulatorRuntime` processes outlive a killed parent — `ps` hits do not mean an emulator is
  up; `lsof -nP -iTCP:8080 -sTCP:LISTEN` does. Never stop an emulator you did not start; SKIP and say so.
- The emulator loads `functions/.secret.local`: with a real `TWOFACTOR_API_KEY` present every boot is
  provider-ENABLED, so `phase14_phone_otp_test.js` (asserts the disabled state) is structurally
  un-runnable there — not a regression. The suites mock 2Factor/Resend at the axios boundary; no real
  SMS/voice/email is sent by a suite. **The app client is different**: `auth_service.dart:334`
  hardcodes the production functions URL, so "test a login on a device" always spends a real
  production OTP (voice call) — never do that to look at a layout.
- The emulator does **not** enforce composite indexes; production throws `FAILED_PRECONDITION`.
- `firebase-functions-test`: v2 `wrapV2` takes ONE `{data, auth}`; v1 `wrap` takes `(data, {auth})`.
  Calling a v1 function the v2 way silently yields an unauthenticated context for every scenario.
  Set `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` for callables that end in `admin.auth()`.
- `verify_secrets.js` is a **deploy** gate (cloud metadata read); `phase19_client_secret_guard_test.js`
  is a **regression** gate. Never "fix" the first to look green; never weaken the second's
  `FORBIDDEN_ENV_NAMES`.
- `flutter test` runs only in `apps/marketplace` (3 files). `melos run test` would loop packages
  with no `test/` and report noise.

## Firebase, deploy, cloud (read-only here; the owner deploys)

- **Never a bare `firebase deploy --only functions`**: 6 live functions have no source anywhere and
  the CLI offers to delete them (non-interactive: aborts). Always `--only functions:<explicit names>`.
- **Gen1 → Gen2 is not an in-place update**: delete + recreate, one at a time, owner decision.
- **Rules deploy is all-or-nothing** and can break clients still on an older Play build (2026-08-31:
  pre-1.0.7 users lost ordering). State which released build satisfies each tightened rule.
- **Indexes**: `firebase firestore:indexes` (read-only) diffed against the file first; the file was a
  strict subset of production once (a deploy would have deleted 26 live indexes). `firebase.json`
  now declares `"indexes"`; before 2026-09-03 the deploy silently no-op'd with exit 0.
- `firebase functions:delete` can print FAILURE while succeeding — verify with `functions:list`.
- `functions/scripts/` USED to ship in every functions deploy bundle, which is how `fix_admin.js`
  reached GCP repeatedly (deleted in `8fd06b2`) and how `create_admin.js` became finding A-1. Phase
  SEC-1 (2026-09-04) deleted `create_admin.js` and added `scripts` to the functions `ignore` list, so
  the directory is no longer uploaded; `phase23_deploy_bundle_guard_test.js` fails if either regresses.
  Two things that did NOT change: the A-1 credential is still valid until the owner rotates it
  (D-CREATE-ADMIN), and the ignore entry only takes effect on the next functions deploy. Never put a
  credential under `functions/` regardless — the guard now catches password/secret/token/credential/
  apikey-shaped string literals there.
- `.firebaserc` is at the root now (flat layout); still pass `--project agrimore-66a4e` explicitly to
  any read-only cloud command so a wrong cwd can never hit another project (two other projects are
  visible on this account: `agrimore-8ae3b`, `arasupandian-farm-servic-a7c84`).
- The Play `versionCode` is date-based `YYYYMMDDnn` (1.0.7 = `2026082701`); a lower number is refused
  as a downgrade. `pubspec.yaml` is the single source (`flutter.versionCode` in gradle); verify the
  merged manifest after a build, not the green build.

## Run (local device / web)

- Per app, before `flutter run`: `android/app/google-services.json` reconstructed for that app's
  `applicationId` (marketplace `com.customer.agrimore`), `android/app/debug.keystore` copied from
  `~/.android/debug.keystore`. First Gradle build is 2–4 min (not hung — `ps aux | grep -i gradle`).
- The AVD `Pixel_8_API_35` exists; the harness simulator tool was gated off on 2026-08-30 while
  `flutter run -d emulator-5554` worked on 2026-09-03 — try, do not assume either way. No iOS.
- Web: `.claude/launch.json` → `marketplace-web` (`flutter run -d web-server --web-port 8090`);
  eye-verification of screens behind `AuthGuard` needs a throwaway preview entry point, deleted after.
- `font_awesome_flutter` must stay `^11.0.0` (`FaIconData`); the `DeliveryInfoForm` nine-argument fix
  in `apps/admin` is committed now — if either error reappears in a worktree, the worktree is stale,
  not the diagnosis.
- `withOpacity` → `withValues(alpha:)` migration is done in marketplace (M4); a `// ignore:
  use_build_context_synchronously` must sit on the line the diagnostic anchors to.

## Claim protocol reality

The ledger row is a lock, but **a row on an unmerged branch is invisible from `develop`** — check
`git worktree list` + `git branch --list 'agrimore/*'` + the `ACTIVE` rows, read for topic overlap,
before scoping. Run ONE phase at a time on this machine; commit between phases; the concurrency
incidents all came from parallel sessions on one checkout, which worktrees now prevent — provided
nobody works in the primary checkout.

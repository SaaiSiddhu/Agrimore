# CI — there is none (measured 2026-09-04 at `c8f6f30`), and what a future workflow may and may not do

**Fact:** no `.github/` directory, no workflow, no hooks (`.git/hooks` holds samples only), no
prettier, no lint-staged. `gh run list` has nothing to list. Every deploy to `agrimore-66a4e` has
been a manual `firebase deploy` from a laptop with the owner's same-conversation word. The remote
repository is public and has never received a push since 2026-05-05. **Do not describe a CI signal
that does not exist; do not treat the absence as "green".** The local battery (`scripts/gate.sh`) is
the only gate, and it runs only when someone runs it.

## 1. If a workflow is ever added — what it may do

- Trigger: `pull_request` and `push` to `develop` (and `staging`/`main` for the same checks). Jobs:
  Flutter `analyze` in all five apps with the **error count** as the pass condition (the tool exits
  1 on info lints — a job that reads the exit code fails forever); `flutter test` in
  `apps/marketplace`; `cd functions && npm ci && npm run build`; the three no-emulator guards
  (`phase19_client_secret_guard_test.js`, `phase18_secret_binding_test.js`,
  `phase16b4_fee_truthfulness_test.js`); `node scripts/governance/validate-branch-dispositions.mjs`
  (warnings). Optional nightly: the emulator suites under `firebase emulators:exec` with JDK 21 and
  `firebase-tools` pinned to 15.28.1 — they need `functions/.env` and `functions/.secret.local`
  **fixtures with placeholder values** (the suites mock 2Factor/Resend at the axios boundary), never
  real ones.
- Secrets referenced by name only; never a Firebase token or service account with deploy rights on a
  push-triggered job.

## 2. What it may never do

- **Never `firebase deploy` on push, on merge, or on tag.** A deploy workflow, if one is ever wanted,
  is `workflow_dispatch` only, takes the function names as an input, requires an environment with a
  required reviewer (the owner), and prints `firebase functions:list` before and after. A bare
  `--only functions` in CI would offer to delete the 6 orphan functions — and non-interactive mode
  aborts, which reads as a failed deploy for the wrong reason.
- Never `firebase functions:delete`, never `firestore:indexes` deploy without the live diff step,
  never `firestore:rules` deploy without the client-compatibility statement.
- Never store the keystore, `google-services.json`, `_env`, or the backup zip as a CI secret while
  the repository is **public** (finding A-2): fork pull requests and workflow logs are an exposure
  surface. Make the repository private first.
- Never widen `permissions:`; never let a workflow write to the repository (no auto-commit of
  generated files — nothing here is generated).

## 3. Reading a red run, when there is one

```bash
gh run list --repo SRIESWARAN01/Agrimore-Full-Project --limit 20 --json name,headBranch,headSha,conclusion,createdAt,event
gh run view <run-id> --repo SRIESWARAN01/Agrimore-Full-Project --json jobs --jq '.jobs[] | "\(.conclusion)\t\(.name)"'
gh run view <run-id> --repo SRIESWARAN01/Agrimore-Full-Project --log-failed | sed 's/\x1b\[[0-9;]*m//g' | grep -B8 '##\[error\]'
```
A red run is evidence, not a verdict. Attribute each failing job to: code defect · a check that
misreads `flutter analyze`'s exit code · missing fixture (`functions/.env`) · missing toolchain
(JDK 21) · policy. Never delete a check to go green.

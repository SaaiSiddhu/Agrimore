# Agrimore → new Mac via T7: preservation and verification plan

Prepared 2026-09-28. Status: PLAN / INITIAL INVENTORY ONLY. No transfer or restore has occurred in this task. T7 was not mounted during inspection. No application changes, commits, branch changes, deployments or tests were performed. Single-agent review.

## Context and scope

The referenced “Research unified commerce OS” chat was paginated back to its beginning. Its relevant precedent is the LetBuyy T7 transfer: preserve unpublished work and local configuration, package external context and local data, checksum the media, test extraction, then independently verify runtime on the new Mac. The reported LetBuyy destination is `/Users/saai_mithra/Projects/LetBuyy-Workspace/LetBuyy`.

Agrimore is a separate Flutter/Firebase project, remote `SRIESWARAN01/Agrimore-Full-Project`. Do not apply LetBuyy's Supabase restore instructions, product roadmap, credentials or database assumptions. Keep its existing new-Mac installation and T7 backup untouched.

Proposed destination: `/Users/saai_mithra/Projects/Agrimore-Workspace/`. Confirm the actual home directory on the destination. One enclosing folder will contain the main checkout, all linked checkouts, recovery archives, evidence and context. One folder does not mean merging unfinished branches.

## Measured state — refresh at packaging time

Main checkout: `/Users/saai_siddharth/Projects/Clients/Agrimore`, detached HEAD `f84afbe0f3f07e25a645704e31f637e69dcb3b44`. Initial measurement: 29 modified tracked files and 443 untracked files, excluding ignored files. Approximately 20 GB on disk, including generated material. No stashes were listed.

| Checkout | Initial HEAD prefix | Tracked changes | Untracked files |
|---|---|---:|---:|
| Agrimore | f84afbe0 | 29 | 443 |
| ~/.codex/worktrees/delivery-visual/Agrimore | 2a0f8d19 | 0 | 0 |
| Agrimore-admr91 | 7f65ec58 | 6 | 3 |
| Agrimore-dlvc1 | e1d68352 | 2 | 1 |
| Agrimore-dlvc2 | e6a63b61 | 2 | 1 |
| Agrimore-dlvc3 | 817fdd4d | 2 | 1 |
| Agrimore-dlvc4 | 3538a57a | 6 | 3 |
| Agrimore-dlvc5 | 5061d3a1 | 4 | 2 |
| Agrimore-dlvhome1 | ddad6399 | 2 | 1 |
| Agrimore-dlvmap3 (develop) | 143376d0 | 6 | 3 |
| Agrimore-sredesign | 1e247b6d | 0 | 53 |

These measurements are not a frozen snapshot. Develop changed from `506769a6` to `143376d0` during inspection. Other sessions are changing state. Older repository instructions saying there is only one worktree on develop are contradicted by current Git registration. Do not reset or consolidate to match those notes.

## 1. Establish a stable capture boundary

- Let all Agrimore coding sessions finish their current operation and save/checkpoint unfinished work. Coordinate with their owners; do not terminate unrelated processes or send other chats instructions without authorization.
- Inventory running editors, agents, watchers, emulators and any local-data writers. Stop only appropriately authorized, identified Agrimore writers when necessary.
- Refresh every worktree's HEAD, branch/detached state, index, staged and unstaged binary diffs, untracked and ignored-file inventories, branch/tag refs, stashes, reflogs, submodules, Git LFS, alternate object directories and symlink targets.
- Capture all existing state without requiring a commit, merge, push, stash or clean operation. Archive the complete main `.git`, including per-worktree administrative directories and indexes. A Git bundle is useful secondary recovery, not a replacement for worktree contents or detached/reflog-only history.
- Record every scope item as INCLUDED, REGENERABLE, NOT_PRESENT or BLOCKED, with a reason. Unknown must not silently mean excluded.

## 2. Capture the full project and external work

Default to full archives of all 11 checkout directories, including hidden, ignored and untracked files. Inventory permissions, symlinks and executable bits. Preserve original archives before adjusting anything for the destination. If caches are later excluded for space, list each exclusion explicitly and prove it contains no unique data.

Required contents:

- Five apps: marketplace, seller, admin, delivery, employee; all three shared packages; functions; rules, indexes, hosting configuration and scripts.
- Main and branch-specific work: seller profile/icon implementation and tests; seller redesign assets; delivery mockups/design references; admin finance/release work; delivery history, document review, lifecycle/notifications, support, iOS readiness, home and map work. Names indicate scope, not completion. Read each checkout's own ledger/evidence when making the handoff.
- All docs, evidence, design files, image prompts, app_icons, APKs, bundles and release outputs, even if ignored.
- `.env`, `_env`, `functions/.env`, `functions/.secret.local`, per-app env files, Firebase JSON/plist files, key.properties, keystores and the existing secret/signing backup zip. Inspect and verify by paths and checksums without displaying secret values.
- Android `upload-key.jks`, key.properties and google-services.json were found for all five apps. Preserve any additional keys found in other checkouts. Separately inventory iOS certificates/private keys/profiles and Apple account requirements; filesystem copying does not prove Keychain signing identity transfer.
- Entire `~/.agrimore` (about 14 MB): programme states, status, checklists, logs and evidence. Observed programmes include admin, category, delivery UI, auth, next, home and delivery redesign. Keep automated continuation disabled until restored state is reconciled.
- Agrimore-specific Claude project histories, memories and attachments, including pre-flattening names under `~/.claude/projects/` (roughly 1.2 GB total). Exclude the unrelated Agrimore-Supabase product. Discover any histories keyed to individual worktree paths too.
- Inventory Agrimore-specific Codex chat records, attachments, archived worktree snapshots and generated artifacts outside the checkouts. Preserve accessible records as recovery material and create a readable handoff. Do not assume copying hidden app state makes chats resumable; do not overwrite the new Mac's global Codex or Claude state.
- Search known project, backup and attachment locations for Agrimore recovery material; record missing or inaccessible items. Historical clone folders may be preserved separately after identification; they must not replace the active project.

## 3. Local data and toolchain

Inventory actual Firebase emulator exports, fixtures, uploaded files and local databases/volumes. For every store record ownership, location, export method and restore test status. If no persistent local data exists, explicitly record NOT_PRESENT after inspection. Export mutable owned stores using their supported method after a consistent checkpoint; a copied running database directory is not sufficient proof of recovery.

Agrimore's hosted Firebase data remains hosted. This machine migration does not deploy, delete, migrate or overwrite production data. Do not start an app with production writes merely to test the new machine. Hosted backups are a separate scope.

Capture measured Flutter/Dart, Node/npm, Firebase CLI, JDK, Android SDK, Xcode/CocoaPods, Melos and shell versions and relevant configuration paths. Functions declares Node 22. Old documentation's installed-version list is historical; measure the working environment. Preserve lockfiles. Reinstall/regenerate dependencies on the new Mac and repair local absolute SDK paths there, keeping the archive unchanged. Reauthenticate accounts instead of blindly replacing Keychains or global credential stores.

## 4. Assemble one transfer directory

Proposed T7 folder: `Agrimore-Mac-Transfer-2026-09-28/` (choose a new unique suffix if it already exists).

Contents: README_FIRST.md, README_TRANSFER.md, RESTORE_MAC.sh, Archives/, Verification/, LocalData/, Context/, Toolchain/, SHA256SUMS.

The restore script is a future deliverable, not created or tested by this plan. It must validate checksums before extraction; refuse an existing/nonempty destination; check capacity; handle paths containing spaces; reject unsafe archive paths; preserve metadata; never run dependencies, database imports, agents, pushes or deployments automatically.

Suggested restored layout:

    Agrimore-Workspace/
      Agrimore/
      Worktrees/<original-unique-checkout-name>/
      Recovery/ExternalState/
      LocalData/
      Verification/
      Context/
      README_TRANSFER.md

After all checkouts and the main `.git` have been restored, repair Git's linked-worktree paths on the restored copy only, using the installed Git's supported worktree repair mechanism. Validate each checkout resolves to the new main Git directory, with its original HEAD, index and dirty state. Do not prune worktrees, merge branches or discard detached HEADs during restoration. Test this relocation in a disposable directory before shipping the package.

The package contains credentials and signing material. Keep it private, prefer an encrypted transfer container if supported, and document how to unlock it on the new Mac. Do not upload it to GitHub. Never reformat or erase the T7 to accomplish this transfer.

## 5. Verification gates — before calling the transfer ready

1. Stable source: before/after inventories agree for every checkout and external state captured. If any source changed, repeat the affected capture after quiescence; do not certify a mixed snapshot.
2. Preservation: manifests cover tracked, untracked AND ignored unique files; regular-file SHA-256, symlink targets and relevant modes compare successfully with a test extraction.
3. Git recovery: refs, detached HEADs, indexes, staged/unstaged diffs, worktree registrations, stash/reflog evidence and object integrity validate. Git fsck alone does not prove WIP preservation.
4. Media copy: verify every packaged file's SHA-256 from the T7 after copying. Retain archive and file counts plus exact verification logs. Record final package size and capacity checks.
5. Local data: record which exports were merely readable and which were actually restored into isolated local services. Never claim a database restore succeeded based only on extraction.
6. New-Mac runtime: independently verify toolchains, all five apps' analysis/build readiness, functions build, relevant existing tests, safe emulator smoke checks and signing availability. Record baseline issues separately from migration failures. Avoid accidental live payment, OTP or production data writes.
7. Context: readable handoff lists every workstream's actual path, SHA, status, unfinished task, evidence and next action. Planned, implemented, tested, merged and deployed are separate statuses. Include this plan and a final restore report.

## Completion and next action

Current verdict: inventory partially verified; package NOT_BUILT; T7 copy NOT_STARTED; test restore NOT_RUN; runtime NOT_TESTED. Deployment consequence: NONE. No production-readiness claim.

Next bounded operation: reconnect T7, coordinate a stable checkpoint for active Agrimore writers, complete external/local-data inventory, then build and test the preservation package. Leave all original folders, the existing LetBuyy package and both old-Mac/new-Mac work intact until independent restore and runtime verification pass. Do not promise “nothing missing” before the scope ledger and verification gates close.

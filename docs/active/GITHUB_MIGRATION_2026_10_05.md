# GitHub history migration — 2026-10-05

Owner requested all existing history preserved under one identity and a new private repository.

- New repository: https://github.com/SaaiSiddhu/Agrimore (private; publication verified).
- All 2,613 original commits retained individually; no squash. Authors and committers normalized to `SaaiSiddhu <saaisiddu@gmail.com>`.
- Removed co-author trailers from 203 commits; zero original signature headers were present.
- Every original file tree, timestamp/timezone and merge relationship preserved. Commit messages preserved except co-author lines.
- Original tip `0cf5f9f53f31f2759ed34938a7d80db18efd839b` maps to `9169570b4102c8d5437d4fe732fb9395b41b9f8b`. Complete mapping: [GIT_COMMIT_MAP_2026_10_05.json](GIT_COMMIT_MAP_2026_10_05.json). Historical evidence documents retain their original IDs; use this mapping for lookup in the new repository.
- Original self-contained bare backup: `.git/identity-rewrite-backups/2026-10-05-original.git`. Immutable object files are hard-linked, so the backup retains them independently without another gigabyte copy. Backup has its own refs and no alternates dependency. No original GitHub repository history changed.
- Working checkout remained unchanged and clean at rewrite completion. Source guards/operating instructions now reflect the new owner identity/remote in this separate follow-up commit.
- Prepublication bounded pattern scan inspected 6,955 historical text blobs, no private-key/GitHub-token/AWS-key patterns found; not exhaustive secret or APK-content certification. Historical files are intentionally retained, including build artifacts below GitHub's 100MiB hard per-blob limit. Ignored local credentials/build caches are not added.
- Develop remains the latest integrated source branch. Staging/main preserve their previous points in the rewritten graph; no release promotion. No Firebase deployment, production mutation, provider transaction or device run. Full F0–F9 acceptance remains open.

## Publication verification

Initial atomic push accepted all three branches. GitHub GraphQL verified private `SaaiSiddhu/Agrimore`, default branch `develop`, 2,614 commits at initial publication, and branch tips matching local source: develop `158f421176b1900be1ddcea90bf2b48299b97630`; main/staging `8860393f4c7ed0158c88006ea005bb3722967106`.

GitHub API verified requested author and committer email/name and linked both to account SaaiSiddhu. Historical APK-size warnings were advisory; the remote accepted the preserved objects. Temporary ENOSPC affected only local tracking updates after remote acceptance; repaired by scoped fetch/upstream configuration after space returned. No history was removed to accommodate upload.

The subsequent documentation commit adds the comprehensive five-app README and corrects the Melos repository URL. README verification resolved all 109 local links/images and independently checked 1,113 tracked asset files/506 design-board PNGs; branch-ledger validation passed. Application behavior is unchanged; no new runtime or full-suite acceptance claim. Additional documentation commits are expected beyond the 2,613 preserved originals.

# GitHub history migration — 2026-10-05

Owner requested all existing history preserved under one identity and a new private repository.

- New repository: https://github.com/SaaiSiddhu/Agrimore (private; publication verification pending).
- All2,613 original commits retained individually; no squash. Authors and committers normalized to `SaaiSiddhu <saaisiddu@gmail.com>`.
- Removed co-author trailers from203 commits; zero original signature headers were present.
- Every original file tree, timestamp/timezone and merge relationship preserved. Commit messages preserved except co-author lines.
- Original tip `0cf5f9f53f31f2759ed34938a7d80db18efd839b` maps to `9169570b4102c8d5437d4fe732fb9395b41b9f8b`. Complete mapping: [GIT_COMMIT_MAP_2026_10_05.json](GIT_COMMIT_MAP_2026_10_05.json). Historical evidence documents retain their original IDs; use this mapping for lookup in the new repository.
- Original self-contained bare backup: `.git/identity-rewrite-backups/2026-10-05-original.git`. Immutable object files are hard-linked, so the backup retains them independently without another gigabyte copy. Backup has its own refs and no alternates dependency. No original GitHub repository history changed.
- Working checkout remained unchanged and clean at rewrite completion. Source guards/operating instructions now reflect the new owner identity/remote in this separate follow-up commit.
- Prepublication bounded pattern scan inspected6,955 historical text blobs, no private-key/GitHub-token/AWS-key patterns found; not exhaustive secret or APK-content certification. Historical files are intentionally retained, including build artifacts below GitHub's100MiB hard per-blob limit. Ignored local credentials/build caches are not added.
- Develop remains the latest integrated source branch. Staging/main preserve their previous points in the rewritten graph; no release promotion. No Firebase deployment, production mutation, provider transaction or device run. Full F0–F9 acceptance remains open.

Publication result and default-branch/ref checks recorded after push.

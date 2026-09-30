# Agrimore consolidation — 2026-09-30

Owner request: consolidate every local branch and worktree into the primary folder, retain only main, staging and develop, preserve the latest work, and clean redundant worktrees.

This consolidation is in progress. Initial inventory: 29 local branches, four registered worktrees. develop started at 0e5e6ec49322c7d966f14d0c9deeaee1bfce61b5. main and staging started at 34da213a and remain release references; this request does not deploy or push anything.

Recovery material is private Git metadata at `.git/consolidation-2026-09-30/`: a verified all-ref Git bundle, binary patches, SHA-256 manifests and verified archives of modified, untracked and non-cache ignored files from every worktree. Secrets remain excluded from commits. Reproducible dependency and build caches are excluded from archives.

Scope: integrate primary-folder seller artwork and profile UI changes, iOS CocoaPods files, untracked design/research/evidence, and the remaining delivery status-lock branch. Then verify the combined tree, remove redundant worktrees, delete merged topic branches and record final results here.

Production consequence: the delivery status lock changes Firestore rules. Its release gate requires adoption of the callable-based delivery client before deploying those rules. No production adoption is inferred from local tests.

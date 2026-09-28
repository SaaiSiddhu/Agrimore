# Finance Reconciliation + Support Case System — Release Manifest

Delivered by ADMR-91 (2026-09-28), per the sixth fresh owner prompt's own section 14 ("deliver the
release manifest ... no deploy/push/migrate/external messages, no blanket deployments"). This
document is the deliverable itself — no `firebase deploy` was run by this or any prior session in
this milestone. The owner runs the commands below, in the order given.

## Scope boundary

This manifest covers **one milestone**: the People-360 / support-case / finance-reconciliation work
built across **ADMR-56 through ADMR-91** (customer/seller/rider/associate 360 screens, the support
case backend and UI, and the finance reconciliation investigation workspace). It does **not**
re-audit the project's older, pre-existing deploy debt (phases before ADMR-56) — `firebase
functions:list` shows 77 functions live today against a much larger implemented surface going back
to the project's start; a full historical audit is a separate, larger undertaking this phase did not
attempt, named here so it is not mistaken for "everything is now accounted for."

All findings below were measured fresh on 2026-09-28 with read-only commands
(`firebase functions:list`, `firebase firestore:indexes`, both `--project agrimore-66a4e`), not
carried forward from an older memory or ledger snapshot, several of which turned out to be stale by
the time they were re-checked (77 live functions today, not the 48 an earlier measurement recorded;
58 live indexes today, not 38).

## Executive summary

- **The entire support-case backend has never been deployed.** All 11 of its callables are absent
  from a live `functions:list` pull. The admin app's support-case queue, case detail screen, linking,
  evidence upload/view, and every finance-finding "Raise a case" action call functions that do not
  exist in production today — they will fail, not silently degrade.
- **The finance-reconciliation backend has never been deployed** (`financeReconciliationScan`,
  `financeReconciliationRecheckFinding` — both absent from live `functions:list`).
- **A genuine, previously undisclosed bug was found and fixed by this same phase**: 3 of
  `financeReconciliationScan`'s own 4 real query paths (`rider_payouts` paid, `employee_payouts`
  paid, and `seller_withdrawals`'s own paid group) have **no supporting Firestore composite index
  anywhere** — not in `firestore.indexes.json`, therefore not live either. Deployed as-is, the
  function would fail outright (`FAILED_PRECONDITION: The query requires an index`) for those three
  paths the first time an admin ran a scan against real data. This was never caught by ADMR-80
  through 90's own extensive real-emulator test suites because the Firestore emulator does not
  enforce composite-index requirements the way production Firestore does — see "How this was found"
  below. **Fixed in this phase**: `firestore.indexes.json` gained the 3 missing entries.
- Two **already-live** functions had their **behavior** changed across this milestone and need a
  redeploy-by-name, not a new deploy: `markSellerWithdrawalPaid`, `requestEmployeePayout`.
- `firestore.rules` (2,656 lines) and `storage.rules` (408 lines) have grown substantially since the
  last confirmed-deployed snapshot referenced in this repo's own skill documentation (1,457 lines,
  2026-08-31) — the `support_cases` and `addresses` rule blocks this milestone depends on exist in
  source but their live-deployed state could not be confirmed with a read-only tool the way functions
  and indexes could (Firebase's CLI has no read-only "diff my local rules against live" command).
  **Treat rules as pending until the owner confirms otherwise** — see the explicit note under
  "Rules" below.

### How this was found (indexes)

`firebase firestore:indexes --project agrimore-66a4e` was pulled and diffed programmatically against
the local `firestore.indexes.json`. The first diff attempt reported nearly every local entry as
"missing live" — a false alarm: Firestore's live representation appends an implicit trailing
`__name__` tie-break field to every composite index, which the local file (correctly) omits, so a
naive field-for-field comparison mismatches everywhere. Corrected to ignore that implicit field, the
diff dropped to 14 genuinely-missing entries, 7 of which are this milestone's own `support_cases`-
family indexes and 7 of which belong to an unrelated, concurrent delivery-redesign workstream (not
touched here). Cross-referencing `boundedByStatus()`'s own 4 call sites in
`functions/src/admin/financeReconciliation.ts` against that corrected list surfaced the missing
`seller_withdrawals`/`rider_payouts`/`employee_payouts` `[status, paidAt]` indexes specifically.

## Functions to deploy

All commands take `--project agrimore-66a4e`. Deploy in the order listed — earlier rows have no
dependency on later ones, but a function calling into a collection whose index isn't live yet will
fail at query time until the matching `firestore:indexes` deploy (below) has also landed; run the
indexes deploy first or in the same release window.

| # | Function | Kind | Built/changed in | Purpose | Command |
|---|---|---|---|---|---|
| 1 | `createSupportCase` | new | ADMR-61 | Open a support case for an actor | `firebase deploy --only functions:createSupportCase --project agrimore-66a4e` |
| 2 | `assignSupportCase` | new | ADMR-61 | Assign a case to a staff member | `firebase deploy --only functions:assignSupportCase --project agrimore-66a4e` |
| 3 | `changeSupportCaseStatus` | new | ADMR-61 | Move a case between open/in_progress/waiting | `firebase deploy --only functions:changeSupportCaseStatus --project agrimore-66a4e` |
| 4 | `addSupportCaseNote` | new | ADMR-61 | Add a note to a case | `firebase deploy --only functions:addSupportCaseNote --project agrimore-66a4e` |
| 5 | `resolveSupportCase` | new | ADMR-61 | The only path to `status: resolved` | `firebase deploy --only functions:resolveSupportCase --project agrimore-66a4e` |
| 6 | `reopenSupportCase` | new | ADMR-61 | Reopen a resolved case | `firebase deploy --only functions:reopenSupportCase --project agrimore-66a4e` |
| 7 | `linkSupportCaseRecord` | new | ADMR-65, extended ADMR-85 | Link a case to a real record (order/actor/rider-ops/financial) | `firebase deploy --only functions:linkSupportCaseRecord --project agrimore-66a4e` |
| 8 | `unlinkSupportCaseRecord` | new | ADMR-65 | Remove a link | `firebase deploy --only functions:unlinkSupportCaseRecord --project agrimore-66a4e` |
| 9 | `createSupportCaseFromSource` | new | ADMR-65 | Create a case from a rider-ops ticket/incident/exception | `firebase deploy --only functions:createSupportCaseFromSource --project agrimore-66a4e` |
| 10 | `attachSupportCaseEvidence` | new | ADMR-71 (implied by evidence tab) | Upload evidence to a case | `firebase deploy --only functions:attachSupportCaseEvidence --project agrimore-66a4e` |
| 11 | `viewSupportCaseEvidence` | new | ADMR-76 | Authenticated, revocation-checked, generation-verified evidence read (replaces a Storage-token bypass ADMR-76 itself found and closed) | `firebase deploy --only functions:viewSupportCaseEvidence --project agrimore-66a4e` |
| 12 | `financeReconciliationScan` | new | ADMR-80, response shape changed ADMR-82/85/88 | The bounded, paginated, confirmed finance-finding scan | `firebase deploy --only functions:financeReconciliationScan --project agrimore-66a4e` |
| 13 | `financeReconciliationRecheckFinding` | new | ADMR-85 | Recheck one finding on demand | `firebase deploy --only functions:financeReconciliationRecheckFinding --project agrimore-66a4e` |
| 14 | `markSellerWithdrawalPaid` | **already live** — behavior changed | ADMR-77 (frozen-destination payment), ADMR-84 (server-side legacy refusal) | Redeploy to pick up both fixes; a legacy-unresolved withdrawal can no longer be marked paid via a direct call, not just a disabled UI button | `firebase deploy --only functions:markSellerWithdrawalPaid --project agrimore-66a4e` |
| 15 | `requestEmployeePayout` | **already live** — internal-only change | ADMR-79 (destination read moved inside its own transaction) | No observable behavior change for any non-racing call; redeploy is precautionary, matching this codebase's own transaction-consistency convention | `firebase deploy --only functions:requestEmployeePayout --project agrimore-66a4e` |

All 15 can be deployed together: `firebase deploy --only functions:createSupportCase,functions:assignSupportCase,functions:changeSupportCaseStatus,functions:addSupportCaseNote,functions:resolveSupportCase,functions:reopenSupportCase,functions:linkSupportCaseRecord,functions:unlinkSupportCaseRecord,functions:createSupportCaseFromSource,functions:attachSupportCaseEvidence,functions:viewSupportCaseEvidence,functions:financeReconciliationScan,functions:financeReconciliationRecheckFinding,functions:markSellerWithdrawalPaid,functions:requestEmployeePayout --project agrimore-66a4e`

**Never** `firebase deploy --only functions` with no explicit names — this project has 6 live functions
with no source anywhere in this tree (per this repo's own standing operating rules); a bare
`--only functions` offers to delete them.

## Indexes to deploy

```bash
firebase deploy --only firestore:indexes --project agrimore-66a4e
```

This single command applies every entry in `firestore.indexes.json`, including the 7 pre-existing
`support_cases`-family entries (ADMR-61/62/71) already in the file and the 3 this phase adds
(`seller_withdrawals`/`rider_payouts`/`employee_payouts`, each `[status ASC, paidAt DESC]`) —
**required** before `financeReconciliationScan` can serve its `paid`-status queries against
`rider_payouts`/`employee_payouts`, and its `seller_withdrawals` paid group, in production. Also
carries forward every other pending index this milestone's earlier phases already disclosed (ADMR-60's
5, ADMR-63's 1) — this command is idempotent and safe to run even though it also re-applies indexes
that may already be live.

## Rules

```bash
firebase deploy --only firestore:rules --project agrimore-66a4e
```

Two blocks this milestone depends on: an `addresses` read rule (ADMR-56, `firestore.rules:1574` and
a nested `users/{uid}/addresses` block at `:246`) and a `support_cases` block (ADMR-61 onward,
`firestore.rules:2431`). Both exist in source. **Their live-deployed state was not directly
confirmed** — Firebase's CLI has no read-only command to diff local rules source against what is
actually live the way `firestore:indexes` does for indexes, and this phase did not attempt an
indirect proxy (e.g. a live permission probe) since that would itself be a write-adjacent action.
Given every one of this milestone's own new functions is confirmed absent from production, it is very
likely these rules blocks are equally undeployed, but treat this as reasoned, not verified — the
owner should confirm (or simply include `firestore:rules` in the same release window; a rules deploy
is idempotent and safe to run even if some blocks are already live).

## Admin app

No separate deploy step — the Flutter admin app (web/android/ios) ships in whatever build/release
process already exists for it; nothing in this milestone changes that process. The web build simply
needs to be rebuilt and redeployed to pick up ADMR-86/87/88/89/90's own Dart changes once the
functions/rules/indexes above are live (before that, its finance/support screens will show honest
error states — `MalformedScanResponseException`'s "couldn't reach the server" language, or a
functions-not-found error — rather than working, which is the correct, disclosed behavior of code
that calls an undeployed callable).

## Dependencies and order

1. **Indexes first** (`firestore:indexes`) — cheap, idempotent, and several functions above will
   throw on their very first real query without the matching index already live.
2. **Rules** (`firestore:rules`) — needed before any client (not just the admin app — a rider's own
   `rider_support_tickets` read, for instance) can read paths these blocks gate.
3. **Functions** (the 15 listed above, by explicit name) — safe once 1 and 2 are live; several of
   these functions read/write paths those rules blocks gate for non-Admin-SDK callers, though the
   Admin SDK itself bypasses rules, so strictly speaking the functions would still "work" for
   Admin-SDK-only access even if rules were deployed after — deploying rules first is about not
   leaving a same-day window where a legitimate rider/seller/customer client read fails.
4. **Admin app rebuild** — last, once the backend surface above is live, so the UI's own calls
   actually succeed instead of hitting an honest-but-avoidable error state.

## Legacy compatibility

- `financeReconciliationScan`'s response shape changed twice since ADMR-80 (ADMR-82: `scanned` →
  `coverage` plus `incomplete`/`incompleteReasons`; ADMR-85: added `id`/`confirmation`/`nextCursor`/
  `hasMore`; ADMR-88: cursor shape redesigned to a tagged union) — every one of these is a
  pre-deployment change to a function that has **never been live**, so there is no real client in the
  field depending on an older shape. No migration, no dual-write, no version negotiation needed.
- `markSellerWithdrawalPaid`'s ADMR-84 refusal (a legacy-unresolved withdrawal can no longer be paid)
  is a genuine behavior change to an **already-live** function. If any currently-open (requested,
  unpaid) legacy withdrawal exists in the real production database, it will become honestly
  unresolvable in-app after this deploy — this was flagged as `UNKNOWN_LIVE_STATE` by ADMR-83 and is
  still unresolved; the owner may want to check for one before this specific redeploy, or decide on a
  separate manual exception process. Not decided or built by this session.

## Post-release verification checklist

- [ ] `firebase functions:list --project agrimore-66a4e` shows all 15 functions above as live.
- [ ] A real admin sign-in reaches Finance Reconciliation and a scan returns (not an honest error).
- [ ] A scan against `rider_payouts`/`employee_payouts` with real `paid` records does not throw
      `FAILED_PRECONDITION` (the specific bug this phase fixed).
- [ ] A support case can be created, linked to a financial record, and the link is visible from both
      the case screen and the financial record's own linked-cases list.
- [ ] Evidence upload/view round-trips for a real case.
- [ ] `apps/marketplace`/`apps/seller`/`apps/delivery`/`apps/employee` are unaffected — none of this
      milestone's own functions are called by those apps.

## Out of scope, named rather than silently omitted

- The project's pre-ADMR-56 deploy debt (older undeployed functions/rules/indexes) — a separate audit.
- The 7 delivery-redesign-workstream indexes this phase's own diff also surfaced
  (`rider_cash_ledger`, `orders[deliveryPartnerId]`, `rider_earnings`, `rider_support_tickets`,
  `rider_incidents`, `delivery_exceptions`, `commission_exceptions`) — a different, concurrent
  session's own work; not this milestone's to manifest.
- A byte-level `firestore.rules`/`storage.rules` live-vs-local diff — no read-only tool exists for
  this; only functions and indexes could be verified this precisely.

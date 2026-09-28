# Finance investigation acceptance matrix (I01–I18)

Covers the "complete financial investigation" milestone built across ADMR-85 (backend: typed
contracts, complete parent+child confirmation, cursor continuation, `financeReconciliationRecheckFinding`,
the three financial `LINK_RECORD_TYPES`), ADMR-86 (UI: navigation from a finding to its exact
record, actor, a Recheck action, and a linked support case), and ADMR-87 (the emulator-mode fix
that made a real, live browser verification of the whole thing possible). Workflow under test:
bounded scan → confirmed finding → exact financial record → actor/order context → recheck →
linked support case → return to scan → continue older records.

Each row is falsifiable and mapped to a real command, file or a live browser session, not asserted
from memory. `PASS` means the cited evidence exists and was reproduced in this session; nothing here
is marked `PASS` without a command or a real click actually having been run.

**Scope note:** this matrix covers the I-series (investigation workflow) only. Earlier phases in this
programme (ADMR-77 through 84) were tracked under their own F-series/S-series criteria in
`docs/active/BRANCH_DISPOSITIONS.md` and this repo's run-state; consolidating those into one single
F/S/H/E/R/I table is not done in this pass — see "Not done" at the end.

| # | Criterion | Evidence | Verdict |
|---|---|---|---|
| I01 | A finding with a navigable target opens the exact financial record screen, not a list. | `financeFindingNavigationTarget` unit tests (`apps/admin/test/finance_finding_navigation_test.dart`), all 5 seller withdrawal-level kinds + rider/employee `paid_missing_reference`. **Live**: tapping the seeded `bc-withdrawal-1` finding in a real browser session opened the real record screen. | PASS |
| I02 | The record screen shows the record's real amount, status, reference and (for a withdrawal) masked destination. | `financial_record_detail_screen_test.dart` widget test. **Live**: the record screen rendered `₹250.00`, `paid`, `record id: bc-withdrawal-1`, `actor id: bc-seller-1`, and the real `legacyUnresolved` destination text/warning from `resolveSellerWithdrawalDestination` (ADMR-83's own logic, reused unmodified). | PASS |
| I03 | A withdrawal's constituent payout rows render, chunked past Firestore's 30-item `whereIn` cap. | Widget test with 2 rows. **Live**: the seeded withdrawal's single payout row (`₹250.00 · paid · id bc-payout-1`) rendered under "Constituent payout rows (1)". | PASS |
| I04 | "Open <actor>" navigates to the already-existing, unmodified actor 360 screen (seller/rider/associate). | `linkRecordRoute` reuse + widget-test button-label assertions. **Live**: tapping "Open seller" opened the real, unmodified `SellerDetailScreen` showing "Browser Check Farms" (the seeded seller). | PASS |
| I05 | `malformed_amount` / `payout_ownership_mismatch` findings navigate to the PARENT withdrawal, not the orphaned child id. | `finance_finding_navigation_test.dart`: exhaustive unit coverage including the no-withdrawalId-in-detail case asserting `null` rather than a guess. | PASS |
| I06 | Recheck re-derives the finding fresh, live, on demand and reports `confirmed` / `resolved` / `not_found`. | `phaseADMR80_finance_reconciliation_test.js` r18/r19 (real Firestore emulator). **Live**: tapping "Recheck" on the seeded finding called the real `financeReconciliationRecheckFinding` callable and rendered "Still confirmed — this finding reproduces right now." | PASS |
| I07 | Recheck is offered only when the screen was opened from a specific finding. | `financial_record_detail_screen_test.dart` widget test, both states. | PASS |
| I08 | "Raise a case about this" creates a real support case with the record pre-linked via `initialLink`. | `createSupportCaseCore` read directly: `initialLink` validates through the same `parseLinkedRecord`/`LINK_COLLECTION` ADMR-85 extended. **Live**: filled the dialog, tapped Create, got a real success snackbar ("Case created and linked to this record") from a real `createSupportCase` call. | PASS |
| I09 | The three new financial `LINK_RECORD_TYPES` validate through the SAME constrained path every existing type uses. | `phaseADMR65_support_case_links_test.js` f09/f10 (real Firestore emulator, 19/19 total). **Live**: the created case's own Linked Records tab, on the pre-existing, UNMODIFIED `support_case_detail_screen.dart`, rendered "Seller withdrawal · bc-withdrawal-1" with a working View link — proving the new type integrates with existing UI it was never specifically built for. | PASS |
| I10 | Every finding carries an honest `confirmation` state (`confirmed` / `unconfirmed`), never silently omitted. | `phaseADMR80_finance_reconciliation_test.js` r14b. | PASS |
| I11 | "Load older records" pages via a real cursor, appending, with a stable `documentId` tiebreak. | `phaseADMR80_finance_reconciliation_test.js` r16/r17. Not exercised live this phase — would need 200+ seeded withdrawals to trigger `hasMore`, disclosed rather than faked. | PASS (emulator suite); not separately re-proven live |
| I12 | A budget-starved confirmation reports `unconfirmed`, never silently drops or falsely claims `confirmed`. | `phaseADMR80_finance_reconciliation_test.js` r15. | PASS |
| I13 | The investigation surface remains read-only end to end. | Source review: zero `.set(`/`.update(`/`.delete(` against the four payout collections anywhere in the two touched screens. | PASS |
| I14 | A missing/vanished record shows an honest not-found state, not a crash. | `financial_record_detail_screen_test.dart` + `tester.takeException()` asserted `isNull`. | PASS |
| I15 | Rider and associate payout records render correctly using their OWN field names and amount units. | `financial_record_detail_screen_test.dart`: rider `50.00` from paise, employee `300.00` direct (no /100) — a real bug class this test would catch. | PASS |
| I16 | The linked-support-cases section shows an honest empty state when nothing is linked, AND a real positive match once one is. | Widget test covers the empty state (disclosed limit: `fake_cloud_firestore`'s `arrayContains` can't honestly prove a Map-value match). **Live**: after raising a case, it appeared correctly in the record screen's own "Linked support cases" section — proving the real backend's `arrayContains` match (unlike the fake) works exactly as intended. | PASS — fully proven live, closing the one gap the widget-test layer could not |
| I17 | ADMR-84's server-side legacy-destination-refusal enforcement is unaffected by this milestone. | `phaseADMR84_server_legacy_destination_refusal_test.js` re-run unmodified against both merge commits, 8/8 both times. | PASS |
| I18 | The complete scan → finding → record → actor → recheck → raise-a-case → back-to-scan journey completes via real UI interaction in a live browser session. | **Live, this session**: a scoped Firestore+Auth+Functions+Storage emulator with a real seeded admin account (email+password, real Auth-emulator sign-in) and a genuine `paid_missing_reference` finding; the admin app built and served in `--release` web mode against it; driven via real clicks and typing in the Browser pane through the ENTIRE journey — sign in → Finance Reconciliation (real scan, real coverage line) → tap the finding → exact record screen (real destination-resolution text) → Recheck (real callable, "Still confirmed") → Open seller (real actor screen) → back → Raise a case (real `createSupportCase` call, real success) → the new case appears in the record's own linked-cases list → opening it shows the real, pre-existing Support Case screen with the financial link correctly rendered on its Linked Records tab. Found and fixed one real, previously-undiscovered infrastructure bug along the way (see ADMR-87's own ledger entry): App Check's placeholder web reCAPTCHA key broke email/password sign-in against the Auth emulator for every prior phase in this saga, which is exactly why no earlier phase's disclosed "no live browser check" limitation was ever closed — it could not have been, until this fix. | PASS |

## Not done in this pass

- Consolidating this I-series with the historical F-series/S-series/H-series/E-series/R-series
  criteria from ADMR-77 through 84 into one single table — those live in
  `docs/active/BRANCH_DISPOSITIONS.md`'s own per-phase evidence; a faithful consolidation needs
  reading that ledger's full history fresh, not reconstructing it from a compacted summary.
- The release manifest as its own artifact.
- Remaining domain register continuation (catalog/inventory, category images, banners, media
  integrity, settings consumers, reporting/export, jobs/exceptions, audit/security visibility).
- Responsive/platform acceptance for the two touched screens (phone/tablet/desktop breakpoints) —
  the live session ran at a single mobile-width viewport only.
- I11's cursor-continuation was not separately re-proven live (needs 200+ seeded records to trigger
  `hasMore`); the real-emulator Node suite (r16/r17) is the evidence for that one.

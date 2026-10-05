# Agrimore — C11 codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-03.** [Ten-image gallery](SELECTION_CONTROLS_FILTER_STATE_BOARDS_2026-10-03.md) · [C01 approval](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Coverage and limits

Inventory HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: **817 source files / 271,604 lines**. All eligible Dart text in five app lib trees and agrimore_ui/core/services plus TypeScript functions/src was scanned for selection/filter/picker markers. Generated .g/.freezed files, firebase_options and credential/secret-named files excluded. Representative domain selection flows and control primitives read contextually. This is a broad static inventory plus focused review, not exhaustive semantic review of every line or a rendered audit of every screen.

Marker totals include comments and construction text; they are not unique screen or defect counts. Backend inventory supplies domain context; it does not imply backend owns control layout. Concurrent implementation proceeds independently; observations are a timestamped source snapshot, not deployed guarantees.

| Scope | Switch | Checkbox | Radio | ChoiceChip | FilterChip | Custom chip | Dropdown | Picker | Filter apply | Selected |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| admin | 16 | 5 | 3 | 21 | 1 | 0 | 26 | 4 | 0 | 33 |
| delivery | 2 | 0 | 4 | 1 | 0 | 8 | 3 | 1 | 4 | 9 |
| employee | 2 | 0 | 0 | 3 | 0 | 0 | 0 | 0 | 0 | 3 |
| marketplace | 3 | 3 | 4 | 3 | 0 | 0 | 1 | 2 | 12 | 5 |
| seller | 1 | 0 | 0 | 0 | 0 | 24 | 1 | 3 | 0 | 33 |
| functions | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_core | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_services | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| agrimore_ui | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Existing shared control infrastructure

The workspace Material theme defines selected switch track/thumb, checkbox fill/check and radio fill through state properties; its presence does not prove adoption by every app. DialogHelper.showChoice already presents a single-choice RadioListTile group. Seller and Delivery additionally have app-specific chip/segment components, and Sales Associate uses its shared theme tokens with screen-local Material choices. These are reuse candidates, not a reason to introduce five parallel generic widgets in this asset task.

Verified shared source anchors:

- [Workspace Material selection theme](../../packages/agrimore_ui/lib/workspace/ws_theme.dart)
- [Shared choice dialog](../../packages/agrimore_ui/lib/widgets/dialog_helper.dart)

## Shared target selection contract

1. State cardinality explicitly: switch = Boolean preference/availability, checkbox = independent choice, radio/choice chip = one option in a group, toggle chip = independent choice, picker = a value or bounded range. Never silently change a domain group from one to many.
2. Show persistent labels and selected/checked/toggled semantics. Use a dot for radios, check for selected checkbox/toggle chip, dash for a derived mixed parent and explicit On/Off wording when needed. Selection is not success, delivery confirmation, approval or payment settlement.
3. Separate draft controls from committed state. Stage a copy of current filters for a modal; Apply commits, Cancel/dismiss discards. Immediate inline filters do not need a fictional Apply. Reopen from current applied values. Each workflow must define close/back/scrim behavior.
4. Reset is not automatically draft-only: Marketplace shop and Delivery history currently clear applied filters immediately, while search Clear All only clears the local draft. Retain and clearly label immediate reset, or migrate deliberately with tests. Clearing draft controls never implies a query changed.
5. Applied chips mirror canonical query state; removing one changes the committed filter consistently. Defaults/all options have unambiguous behavior. Canonical filter keys, category IDs, sorting, date range/timezone bounds and back/deep-link restoration require a deliberate domain model, not cosmetic equivalence.
6. Parent mixed states derive from explicit scope: none/some/all visible eligible rows. No hidden-page or all-query selection by implication. Track stable IDs, define what happens on filtering/pagination/account/permission changes and separate selecting from the eventual bulk mutation. Do not claim a new select-visible parent is already implemented.
7. Picker labels, search, selected option and cancellation are explicit. Preserve current value on cancel; handle loading, empty, unavailable and stale options safely. Never switch to another ID just because the selected option disappears. Custom ranges need valid bounds and an adjacent explanation for unavailable Apply.
8. Control focus must be visible independently of selected state. Keyboard/assistive semantics identify role, group, selected state and unavailable reason. A row click is one activation, not double toggling; nested clear/remove targets have distinct labels and focus stops. Text wraps and touch regions target at least 48px.
9. Asynchronous settings distinguish requested change from confirmed state. Prevent conflicting toggles while pending, announce progress without fake success, and recover/roll back on failure according to existing domain behavior. Filtering is a query, not a server mutation or permission grant.
10. Do not invent query result counts. Distinguish loading, no results and failure; preserve the applied filter during reload/retry. Reconcile stale query responses. Counts shown on selection controls must reflect their documented scope and actual data.
11. Keep all five C01 identities and role-correct inverse text in dark mode; primary/selected colors indicate choices, while warning/error/success remain semantic statuses. Extend the existing Seller/Delivery controls, associate theme and shared Material/theme infrastructure before building equivalent primitives.

## Agrimore Marketplace

**Current source:** SearchFilters clones current filter state, stages multi-category/price/rating edits and applies on confirmation; Clear All there resets the draft. Shop FilterDrawer instead applies Reset immediately and closes. SortBottomSheet immediately chooses one option and closes. Category controls are custom gesture containers; hardcoded white search-filter surfaces remain.

**Target:** Keep category multi-select separate from single-choice sort; use explicit selected indicators, accessible control roles, staged Apply/Cancel and clearly named immediate Reset where retained. Applied filter chips mirror committed query state.

**Character:** Professional-green shopping filters with warm-gold guidance, spacious category choices and removable applied chips.

| Panel | Domain specimen |
| --- | --- |
| Switches and checkboxes | In-stock only switch OFF with visible Off text, helper Filter choice applies on Apply. Category checkbox examples Seeds checked and Fertilizers unchecked, label Choose any; category labels illustrative, not live inventory. Small state strip Checked / Unchecked / Mixed / Disabled (Load options first). Mixed has a dash, not a check. |
| Single and multiple choice | Sort radio group: Newest first selected, Price: low to high unselected. Separate multi-select chips Seeds selected with check and Fertilizers unselected. Only one sort, any categories. Selected is a choice, not success. |
| Category picker | Standalone compact picker surface titled Choose categories, search field Search categories, checkbox rows Seeds checked, Fertilizers unchecked; Done action. No sidebar. No prices, fake category counts or real records. |
| Draft and applied filters | Draft filters badge; Apply filters primary, Cancel secondary, Clear draft text action. Diagram Edit draft → Apply → Applied chips. Applied chip Seeds ×; removing it changes applied state. Small annotation Existing shop Reset clears immediately; label this clearly. No result count. |

Gaps/preservation:

- Search and shop reset semantics differ; standardize deliberately or label them clearly, not silently.
- The two flows use different price filter keys/shapes (minPrice/maxPrice versus priceRange); a canonical filter model is a future implementation decision.
- Do not invent query result counts or treat rating/sort choice as a success status.

Verified source anchors:

- [search_filters.dart](../../apps/marketplace/lib/screens/user/home/search/widgets/search_filters.dart)
- [filter_drawer.dart](../../apps/marketplace/lib/screens/user/shop/widgets/filter_drawer.dart)
- [sort_bottom_sheet.dart](../../apps/marketplace/lib/screens/user/shop/widgets/sort_bottom_sheet.dart)
- [category_selection_utils.dart](../../packages/agrimore_core/lib/utils/category_selection_utils.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| auth | 9 |
| business | 3 |
| chat | 11 |
| employee | 7 |
| landing | 1 |
| legal | 2 |
| not_found_screen.dart | 1 |
| onboarding | 1 |
| seller | 1 |
| splash | 1 |
| user/cart | 9 |
| user/categories | 2 |
| user/checkout | 7 |
| user/flash_sale | 1 |
| user/help | 1 |
| user/home | 27 |
| user/main_screen.dart | 1 |
| user/notifications | 1 |
| user/offers | 1 |
| user/orders | 15 |
| user/profile | 9 |
| user/rewards | 1 |
| user/rfq | 3 |
| user/search | 3 |
| user/settings | 1 |
| user/shop | 20 |
| user/subscriptions | 2 |
| user/wallet | 9 |
| user/wishlist | 5 |

## Agrimore Seller

**Current source:** SellerChip distinguishes filled single-choice tabs from checked independent toggles, includes selected semantics and 48dp outer hit area. SellerSwitchRow provides toggled semantics and shared focus tracking. StoreStatusSheet stages accepting-orders and pause duration, returning a new value only on Save/Pause; schedule screens open date/time pickers.

**Target:** Reuse the seller controls, keep staged store availability distinct from immediate filter chips, make mixed/disabled checkbox atoms consistent, and keep picker cancellation and commit explicit.

**Character:** Compact blue-teal operational controls with copper section guidance and clear store-status commitments.

| Panel | Domain specimen |
| --- | --- |
| Store switch and checkbox states | Accepting orders switch ON and helper Draft setting — Save to commit. Checkbox atom strip marked Pattern reference: Checked, Unchecked, Mixed with dash, Disabled with helper Unavailable. No claim of bulk-product feature. |
| Single and independent choices | Order-stage chips All selected, New unselected, Delivered unselected; one active stage. Separate independent toggle chip B2B with check, no fabricated counts. Radio atom group Pause duration: 1 day selected, 3 days unselected; these are separate pattern specimens. |
| Schedule picker | Field Schedule date, empty hint Choose a date, calendar icon; compact popup picker-style surface with Choose date heading and Cancel / Done. No invented selected dates or opening times. Caption Cancel keeps the saved value. |
| Stage before committing | Store-status draft panel Accepting orders ON. Primary Save, secondary Cancel. Diagram Open saved state → Edit draft → Save. Separate small filter note Order-stage chips apply immediately. Explicit no immediate store pause on draft change. |

Gaps/preservation:

- Chip remove controls need a separately reachable labeled target; outer excludeSemantics and constrained remove size need runtime review.
- Preserve staged store status: toggling the draft switch does not immediately pause the server.
- Generic checkbox atoms are pattern proposals, not a new bulk-product feature. Preserve finite single-choice groups.

Verified source anchors:

- [seller_chips.dart](../../apps/seller/lib/design_system/components/seller_chips.dart)
- [seller_fields.dart](../../apps/seller/lib/design_system/components/seller_fields.dart)
- [store_status.dart](../../apps/seller/lib/screens/account/store_status.dart)
- [store_schedule.dart](../../apps/seller/lib/screens/account/store_schedule.dart)
- [seller_orders_screen.dart](../../apps/seller/lib/screens/orders/seller_orders_screen.dart)
- [seller_order_provider.dart](../../apps/seller/lib/providers/seller_order_provider.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| account | 8 |
| ai | 1 |
| auth | 6 |
| home | 4 |
| insights | 3 |
| notifications | 2 |
| onboarding | 10 |
| orders | 6 |
| payments | 3 |
| posts | 2 |
| products | 6 |
| profile | 5 |
| reviews | 2 |
| rfq | 7 |
| search | 2 |
| shell | 1 |
| storefront | 2 |

## Agrimore Delivery

**Current source:** Delivery history sheet stages date range and one status; Apply commits, dismissal discards draft, Reset clears committed filters immediately and closes. Custom dates use a date-range picker and block Apply until chosen. Availability pill exposes Online/Offline and a busy spinner. DeliveryChipRow uses filled brand choices; custom interactive chips need selected semantic verification.

**Target:** Keep status mutually exclusive, dates staged, and Reset explicitly immediate. Make selection visible by symbol/border as well as color and preserve an announced availability busy state distinct from filter selection.

**Character:** Monochrome field controls, burgundy selected-container cues and burnt-orange focus with a compact history sheet.

| Panel | Domain specimen |
| --- | --- |
| Availability and checkbox atoms | Offline availability switch OFF with clear Offline text; alternate busy specimen Changing availability… static progress glyph and inert switch. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled. Do not introduce multi-status selection. |
| History selection | Radio status group All statuses selected; Delivered, Cancelled, Returned unselected, exactly one. Separate single-choice date chips This week selected, Last week unselected, Custom unselected. Selected fills black in light or white in dark, foreground inverse; burgundy secondary container accents, orange focus only. |
| Custom date picker | Custom range field empty Choose dates, calendar icon. Picker surface Select date range with Start date and End date empty fields and Cancel / Done. Disabled Apply filters with adjacent Choose start and end dates. No fabricated date values. |
| Apply, cancel and reset | Draft history filters panel. Primary Apply filters; secondary Cancel; explicit Reset now action. Diagram Draft → Apply → Applied filters. Text Cancel discards draft. Reset now clears applied filters and closes. No fake result count, no delivery success check. |

Gaps/preservation:

- Reset is an immediate committed clear; do not depict it as Clear draft.
- Do not invent live result-count badges; source intentionally uses Apply filters without a count.
- Checkbox atom examples are reference patterns, not multi-status history filters. The status group stays one choice.
- Custom control selection/keyboard focus and unavailable helper copy need runtime verification.
- DeliveryChipRow and DeliverySegmented pass button/label semantics to DeliveryInteractive, whose current wrapper has no selected parameter. Add explicit selected/group semantics as a future control extension; this asset task does not change runtime accessibility.

Verified source anchors:

- [history_filter_sheet.dart](../../apps/delivery/lib/screens/history/history_filter_sheet.dart)
- [rider_history.dart](../../apps/delivery/lib/data/rider_history.dart)
- [delivery_chips.dart](../../apps/delivery/lib/design_system/components/delivery_chips.dart)
- [home_app_bar.dart](../../apps/delivery/lib/screens/home/home_app_bar.dart)
- [delivery_states.dart](../../apps/delivery/lib/design_system/components/delivery_states.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| auth | 3 |
| history | 2 |
| home | 6 |
| inbox | 1 |
| money | 3 |
| offers | 1 |
| orders | 4 |
| profile | 3 |
| settings | 1 |
| support | 5 |

## Agrimore Sales Associate

**Current source:** Orders, wallet and payout history use single-choice ChoiceChip enums updated immediately. Payout account method uses a custom two-way Bank account/UPI gesture segment; choice changes form mode without saving destination. Profile Dark Mode switch changes theme immediately. Focused flow has no multi-order selection or filter date-range picker.

**Target:** Make one-choice groups explicit with selected symbols and semantics; distinguish selecting a payout method from saving/approving it. Include checkbox and picker atoms as future reference patterns without implying new operational features.

**Character:** Premium royal-blue relationship and payout filters, indigo guidance and restrained pearl/slate control surfaces.

| Panel | Domain specimen |
| --- | --- |
| Preference and checkbox states | Dark mode switch uses current board theme (OFF in LIGHT, ON in DARK), helper Applies immediately. Checkbox strip explicitly Pattern reference: Checked / Unchecked / Mixed dash / Disabled with Unavailable helper. No new bulk-order functionality. |
| One choice per group | Order-mode chips All orders selected, B2B orders unselected, Retail orders unselected. Separate payout status radio group Requested selected, Paid / Settled unselected. Each group is independent and single choice; selection is filtering, not payout approval. |
| Method and picker patterns | Payout method segment Bank account selected, UPI unselected. Helper Method choice edits the form; Save commits. Small date picker field labelled Date picker · pattern reference with empty Choose a date, Cancel / Done. No account IDs, dates, numeric amounts or invented date-filter feature. |
| Immediate filters, draft method | Two clean mini-flows: Order chip → Filter list immediately; Method choice → Edit form → Save. Text Choosing a method does not approve an account. Neutral empty-state example No orders match this filter with Clear filter action. No fabricated records or counts. |

Gaps/preservation:

- Do not turn Requested/Paid/Settled choices into payout actions or guarantees.
- Payout method segment is a form draft choice, not a saved destination or approved account.
- Generic checkbox/date picker specimens are target patterns only; source does not establish bulk-order selection or a payout date filter.

Verified source anchors:

- [orders_screen.dart](../../apps/employee/lib/screens/orders/orders_screen.dart)
- [wallet_screen.dart](../../apps/employee/lib/screens/wallet/wallet_screen.dart)
- [payout_history_screen.dart](../../apps/employee/lib/screens/wallet/payout_history_screen.dart)
- [payout_account_screen.dart](../../apps/employee/lib/screens/wallet/payout_account_screen.dart)
- [profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [sales_associate_tokens.dart](../../packages/agrimore_ui/lib/themes/sales_associate_tokens.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| auth | 5 |
| home | 1 |
| notifications | 1 |
| orders | 2 |
| profile | 2 |
| shell | 1 |
| support | 1 |
| wallet | 6 |

## Agrimore Admin

**Current source:** User management tracks selected IDs with per-row Checkbox and single-choice filter chips; bulk status/delete loops operate on that set. Product form category dropdowns and badge switches are editor inputs. Payout/review queues use choice chips. No select-visible mixed parent was observed in user management.

**Target:** Keep query filters, row selection and editor draft choices separate. A proposed select-visible parent reflects none/some/all visible eligible rows, with readable scope and no assumption that hidden pages are selected.

**Character:** Professional-blue dense review controls with cyan grouping, explicit row selection scope and mixed parent checkboxes.

| Panel | Domain specimen |
| --- | --- |
| Visible-row selection | Proposed pattern: Select visible checkbox MIXED dash; two synthetic rows Record A checked, Record B unchecked. Caption Only visible eligible rows. Separate switch Product active ON, helper Editor draft — Save to commit. Do not show fake bulk actions or user data. |
| Exclusive filters and radios | User-filter chips All selected, Active unselected, Inactive unselected. Separate radio group Payout status: Pending / Requested selected, Paid unselected, Rejected unselected. One choice per group; not a mutation. |
| Structured category picker | Product category field Choose a category; open compact picker with Search categories and radio options Category A selected, Category B unselected. Synthetic labels. Caption Stable option IDs; preserve current value on cancel. No sidebar. |
| Filter scope and selection | Diagram Filter visible records → Review selected rows → Explicit action. Callout Mixed means some visible rows selected. Text Changing filters must reconcile selection. Clear selection text action. Separate editor Save / Cancel action specimens. No success message, permissions claims or real record counts. |

Gaps/preservation:

- Mixed/select-visible parent is a target extension, not current user-management behavior.
- Reconcile selected IDs when filters/pages/permissions change; define retain/clear policy explicitly before bulk actions.
- Selection does not perform bulk mutation; confirmations, permissions and partial failure results need separate implementation review.
- Picker options require stable IDs and unavailable-value handling; do not silently select another category.

Verified source anchors:

- [user_management_screen.dart](../../apps/admin/lib/screens/admin/users/user_management_screen.dart)
- [product_form.dart](../../apps/admin/lib/screens/admin/products/widgets/product_form.dart)
- [employee_payouts_screen.dart](../../apps/admin/lib/screens/admin/employees/employee_payouts_screen.dart)
- [delivery_info_form.dart](../../apps/admin/lib/screens/admin/products/widgets/delivery_info_form.dart)

Scanned screen families (file counts, not unique screens):

| Family | Dart files |
| --- | --- |
| admin | 98 |
| auth | 1 |

## Future implementation verification

- Verify checked, unchecked, mixed, unavailable, hovered/pressed, focused and pending states in light/dark, narrow phone and applicable desktop layouts, 100–200% text scaling and screen-reader/keyboard traversal.
- Check cardinality: choosing one radio/choice chip replaces the previous choice; independent checkboxes can be combined; all/default state is well-defined. Mixed derives from visible eligible rows and cannot falsely imply selection across hidden pages.
- Stage, Apply, Cancel, back, scrim dismissal, reopening and reset in every domain. Search Clear All differs from shop/Delivery immediate Reset until deliberately standardized. Inline order/payout filters remain immediate.
- Picker cancellation, stale/loading/no options, long labels, category stable IDs and custom date bounds. Delivery history uses IST week boundaries and inclusive UI end dates mapped to exclusive query end; do not replace this with device-zone defaults.
- Applied-chip removal, filter persistence/deep links where supported, pagination/query reloads, no results, offline/error and stale responses. No fake result-count badges.
- Bulk scope reconciles with visible/eligible row changes; selection itself does not invoke mutations. Bulk action permissions, confirmation and partial failures are separate future implementation work.
- Seller store availability remains staged; Delivery availability distinguishes pending from confirmed; associate payout method selection does not save or approve the destination.
- Reuse existing equivalent controls before adding primitives. Pattern-reference checkbox/picker atoms do not authorize unrelated bulk or filtering features.

## Handoff scope

Ten PNGs, five per-app README/prompt/manifest sets and two master documents: 27 new repository files. Earlier C01–C10 design files preserved. Exact prompts, generation history and reference/source/output hashes retained. C11 remains provisional until owner approval. No Flutter build, emulator, runtime accessibility certification, selection/filter implementation migration, pubspec registration, branch, staging, commit, deploy or other-chat interruption.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

## Asset validation result

**PASS** at source HEAD 97f171f00f8330f1ae7c831845e4dd94a8ae2c33: 10 PNGs / 5 theme pairs, 27 new repository files, 18 exact generation/refinement prompt blocks and 86 local links checked. PNG signatures/dimensions, selected-output hashes, input-reference hashes, prompt hashes and C01 palette/status/spacing/radius/border metadata inheritance passed. All 621 earlier design files retained their pre-task hashes.

The final three generation outputs completed despite a turn interruption. Their saved files were recovered and visually inspected; prompt history was reconstructed from the exact tool calls in this chat and recovery provenance retained in manifests. No duplicate generation was needed for recovery. All ten selected boards were inspected for identity, selected-state symbols, group cardinality, draft/applied annotations and dark surfaces.

The 817-file runtime snapshot showed no byte changes between inventory, packaging and validation. This task wrote only the 27 declared design assets/documents; the independent implementation conversation was not messaged or interrupted. These checks establish asset integrity and documented token targets, not exact raster colors, functioning filter behavior, runtime accessibility or deployment. Future implementation checks above remain outstanding.

# Agrimore — C27 content vocabulary and localization: codebase and domain map

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · 2026-10-04.** C01 remains APPROVED_LOCKED. C27 owner approval is pending. Assets/docs only.

[Ten-board gallery](CONTENT_VOCABULARY_LOCALIZATION_BOARDS_2026-10-04.md) · [C01 approval index](COLOR_ROLES_THEME_IDENTITY_LOCK_2026-10-02.md).

## Fresh static coverage

Inventory HEAD: be6c1dae99497dd674fb2f484c2d7cc0cfa16d30. 815 eligible files / 253069 source lines across all five app lib trees, all three package lib trees and functions/src. Generated .g/.freezed files, generated app_localizations classes, firebase_options and credential/secret-named files are excluded. Generated locale declarations were separately read; 9 app pubspec/l10n/ARB resources were hashed separately. Focused semantic reads cover all five roots, Marketplace language/settings, Seller ARBs/product/auth copy, Delivery ARBs/device/auth/delivery-confirmation mapping, Associate auth-gate/notification/payout copy, Admin case/evidence and shared ErrorView/feedback defaults. This is a broad inventory plus targeted analysis, not a read of every line or rendered screen.

Marker totals include logs, comments and call sites; they are not translated-string coverage, user-visible-error leak counts or unique component counts. Transport-message references may be used only for logging/classification. Direct Text literal counts omit variables, custom controls and multiline constructions. Verified source examples below establish specific risks; absence of a marker is not proof of a fully localized app.

| Scope | localization_calls | literal_text_sites | transport_message_sites | display_labels | role_terms |
| --- | --- | --- | --- | --- | --- |
| admin | 0 | 1057 | 24 | 677 | 40 |
| delivery | 290 | 5 | 3 | 324 | 0 |
| employee | 0 | 158 | 1 | 141 | 25 |
| marketplace | 0 | 946 | 11 | 408 | 55 |
| seller | 1847 | 1 | 16 | 612 | 3 |
| functions | 0 | 0 | 17 | 113 | 57 |
| agrimore_core | 0 | 0 | 0 | 20 | 8 |
| agrimore_services | 0 | 9 | 15 | 5 | 0 |
| agrimore_ui | 1 | 5 | 0 | 20 | 19 |

## Localization source snapshot

| App | Catalog | Source locale | Message keys | Placeholder metadata | ICU plural messages | Generated supported locales |
| --- | --- | --- | --- | --- | --- | --- |
| seller | apps/seller/lib/l10n/app_en.arb | en | 1105 | 159 | 27 | en |
| delivery | apps/delivery/lib/l10n/app_en.arb | en | 925 | 80 | 7 | en |

Seller and Delivery each have one English ARB source, l10n.yaml, generate:true, generated AppLocalizations and root app/delegates/supportedLocales wiring. Generated supportedLocales lists English only. These are current infrastructure facts, not evidence of another delivered language or every visible string being extracted. No localization generator was run.

Marketplace lists English/Tamil in LanguageScreen but only local selected state changes and Apply Language pops the route. SettingsProvider stores a separate language string; the examined screen does not call changeLanguage and the root MaterialApp does not bind that preference to a Locale or localization delegates. Sales Associate and Admin roots likewise do not configure app localization delegates/supportedLocales. Admin declares easy_localization, but the scanned Admin lib tree contained no import/calls adopting it. A package dependency, a stored preference or a visible language option is not a working translated app.

The older feedback lane statement that the repository has zero ARB files is superseded by current Seller/Delivery source. Its safe-copy and role-term rules still inform this proposal. These assets do not amend lane files or add a new runtime framework.

## Shared content target contract

1. Use sentence case, direct domain words and action labels that explain what happens next. Product names, user content and technical identifiers are separate from translatable UI copy.
2. Each app owns its domain vocabulary/catalog. Shared generic controls can reuse reviewed generic messages without collapsing the five domain meanings into one catalog.
3. Safe display copy maps stable typed errors/reasons to reviewed messages. Raw exception messages, paths, codes, stack traces and sensitive details do not belong in user-facing copy.
4. Choose recovery by cause: read retry, sign-in, permission/access support and command reconciliation differ. Never blindly offer retry of a financial/delivery/approval mutation.
5. Translate whole messages using typed named placeholders and locale-appropriate plurals/selects; do not concatenate English fragments or expose untranslated placeholder braces.
6. Source catalog descriptions explain intent, state, action, placeholder type/unit/privacy and terminology. Generated localization classes are outputs, not the editorial source.
7. Only release a locale with reviewed coverage, matching placeholders, fallback behavior and actual app-root/delegate wiring. A selector or dependency does not establish translation support.
8. Expanded labels grow/wrap/stack and retain full meaning. Locale fonts/glyphs, directionality, semantics and formatting require rendered checks; these English boards are length examples only.
9. Proposed ownership is source author → app-domain reviewer → fluent language reviewer → UI/implementation reviewer. No actual assigned person, reviewed translation or approved release is claimed.
10. Status and success copy reflect confirmed business state. No benefit/payment/approval/delivery/support outcome or new financial terminology is invented by a design sample.
11. Separate behavioral codes/identifiers from localized text before migration. Do not translate strings currently used to drive routing or machine decisions.
12. C27 is assets/docs only. Preserve C01 identities, all earlier board sets, existing server/owner guards and other-chat changes; future localization implementation needs its own relevant tests.

## Five domain systems

### Agrimore Marketplace

**Current source:** Marketplace MaterialApp has no app localization delegates or supportedLocales wired. LanguageScreen starts with a local English selection, lists English/Tamil, changes only its local state and Apply Language pops the route. SettingsProvider separately persists a language string; this screen does not call it, and the root does not bind it to Locale. Existing product/order/settings copy is largely inline English. Shared ErrorView has a fixed English heading and retry label; its supplied message is not sanitized by the widget.

**Target:** Keep shopper-facing product, cart and order terms consistent; name the next action precisely. Extract complete sentences with context into a reviewed app catalog in later implementation, then connect supported locale selection to the root. A visible language choice must describe only genuinely available translations.

| Panel | Domain specimen |
| --- | --- |
| Customer vocabulary | Panel "Customer vocabulary": heading "Your orders"; neutral glossary rows "Product" / "What you browse", "Cart" / "Items before checkout", "Order" / "Your placed order". Primary "View order details". These are glossary definitions, not live cart/order outcomes. |
| Safe recovery copy | Panel "Safe recovery copy": example error notice with icon and "Could not load product details. Try again."; primary "Try again", secondary "Back". Gold note "Explain the next step without technical details"; caption "Example notice". No exception/code/path/permission message. |
| Longer label layout | Panel "Room for longer text": side-by-side labelled "Short label" and "Longer label example"; buttons "View details" and "View details for this product". Longer button wraps and grows vertically; full labels preserved, same primary roles. Gold note "Let translated labels wrap and grow". English length illustration, not a released translation. |
| Commerce translation review | Panel "Translation ownership": proposed review flow with readable four stacked rows "Source copy", "Commerce review", "Language review", "UI review". Small note "Keep product, cart and order meaning consistent"; clear caption "Proposed review flow" and "English source examples". No real person/approval/checkmark or new settings UI. |

Preserve or resolve:

- English/Tamil options do not prove Tamil product copy exists or a locale changes. Do not display an operational language picker in C27.
- Keep user-entered product titles distinct from translated interface labels; never automatically rewrite seller content.
- Translate whole messages with typed placeholders/plurals rather than joining English fragments.
- Checkout/payment/stock outcomes must remain tied to confirmed server state; read retry is not a command retry.

Sources:

- [apps/marketplace/lib/app/app.dart](../../apps/marketplace/lib/app/app.dart)
- [apps/marketplace/lib/screens/user/settings/language_screen.dart](../../apps/marketplace/lib/screens/user/settings/language_screen.dart)
- [apps/marketplace/lib/providers/settings_provider.dart](../../apps/marketplace/lib/providers/settings_provider.dart)
- [apps/marketplace/lib/widgets/product/unified_product_card.dart](../../apps/marketplace/lib/widgets/product/unified_product_card.dart)
- [packages/agrimore_ui/lib/widgets/common/error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)

### Agrimore Seller

**Current source:** Seller has l10n.yaml, one English ARB catalog and generated AppLocalizations wired into the root with Material/Widgets/Cupertino delegates. Product screens use localized catalogue, stock, option and safe-action messages; ARB has typed placeholders and ICU plurals. AuthErrorBanner maps typed errors but rate-limit/unavailable branches accept a provider string named serverMessage. The inspected provider supplies safe hardcoded English fallbacks, not verbatim transport text; localization coverage is therefore not complete.

**Target:** Keep product, option and stock wording precise for merchants; catalogue/source messages own merchant editing semantics. Preserve whole-message placeholders and plural context, replace remaining safe English fallbacks through reviewed keys later, and keep form labels visible with longer copy.

| Panel | Domain specimen |
| --- | --- |
| Merchant vocabulary | Panel "Merchant vocabulary": title "Product details"; form labels "Product name", "Product options", "Stock quantity" with neutral empty field specimens; primary "Review product details". Copper note "Keep options and stock quantity distinct". No product, quantity, availability or save outcome. |
| Safe editor copy | Panel "Safe recovery copy": icon plus "Could not load products. Try again."; primary "Try again", secondary "Back", caption "Example notice". Copper note "Say what failed and what to do next". Read-only retry sample; no save/publish/approve claim. |
| Merchant label expansion | Panel "Room for longer text": "Short label" / "Longer label example" with same-role actions "Review details" and "Review details for this product". Longer wraps and grows, no ellipsis or compressed font. Copper note "Keep the complete action label visible". English illustration, not translated language. |
| Merchant copy review | Panel "Translation ownership": four readable stacked stages "Source copy", "Merchant review", "Language review", "UI review"; note "Preserve option names, stock meaning and action intent"; caption "Proposed review flow", "English source examples". No technical keys inside product form; no reviewer approval claim. |

Preserve or resolve:

- Only English is generated and supported; ARB presence is infrastructure, not multilingual delivery or every-string adoption.
- Stock and product options are distinct; do not treat a missing stock quantity as a confirmed stock state.
- Do not hand-edit generated localization Dart; later changes belong in source ARBs/config plus generator output.
- Keep saved/published/approved labels separated and backed by actual outcomes; safe banner transport mapping remains required.

Sources:

- [apps/seller/lib/app/app.dart](../../apps/seller/lib/app/app.dart)
- [apps/seller/l10n.yaml](../../apps/seller/l10n.yaml)
- [apps/seller/lib/l10n/app_en.arb](../../apps/seller/lib/l10n/app_en.arb)
- [apps/seller/lib/screens/products/seller_products_screen.dart](../../apps/seller/lib/screens/products/seller_products_screen.dart)
- [apps/seller/lib/screens/products/widgets/product_variants_section.dart](../../apps/seller/lib/screens/products/widgets/product_variants_section.dart)
- [apps/seller/lib/screens/auth/widgets/auth_error_banner.dart](../../apps/seller/lib/screens/auth/widgets/auth_error_banner.dart)
- [apps/seller/lib/providers/seller_auth_provider.dart](../../apps/seller/lib/providers/seller_auth_provider.dart)

### Agrimore Delivery

**Current source:** Delivery has one English ARB catalog, generated supported English locale and delegates at the root. authProblemText maps RiderAuthProblem to localized sentences. confirmDelivery catches FirebaseFunctionsException, logs details, and uses a code/reason-specific copy mapper; catch-all returns deliverFailed. deviceLocalizations selects a supported device language or English for background/local notification strings. ARB placeholders/plurals exist; some server-authored notes/status fallbacks are passed through, requiring separate trust/context review.

**Target:** Use clear pickup, delivery and instruction terms; distinguish viewing directions from recording completion. Localize visible and background messages from the rider catalog; failure copy and available actions must reflect the real typed state, not a raw transport message or automatic replay of a delivery command.

| Panel | Domain specimen |
| --- | --- |
| Rider vocabulary | Panel "Rider vocabulary": title "Pickup instructions"; definition rows "Pickup" / "Collect from the store", "Delivery" / "Take to the customer". Primary "Review pickup instructions", secondary "Help". Orange note "Name the task before the action". Glossary only; no current task, address, dispatch or delivered state. |
| Safe route copy | Panel "Safe recovery copy": notice "Could not load route details. Try again." with icon; primary "Try again", secondary "Back"; caption "Example notice". Orange note "Describe the issue without claiming completion". No map API error, confirm-delivery retry, emergency command or server success. |
| Rider instruction expansion | Panel "Room for longer text": "Short label" / "Longer label example"; actions "Review pickup" and "Review the pickup instructions"; long action wraps/grows. Orange note "Keep field instructions readable in full". No clipped instruction, fixed-width language setting or translated support claim. |
| Rider copy ownership | Panel "Translation ownership": stages "Source copy", "Rider review", "Language review", "UI review"; burgundy note "Review task meaning and background notices"; caption "Proposed review flow", "English source examples". Do not insert actual push notification, sensitive content, emergency number or reviewer tick. |

Preserve or resolve:

- Device-language fallback does not provide a translation when only English is supported.
- Safety/emergency wording, delivery confirmation, lockout timings and photo-proof outcomes need separate domain review; no such outcome or safety guarantee is illustrated here.
- Background notices need their own locale and privacy review; foreground selection cannot be assumed to propagate into another isolate.
- User/store/customer content and server notes are not automatically translated UI strings; sanitize/review fallback display separately.

Sources:

- [apps/delivery/lib/app/app.dart](../../apps/delivery/lib/app/app.dart)
- [apps/delivery/l10n.yaml](../../apps/delivery/l10n.yaml)
- [apps/delivery/lib/l10n/app_en.arb](../../apps/delivery/lib/l10n/app_en.arb)
- [apps/delivery/lib/app/device_localizations.dart](../../apps/delivery/lib/app/device_localizations.dart)
- [apps/delivery/lib/auth/auth_copy.dart](../../apps/delivery/lib/auth/auth_copy.dart)
- [apps/delivery/lib/screens/orders/active_order_screen.dart](../../apps/delivery/lib/screens/orders/active_order_screen.dart)
- [apps/delivery/lib/delivery/rider_steps.dart](../../apps/delivery/lib/delivery/rider_steps.dart)

### Agrimore Sales Associate

**Current source:** Sales Associate root uses the correct role title but has no app localization delegates/catalog wired. Many labels and error strings remain inline English. NotificationsScreen renders interpolated exception text on mark-read failure. PayoutReviewScreen passes FirebaseFunctionsException.message or interpolates an arbitrary error into its visible error message. These are source-confirmed copy risks, not evidence of a production data incident. Auth gate currently matches pending/suspended substrings in provider error strings, so translating that routing value directly can change behavior.

**Target:** Use Sales Associate in visible role copy while preserving employee identifiers internally. Distinguish attributed orders, earned commissions and any separate Product Credit program without inventing financial terms. Future locale messages must be separated from typed access/error state; redact technical failure details and preserve exact business meaning.

| Panel | Domain specimen |
| --- | --- |
| Associate role language | Panel "Associate vocabulary": role heading "Sales Associate"; rows "Attributed orders" / "Orders linked to your work", "Order details" / "Information about an order". Primary "View order details". Indigo note "Keep the role and attribution meaning clear". No actual attributed record, commission, program fee, money or eligibility claim. |
| Safe associate copy | Panel "Safe recovery copy": icon and "Could not load order details. Try again."; primary "Try again", secondary "Back"; caption "Example notice". Indigo note "Use helpful copy; keep technical details out". No raw exception, payout action or confirmed result. |
| Associate action expansion | Panel "Room for longer text": "Short label" / "Longer label example"; actions "View orders" and "View orders attributed to your work". Longer wraps and grows, full wording readable. Indigo note "Preserve the meaning when labels grow". Source-English specimen, not language release. |
| Associate translation review | Panel "Translation ownership": four stages "Source copy", "Associate review", "Language review", "UI review"; note "Keep role, attribution and benefit terms distinct"; caption "Proposed review flow", "English source examples". No reviewer identity, approved benefit, enrollment promise or technical identifier. |

Preserve or resolve:

- Do not translate identifiers or strings used as behavioral state; first separate typed state from localized presentation.
- Product Credit, where supported, must keep its product-redemption meaning; it is not a generic cash wallet label.
- Do not reword policy-sensitive onboarding/benefit/payment language as ordinary localization; actual domain/owner review is needed before future runtime changes.
- A safe read error and retry sample does not authorize resubmitting a payout or imply money moved.

Sources:

- [apps/employee/lib/app/app.dart](../../apps/employee/lib/app/app.dart)
- [apps/employee/lib/providers/auth_provider.dart](../../apps/employee/lib/providers/auth_provider.dart)
- [apps/employee/lib/screens/profile/profile_screen.dart](../../apps/employee/lib/screens/profile/profile_screen.dart)
- [apps/employee/lib/screens/notifications/notifications_screen.dart](../../apps/employee/lib/screens/notifications/notifications_screen.dart)
- [apps/employee/lib/screens/wallet/payout_review_screen.dart](../../apps/employee/lib/screens/wallet/payout_review_screen.dart)
- [apps/employee/lib/screens/profile/onboarding_status_screen.dart](../../apps/employee/lib/screens/profile/onboarding_status_screen.dart)

### Agrimore Admin

**Current source:** Admin root has no app-localization delegates/support list wired. easy_localization is declared in pubspec but no import or calls were found in the scanned Admin lib tree. Support-case actions and evidence handling use inline English and can render FirebaseFunctionsException.message. Some dense review/detail screens display internal status strings or fallbacks. Shared feedback widgets accept caller messages and keep fixed English defaults; helper reuse alone does not enforce safe or translated copy.

**Target:** Use clear support-case, evidence and review terms with exact action intent. App catalog ownership should preserve administrative scope/status meaning and permission-specific recovery. Map stable codes to reviewed messages rather than directly rendering transport text, with domain-owned neutral fallback wording for unknown states.

| Panel | Domain specimen |
| --- | --- |
| Operations vocabulary | Panel "Operations vocabulary": title "Support cases"; glossary rows "Case" / "A support request", "Evidence" / "Files for case review", "Review" / "Examine the available context". Primary "Open case details". Cyan note "Use precise words for records and actions". No real case, status, private evidence or resolution. |
| Safe review copy | Panel "Safe recovery copy": notice "Could not load case details. Try again." with icon; primary "Try again", secondary "Back"; caption "Example notice". Cyan note "Give a relevant next step without raw errors". No permission/role claim, destructive retry, stack trace or case outcome. |
| Operations label expansion | Panel "Room for longer text": "Short label" / "Longer label example"; actions "Open case" and "Open the details for this support case". Longer label wraps and grows; no abbreviations or ellipsis. Cyan note "Keep the record context in the action". English illustration, no claimed additional locale. |
| Operations copy review | Panel "Translation ownership": four readable stages "Source copy", "Operations review", "Language review", "UI review"; note "Preserve status meaning and permission context"; caption "Proposed review flow", "English source examples". No named reviewers, assigned admin rights, approval ticks or production policy page. |

Preserve or resolve:

- A localization dependency alone is not app adoption or an approved set of translated languages.
- Keep access denied, missing data and transient read failure distinct; retry is not appropriate for every denial.
- Status mapping must preserve authoritative enum distinctions rather than prettifying several states into a misleading single label.
- Evidence/approval/refund/resolution wording and action outcomes remain server-authoritative; no successful operation or role assignment shown.

Sources:

- [apps/admin/lib/app/app.dart](../../apps/admin/lib/app/app.dart)
- [apps/admin/pubspec.yaml](../../apps/admin/pubspec.yaml)
- [apps/admin/lib/screens/admin/support/support_case_detail_screen.dart](../../apps/admin/lib/screens/admin/support/support_case_detail_screen.dart)
- [apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart](../../apps/admin/lib/screens/admin/sellers/seller_detail_screen.dart)
- [packages/agrimore_ui/lib/widgets/common/error_view.dart](../../packages/agrimore_ui/lib/widgets/common/error_view.dart)
- [packages/agrimore_ui/lib/widgets/snackbar_helper.dart](../../packages/agrimore_ui/lib/widgets/snackbar_helper.dart)

## Safe display copy and business state

| Source example | Observed behavior | Later target |
| --- | --- | --- |
| Shared ErrorView | Fixed English heading/retry label; caller-provided message displayed unchanged | Allow reviewed localized complete messages; helper reuse does not sanitize input |
| Seller AuthErrorBanner/provider | Typed network/generic mapping; rate-limit/unavailable takes serverMessage; inspected provider emits safe English fallback strings | Preserve safe mapping, move remaining fallbacks to reviewed catalog keys without forwarding raw transport messages |
| Delivery auth/confirmation | RiderAuthProblem and confirmation code/reason map to localized messages; detailed failures logged | Preserve precise reason mapping, supported recovery and server-confirmed completion boundaries |
| Associate notifications | Mark-read catch interpolates exception in visible snackbar | Replace with safe notification-update copy and cause-appropriate next action |
| Associate payout review | Visible error uses FirebaseFunctionsException.message or arbitrary exception interpolation | Use reviewed command-state-aware failure/reconciliation copy; do not offer a blind financial retry |
| Admin support/evidence | Some failure branches directly display FirebaseFunctionsException.message | Map stable error codes/reasons to reviewed safe messages; preserve access and upload outcome distinctions |

These are source-confirmed copy risks, not claims of production exposure, backend compromise or completed fixes. Logs and typed errors are distinct from visible UI messages. Diagnostic logging should avoid secret/private values and follow existing data boundaries; these boards do not rewrite logging policy.

Sales Associate _AuthGate currently matches pending/suspended substrings of provider errors. The localized message cannot safely become that routing state. A later migration should first separate typed access state from display text, preserving owner/session guards and approval behavior. No auth or routing code was changed here. User-facing role remains Sales Associate; internal employee IDs, APIs and model names remain machine identifiers.

Read failure, unavailable record, permission denial, signed-out state and failed/ambiguous command are different. Offer read retry only when relevant; respect authorization/account changes. A copy change must not turn an uncertain payment, delivery, approval, upload or support outcome into a confirmed result. C27 notices are isolated read-error examples and glossary definitions, not real records.

Keep program-specific Product Credit meaning distinct from cash wallets/commissions where it is supported. Do not introduce investment/guaranteed-benefit vocabulary. Existing policy-sensitive onboarding, payment steering, fees, redemption terms, safety/emergency instructions and official legal copy need their own domain/owner review in future implementation. No fee/financial/program/legal/emergency wording or outcome is illustrated or changed by this task.

## Whole messages, placeholders and locale behavior

Catalog descriptions should explain domain, intent, current state, available action, placeholder type/unit/privacy and whether content is UI or user/server-authored text. Typed placeholders allow a translator to reorder a complete sentence; plural/select handling belongs to the locale, not English fragment concatenation. Seller already has option/order/review and validation plurals; Delivery has delivery/item/validation/lockout plurals. Their existence does not verify all count forms in another locale.

Examples inspected: Seller editorOptionsCount distinguishes zero/one/other options, dsFieldsNeedAttention uses a typed count; Delivery moneyDeliveries uses count, and dsFieldsNeedAttention uses a typed count. These are source examples only; the boards avoid live numeric records and untranslated placeholder braces. Never translate runtime IDs, enum storage values, URLs, support contacts or merchant/customer-entered content as if they were interface labels. Review server-authored notes/status fallbacks for trust, privacy and localization ownership separately.

Root delegates, supported locale lists, catalog resources and locale selection/fallback must agree. Delivery deviceLocalizations selects a supported device language or English for context-free background copy. With English-only support this does not produce an additional-language notification, and a future foreground preference is not automatically available to a separate isolate. No background-notification delivery or locale transition was tested.

The boards use English short/long labels as illustrative expansion specimens, not translated text or measured localization coverage. Growing buttons preserve full labels rather than shrinking, clipping or inventing abbreviations. Later actual locale rendering must inspect glyph/font fallback, script metrics, directional layout, semantics, interpolation and domain formatting, alongside C24 formatting/C26 accessibility guidance. C01 Inter metadata is retained; this is not a claim that Inter alone covers every future script.

## Proposed translation ownership

No named reviewer or organization assignment was supplied or verified. The following is a proposed responsibility model, not existing staffed ownership or completed review:

| Step | Responsibility | Evidence before release |
| --- | --- | --- |
| Source copy | App-domain source author | Complete message, glossary term, state/action and typed placeholders described |
| Domain review | Commerce / Merchant / Rider / Associate / Operations reviewer for the relevant app | Business meaning, safe recovery, privacy and policy-sensitive terms checked |
| Language review | Fluent target-language reviewer | Natural language, terminology, plural/select/context and placeholder order checked |
| UI review | Implementation/design reviewer | Root locale wiring, rendered expansion/fonts/direction, semantics and fallback tested |

Shared generic labels can have shared ownership, while domain messages remain separately owned. Repeated words do not require five arbitrary synonyms: role context and authoritative meaning determine reuse. Locale release requires catalog completeness/review and actual runtime adoption; no additional locale or human approval is represented by the proposed review panels.

## Primary guidance

Flutter documents ARB sources, generated localization classes, root delegates, supported locale lists and placeholders/plurals/selects as separate parts of localization. Source messages and their generated accessors must remain coordinated with actual app locale behavior. [Flutter internationalization](https://docs.flutter.dev/ui/internationalization).

ICU message formatting supports complete messages with arguments and locale-dependent plural/select structures; fragment joining can lose grammar and context. [ICU formatting messages](https://unicode-org.github.io/icu/userguide/format_parse/messages/). These references guide future implementation; they do not verify Agrimore adoption.

## Verification boundaries and future checks

Existing source tests located for auth/copy interactions include:

- [apps/seller/test/auth/auth_screens_test.dart](../../apps/seller/test/auth/auth_screens_test.dart)
- [apps/delivery/test/auth_session_test.dart](../../apps/delivery/test/auth_session_test.dart)
- [apps/employee/test/screens/auth_screens_test.dart](../../apps/employee/test/screens/auth_screens_test.dart)
- [apps/employee/test/foundation_auth_gate_test.dart](../../apps/employee/test/foundation_auth_gate_test.dart)
- [apps/admin/test/foundation_admin_auth_actions_test.dart](../../apps/admin/test/foundation_admin_auth_actions_test.dart)

No test above was run, and they are not asserted to cover translation releases. Later relevant verification should include:

- Parse source ARBs, check approved locale/key/placeholder parity and descriptions, generate localization outputs and verify roots/delegates/list/fallback together. Do not hand-edit generated classes.
- Render each adopted locale with expanded labels, narrow/wide widths, large text, script fonts/direction, complete messages and screen-reader names. English pseudo-expansion alone does not prove real-language support.
- Exercise each typed error/access/recovery cause with safe output; confirm raw exceptions/private fields do not enter visible notices, and known errors do not become misleading generic success.
- Preserve Associate typed access routing before translating its current state-bearing strings; keep server/owner/session checks unchanged by presentation migration.
- Verify supported locale changes persist and apply only where product behavior specifies them; unsupported preferences/fallback and context-free background copy need explicit tests.
- Review status vocabularies, plural/select categories, money/quantity/date formatting and policy-sensitive program/payment/safety/legal wording with their actual domain owners.

No Flutter generator/analyzer/runtime/emulator, translated-language review, production data query, screen-reader test or backend mutation was performed. Asset validation checks PNG/data/doc integrity and existing design preservation only.

## Scope and design review

27 new files: ten PNGs, five README/prompts/manifest sets and two master documents. C01–C26 and repeated C16 remain intact. Classifier: docs; voluntary UIUX/feedback review covers locked identity, sentence case, domain vocabulary, safe illustrative notices, translation honesty, readable label growth and no fabricated outcomes. Runtime ARB/generated classes, app wiring, pubspec and backend files were not edited by this task.

No branch/index/commit/deploy or other-chat interruption. Concurrent shared-checkout changes remain untouched. Deploy consequence: NONE.

Execution mode: SINGLE AGENT · Subagents invoked: NO · Agent/Task delegation: NO · Background agents: NO · Parallel worktree agents: NO · Workflow orchestration: NO.

Concurrent indexed source changes since inventory: packages/agrimore_services/lib/database/database_service.dart.

## Asset integrity check

First post-packaging snapshot: **PASS**. Ten 1536 × 1024 PNGs form five light/dark pairs. PNG chunk checksums, copied-output hashes, 10 exact prompt blocks, reference-input hashes, approved C01 token metadata, 2 catalog snapshots and 95 local document links verified. Exactly 27 new repository files; all 1053 earlier design files remained byte-for-byte intact.

All ten selected boards received visual review for five distinct identities, inverse dark primary content, domain wording, safe example notices, genuinely wrapped longer labels, English-source examples and clearly proposed translation-review ownership. No focused refinements were needed. All five dark boards reference their selected light compositions plus approved C01 dark identities. Glossaries describe concepts and notices are synthetic read-error examples, not actual records or mutation outcomes.

Snapshot HEAD: 64a71d4e6e6bff5ab04e9dcd38bc84d24f3b266a; inventory HEAD: be6c1dae99497dd674fb2f484c2d7cc0cfa16d30; branch: agrimore/foundation-f3c-distance-delivery-pricing. Source changes observed between inventory and packaging were preserved: packages/agrimore_services/lib/database/database_service.dart. Additional source changes observed during packaging/check were preserved: apps/marketplace/lib/screens/user/shop/widgets/add_review_dialog.dart. Platform configuration hashes matched the inventory. Separately hashed localization/config resources matched the inventory. This is a point-in-time observation; another chat may continue advancing the shared checkout.

Scope: design assets/docs only. Integrity checks and English raster review do not establish translated-language coverage, human translation approval, runtime locale switching, placeholder/grammar correctness in another language, font/direction rendering or backend safe-message adoption. No app runtime, ARB/generated localization class or backend was edited by this task. C27 remains PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION; C01 remains APPROVED_LOCKED.

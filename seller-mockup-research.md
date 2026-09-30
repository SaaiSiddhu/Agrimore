# AgriMore Seller — research and mockup brief

Research completed: 24 September 2026.

## Scope and evidence

This brief analyses the complete supplied seller-app inventory. It does not compare the proposed experience with the existing app, inspect its implementation, or benchmark competitors. The supplied text is the source for product capabilities and labels; its claims about code scans and localisation have not been independently verified. External research is limited to official accessibility and adaptive-layout guidance.

This is the research handoff before visual mockup production. No mockups or user testing are claimed complete.

### Inventory correction

The supplied total of 39 includes the storefront preview sheet. Counting shared Add/Edit product and restricted-account variants as single destinations, and counting the five onboarding steps separately, there are **38 full-screen destinations plus the preview sheet**. Variant frames, confirmation dialogs, pickers, and sheets add to the mockup workload. “About 16 sheets/dialogs” should not be used as a hard production limit.

## Product boundaries

- Five primary destinations: Home, Orders, Catalogue, Payments, Account. Quotes remain accessible through Home and Account.
- Phone navigation uses those five tabs; tablet navigation uses the same destinations in a side rail.
- Delivered orders generate automatic settlements. There is no wallet, withdrawal, request-payout flow, or seller payout approval flow.
- Payout details are entered during onboarding; subsequent changes go through support.
- Sellers advance orders through acceptance, packing, and readiness for pickup. The inventory does not authorise seller controls for dispatch or delivery completion.
- B2B offers can be negotiated, accepted, declined, expire, and lead to orders. Acceptance and order placement are separate states.
- AI has distinct activation, payment-received, connected, and verification-problem states. Preserve the supplied ₹50 activation amount as a product requirement, not as independently verified pricing.
- English is the supplied content scope. Do not invent a language switcher. Leave room for longer translated copy in the layouts.
- The supplied document reports Tamil Nadu-only district data. Do not imply nationwide district coverage in sample controls.
- Terms, privacy, seller policies, tax explanations, and support contacts need supplied content; do not invent legal wording, contact details, settlement deadlines, or tax rules.

## Seller needs and information hierarchy

These are design hypotheses inferred from the inventory, not findings from seller interviews.

1. Know what needs action: unaccepted orders, packing, expiring offers, and stock shortages.
2. Complete the next operational action with little navigation.
3. Keep product availability and prices accurate, including packs and wholesale quantities.
4. Understand what will be paid, what was paid, and deductions per order.
5. Maintain store availability, reputation, and business settings.

Home should put the action queue above reporting. Order detail should keep the current stage and permitted next action obvious. Payments should clearly distinguish pending money from money already received. Destructive actions need explicit labels and enough context to understand the consequence.

## Complete screen coverage

All controls and source wording remain governed by the attachment. This matrix defines the hierarchy and variants needed for mockup production, not a replacement transcription of every label.

| ID | Destination | Mockup composition and required variants |
|---|---|---|
| A01 | Splash | Brand, loading status; do not fabricate progress percentages. |
| A02 | Mobile sign-in | Headline, +91 phone field, Get OTP, Google, email link, terms/privacy; invalid number, sending, Google mobile-link banner. |
| A03 | OTP | Masked destination and Change, six digits, verify action, resend countdown and call alternative; incorrect code and verifying. Debug ribbon only on an explicitly marked test variant. |
| A04 | Email sign-in | Email, password visibility, reset link, sign-in, mobile tip; validation and submitting. |
| A05 | Application under review | Submission timeline, Check status, support, sign out; refreshing and unchanged result. |
| A06 | Account restricted | Separate not-approved and suspended frames; Fix and resubmit only where specified. |
| B01 | Start selling | What is needed, saved-progress promise from source, Start application, support. |
| B02 | Business details | Step 1 of 5, identity/business fields, category, optional GSTIN, persistent progression controls. |
| B03 | Location and delivery | Address, city/PIN/state, location action and radius; location permission denied and manual entry retained. |
| B04 | Documents | Required ID and shop/farm uploads, optional GST certificate; initial, uploading, uploaded, failed, replace. |
| B05 | Payout account | Bank and UPI alternatives; masked account, repeated account, mismatch feedback. |
| B06 | Review and submit | Four summaries with Edit, agreement checkbox, final submit; unchecked and submitting. |
| C01 | Home | Greeting/actions, conditional availability banners, Needs you now, performance, health/insights, amount pending, quick actions; busy and caught-up variants. |
| C02 | Notifications | Filters, grouped rows, unread emphasis, per-item/all read; empty and filtered empty. |
| C03 | Search | Focused query field, two-character guidance, grouped results, exact-order shortcut; initial, mixed results, no match. |
| C04 | Insights | Period selection, sales comparison, B2B contribution, stages, best sellers; meaningful chart axes and no-data frame. |
| C05 | Account health | Score/band, time window, five metric cards with targets/tips; good, attention, and risk bands. |
| D01 | Orders | Search, stage counts, period/B2B filters, cards; active filters, no orders, no matches, 99+ tab badge. |
| D02 | Order detail | Stage/total, customer and fulfilment, items, payment breakdown, invoice and sticky action; new, accepted, packing, ready, out for delivery, delivered, cancelled. |
| D03 | Invoice | Document hierarchy, number/copy, seller/buyer, items, totals; Tax Invoice and Bill of Supply variants. |
| E01 | Catalogue | Search/filter/sort, product cards, visibility and stock actions, Add product; active, draft, low/out of stock, inactive, multiselect. |
| E02 | Add/Edit product | Shared editor with all source sections; add versus edit stats, options, coverage choices, mapped prices, B2B off/on, draft/save validation. |
| E03 | New post | Composer, photo, optional product tag, Post; text only, attached image, tagged product, posting. |
| F01 | Payments | To be paid, 30-day/all-time paid, masked account, monthly statements, settlements; no account, no settlements, mixed paid/pending. |
| F02 | Settlement detail | Delivery/payment timeline, order value minus commission equals receipt, payment reference; pending and paid. |
| F03 | Monthly statement | Month and copy action, aggregate breakdown, paid/pending, order rows; populated and no activity where applicable. |
| G01 | Quotes | Four status tabs/counts, buyer/product, offer and expiry; actionable, waiting, accepted, closed. |
| G02 | Quote detail | Product/wholesale context, current offer, status, negotiation history, permitted actions; seller turn, buyer turn, accepted, order placed, declined, expired. |
| H01 | Account | Shop summary/stats, Business, Selling & money, AI, App groups, sign out; taking orders and paused. |
| H02 | Weekly off & holidays | Weekday chips, date list/add/remove, buyer-visibility explanation, Save. |
| H03 | Storefront editor | Cover/logo, shop name/about, up to three highlights, preview and save; missing images and maximum highlights. |
| H04 | Reviews | Average/distribution, filters, verified review cards and replies; unanswered, answered, no reviews. |
| H05 | Followers & posts | Follower count/change, own posts, delete and compose; no posts. |
| H06 | AI assistant | Disconnected prompt or connected conversation, suggestions and composer; sending and failure proposals clearly marked. |
| H07 | Connect AI | Not activated with website explanation, paid/provider/key entry, connected/disconnect, verification problem/reference/retry. |
| H08 | Notification settings | Six category switches, quiet hours and time controls; quiet hours off/on. Save mechanism is unspecified. |
| H09 | Help & support | Search, six expandable FAQs, contact card; expanded answer and no search match. |
| H10 | Settings | System/light/dark, notifications/help/licences, version; selected theme. |

## Overlay and auxiliary-surface register

Explicitly account for these surfaces; shared layouts can have multiple content variants.

| ID | Surface | Required treatment |
|---|---|---|
| O01 | Password reset | Destination email, send, cancel, success/failure feedback. |
| O02 | Sign-out confirmation | Shared by account and approval/restriction paths. |
| O03 | Reject/cancel order | Two title/action variants, required reason, optional note, prepaid consequence, keep-order escape. |
| O04 | Update stock | Units field, validation, Save. |
| O05 | Delete product | Product context, destructive confirmation, Cancel. |
| O06 | Product option | Name, price, stock, Save. |
| O07 | Accept quote | Quantity, unit price, computed total, Accept/Cancel. |
| O08 | Counter-offer | Price, quantity/minimum warning, validity, note, total, send/cancel. |
| O09 | Decline quote | Reason choices, optional note, destructive action, keep negotiating. |
| O10 | Store status | Accepting switch, four pause durations, consequence, save/pause action. |
| O11 | Business details | All supplied fields; long form needs scrolling and keyboard clearance. |
| O12 | Delivery fee | Flat and tiered variants, add/remove tiers, Save. |
| O13 | Payout account information | Masked bank/UPI details, support change instruction. |
| O14 | Seller policies | Scrollable content shell; actual policy text pending. |
| O15 | Storefront preview | Buyer-facing cover/logo/name/highlights composition from supplied scope. |
| O16 | Public review reply | New and edit reply variants; public audience explicitly visible. |
| O17 | Delete post | Post context and confirmation. |
| O18 | Disconnect AI | Provider context and confirmation. |
| O19 | Holiday date picker | Select/add date, cancel. |
| O20 | Quiet-hour time pickers | From and Until variants. |
| O21 | Catalogue sort menu | All five supplied sort choices and current selection. |

Also include platform camera/gallery permission and chooser states where needed. Terms, privacy, open-source licences, contact handoffs, and website activation are linked destinations whose detailed presentation is not supplied. Do not silently turn these into invented native features.

## Critical journey maps

### Access and onboarding

Sign in → OTP or email verification → account-state routing → start/resume application → five steps → submitted review → approved Home. Not-approved routes to correction/resubmission; suspended routes to support. Google linking requires the supplied mobile-verification branch. Back/Edit must preserve entered values in the prototype.

### Fulfilment and settlements

Home queue or Orders → order detail → Accept order → Start packing → Mark ready for pickup → externally updated delivery stages → delivered settlement → Payments → settlement detail or monthly statement. Show reject/cancel only in permitted states; exact cancellation cutoff is unresolved.

### Catalogue upkeep

Catalogue → add/edit → photo/basic details → options and stock → tax/pricing → delivery coverage → wholesale → save or draft. Low-stock entries on Home should land in the relevant catalogue context. Visibility and publication must have distinct, understandable states where the product rules distinguish them.

### Business negotiation

Home/Account → Quotes → quote detail → accept, counter, or decline → waiting/accepted/closed state → View order only once linked. Preserve offer expiry and current actor. Never imply acceptance automatically means paid or fulfilled.

### Store management

Account → status, hours/holidays, business details, delivery fee, storefront, reviews, posts, preferences or support → saved feedback → updated parent context. Paused and scheduled closed are different states and may overlap; the UI must not imply Resume overrides a holiday.

## Proposed visual direction

Fresh design proposal, not a comparison with any existing screens:

- Calm agricultural-business identity: deep green primary actions, warm neutral backgrounds, clear white surfaces, restrained product imagery. Exact palette remains a design choice and must pass contrast checks.
- Strong readable type, prominent amounts, and compact but legible metadata. Use Indian currency/grouping consistently; keep units next to quantities.
- One visually dominant next action per decision point. Secondary actions remain available without competing for emphasis.
- Status labels always include words; amber, blue, green, and neutral colours supplement those words.
- Use compact operational rows for queues and lists; avoid making every small datum its own oversized card.
- Break the product editor into clearly labelled sections with progressive disclosure for conditional inputs. Preserve all capabilities; a new multi-step workflow is a proposal, not assumed existing behaviour.
- Phone first, with wider-window layouts for orders/quotes list and detail, dashboards, and forms. Retain the supplied five-destination side rail on tablets.
- Light and dark themes use the same component structure. Screen-count coverage does not require mechanically duplicating every state in both themes, but all components and critical screens need theme checks.

## Accessibility and layout research

- Use at least 48 × 48 dp Android touch targets, including small icons and chip hit areas. [Google accessibility guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en-GB).
- Target 4.5:1 contrast for ordinary text and 3:1 for qualifying large text; verify actual colours before declaring compliance. [W3C contrast guidance](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum).
- Pair status colours with labels/icons and give charts distinguishable series and clear legends. [W3C use-of-colour guidance](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html).
- Adapt navigation to available window space, using a bottom bar for compact windows and rail for wider layouts. [Android adaptive-navigation guidance](https://developer.android.com/develop/adaptive-apps/guides/build-adaptive-navigation).

Mockup checks should include small phone widths, large text, keyboard-open forms, safe-area clearance, long names, large currency values, zero data, and long lists. Do not truncate required action labels or hide form errors beneath sticky controls. These are design acceptance criteria; accessibility cannot be fully established from pictures alone.

## State and feedback coverage

The attachment specifies loading, errors, emptiness, and toast feedback. Apply them where meaningful rather than adding empty states to every form.

- Lists: initial loading, populated, empty, filtered empty, failed/retry, refresh.
- Forms: initial, edited, invalid, submitting, success, failed with input retained.
- Uploads/location: permissions, progress, failure/retry, successful replacement/pinning.
- Actions: confirm where specified, show in-progress feedback, prevent accidental duplicate submission in the interactive prototype.
- Financial views: pending/paid, absent payout account, masked identifiers, no fabricated bank references.
- Time-dependent views: OTP cooldown, quote expiry, pause duration, scheduled closure.
- AI: activation/payment/connection states remain distinct; chat response contents are illustrative, never claimed real analysis.

Offline behaviour, autosave, unsaved-edit confirmation, pagination, and concurrent-change handling are useful implementation questions but are not established capabilities in the source.

## Open product questions and safe mockup defaults

These do not block base layouts. Annotate affected frames instead of inventing business rules.

| Unresolved point | Mockup default |
|---|---|
| Brand assets/typeface | Use a text wordmark and proposed palette; no invented official logo. |
| Settlement timing, commission, refunds | Use explicitly fictional consistent sample values; promise no dates or rates. |
| Cancellation stage cutoff | Show source-defined early actions; flag later eligibility for confirmation. |
| Health formula/targets | Reserve target text and sample metrics; do not invent official thresholds. |
| Base stock versus option stock | Show both supplied controls; flag aggregation/decrement rule. |
| Area/default/current price precedence | Show labelled alternatives; avoid fabricating which automatically wins. |
| Delivery fee tier boundaries | Show illustrative rows; flag overlaps and boundary behaviour. |
| Notification settings persistence | Annotate save behaviour as unspecified; do not add a Save button as fact. |
| AI website handoff | Represent the supplied website-activation explanation; checkout details remain out of scope until provided. |
| Reapplication rejected fields | Provide correction entry point; no invented review reasons. |
| Contact/legal content | Visible labelled placeholders in the prototype until supplied. |
| Languages and coverage expansion | English and documented Tamil Nadu coverage only. |

## Mockup production plan and completion criteria

1. Establish foundations and five representative screens: Home, Orders, Order detail, Catalogue, Payments.
2. Complete access, application, and account-status branches.
3. Complete fulfilment, invoice, product editing, stock, draft, visibility, and bulk actions.
4. Complete settlement/statement and all quote-negotiation branches.
5. Complete account management, storefront, reviews/posts, AI, notifications, help, and settings.
6. Add the overlay register, meaningful loading/error/empty states, tablet compositions, and dark-theme checks.

The order is a production sequence, not reduced scope. Each destination needs a traceable ID, populated frame, necessary variant frames, and connected entry/exit points. Each overlay needs a trigger, close/cancel path, and completion result. Sample amounts, counts, dates, products, customers, and order references must agree across linked screens. Use one fictional seller dataset throughout and make its illustrative nature clear.

The research pass is complete for the supplied inventory. Visual production and seller usability validation are separate next stages.

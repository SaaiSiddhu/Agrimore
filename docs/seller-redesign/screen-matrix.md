# Seller redesign — screen & state matrix

Legend — **Func**: E = existing capability restyled · N = new/fixed capability in this phase ·
**Impl**: TODO · WIP · DONE · **Verified**: — (not yet) · T (automated tests pass) · A (seen on Android device,
screenshot inspected) · J (end-to-end journey executed) · iOS column is BLOCKED unless stated (no Xcode on this
machine, see verification report). L/D = light/dark verified. Evidence paths are under `evidence/android/`.
Board ids are `NN-MM` = `apps/seller/assets/ui-mockups/<phase folder>/<MM>-….png`.

## Foundations (phases 01–15, 24)

| ID | Item | Boards | Where | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| F-01 | Seller palette light + dark | 01-01, 02-01, 03-01 | `agrimore_ui/lib/workspace/ws_tokens.dart` | N | TODO | — | `seller_palette_test.dart` | — |
| F-02 | Type scale (Inter, tabular money) | 02-01, 05-01 | `ws_brand_style.dart`, `ws_theme.dart` | N | TODO | — | theme tests | — |
| F-03 | Shape & density (48 dp, radius 8/12/20) | 02-01, 08-01 | `ws_brand_style.dart` | N | TODO | — | theme tests | — |
| F-04 | Lucide icon set additions | 06-01 | `ws_icons.dart` | E+N | TODO | — | — | concurrent DLV-P1 edit |
| F-05 | Avatars, thumbnails, image states | 06-01, 15-01 | `kit/ws_media.dart` | N | TODO | — | kit tests | — |
| F-06 | Responsive: bar < 600, rail ≥ 600, list+detail ≥ 840 | 04-01, 07-01 | `kit/ws_nav.dart`, `seller_shell.dart` | N | TODO | — | shell tests | — |
| F-07 | Single-border keyboard focus, every control | 24-01 (superseded ring), 24-02 | `ws_theme.dart`, `kit/ws_focus.dart` | N | TODO | — | `focus_test.dart` | — |
| F-08 | Motion + reduced motion | 02-01, 24-05 | `ws_theme.dart`, kit | N | TODO | — | reduced-motion tests | — |
| F-09 | Feedback: banners, toasts, submit states | 13-01 | `kit/ws_banner.dart`, `ws_feedback.dart` | E+N | TODO | — | kit tests | toast restyle waits for DLV-P1 |
| F-10 | Overlays: sheets, confirm dialogs, discard guard | 14-01 | `kit/ws_sheet.dart` | E+N | TODO | — | kit tests | — |
| F-11 | Forms: persistent labels, required/optional, errors, pickers | 09-01, 24-07 | `kit/ws_fields.dart` | N | TODO | — | field tests | — |
| F-12 | Status badges, progress, timelines, non-colour cues | 12-01, 24-06 | `kit/ws_status.dart`, `kit/ws_timeline.dart` | E+N | TODO | — | kit tests | — |
| F-13 | Cards, lists, key/value, money breakdown | 11-01 | `kit/ws_card.dart`, `kit/ws_list.dart` | N | TODO | — | kit tests | — |
| F-14 | Search / filter chips / sort menus | 10-01 | `kit/ws_filters.dart` | N | TODO | — | screen tests | — |
| F-15 | Media picking, permission, location states | 15-01 | seller screens | E+N | TODO | — | screen tests | — |
| F-16 | Buttons & selection controls (loading, disabled, destructive) | 08-01 | `kit/ws_button.dart` | N | TODO | — | `button_test.dart` | — |
| F-17 | Screen-reader names/roles/states, grouping | 24-03 | all | E+N | TODO | — | semantics tests | TalkBack pass manual |
| F-18 | Contrast, 48 dp targets, text scaling | 24-04 | all | N | TODO | — | contrast + 2.0× tests | — |
| F-19 | Accessible charts (summary + table) & form error summary | 24-07 | `kit/ws_charts.dart`, `kit/ws_fields.dart` | N | TODO | — | tests | — |

## Shell & system

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| S-01 | Launch: "Loading your seller account" | 13-01 | `app.dart` `_LoadingAccount` | E | TODO | — | | — |
| S-02 | Bottom navigation (5 roots, badges, 99+) | 07-01 | `seller_shell.dart` | E+N | TODO | — | `shell_test.dart` | — |
| S-03 | Navigation rail (≥ 600) | 04-01, 07-01 | `seller_shell.dart` | E+N | TODO | — | | — |
| S-04 | Orders list + detail side by side (≥ 840) | 04-01, 07-01 | `seller_orders_screen.dart` | N | TODO | — | | — |
| S-05 | Global search (grouped, exact order jump, min 2 chars, no match) | 10-01 | `search/search_screen.dart` | E | TODO | — | `inbox_search_test.dart` | — |
| S-06 | Android back: non-Home tab → Home, then exit | 07-01 | `seller_shell.dart` | N | TODO | — | | — |

## Authentication & onboarding (phase 16)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| A-01 | Mobile sign-in: idle · invalid · sending · rate-limited · unavailable · network | 16-01 | `auth/seller_sign_in_screen.dart` | E | TODO | — | `auth_screens_test.dart` | — |
| A-02 | OTP: entry · verifying · wrong code · resend countdown · resend / call · test-mode ribbon | 16-02 | same | E | TODO | — | | OTP E2E only on emulator (D13) |
| A-03 | Google → verify mobile once (link) · cancel | 16-01 | same | E | TODO | — | | Google sign-in needs SHA registration (owner, ADR E5) |
| A-04 | Email sign-in · show/hide password · errors · reset sheet · sent · failed | 16-01, 16-02 | `auth/email_sign_in_screen.dart` | E | TODO | — | | — |
| A-05 | Application intro ("About 5 minutes") | 16-03 | `onboarding/apply_intro_screen.dart` | E | TODO | — | `onboarding_test.dart` | — |
| A-06 | Step 1 business details | 16-03 | `onboarding/steps/business_step.dart` | E | TODO | — | | — |
| A-07 | Step 2 location & delivery: use location · finding · pinned · denied (settings/try again) · manual | 16-03, 15-01 | `steps/location_step.dart` | E+N | TODO | — | | — |
| A-08 | Step 3 documents: required/optional · uploading · uploaded · failed/retry · replace · missing | 16-04, 15-01 | `steps/documents_step.dart` | E+N | TODO | — | | — |
| A-09 | Step 4 payout: bank / UPI · masked · mismatch · IFSC | 16-03 | `steps/payout_step.dart` | E | TODO | — | | — |
| A-10 | Step 5 review & submit: summaries · edit · consent · submitting · invalid · failed | 16-05 | `steps/review_step.dart` | E | TODO | — | | — |
| A-11 | Pending approval: timeline · check status · still pending · error · contacts · sign-out sheet | 16-06 | `auth/application_status_screen.dart` | E | TODO | — | | — |
| A-12 | Rejected: fix & resubmit · contacts · sign out | 16-07 | `auth/account_restricted_screen.dart` | E | TODO | — | | no admin reason field (D15) |
| A-13 | Suspended: restricted banner · what it means · contacts · sign out | 16-08 | same | E | TODO | — | | — |

## Home, insights & health (phases 11, 12, 21)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| H-01 | Home: greeting · search · bell · paused / closed-today banner · needs you now / all caught up · KPIs (period, loading, error, zero) · health · next settlement · quick actions | 03-01, 11-01, 21-01 | `home/dashboard_screen.dart` | E+N | TODO | — | `home_test.dart` | — |
| I-01 | Insights: period · range · KPI cards · comparisons · two-series chart + table · stage bars · top products · B2B share · empty period · error | 21-01…06, 24-07 | `insights/insights_screen.dart` | E+N | TODO | — | `insights_test.dart` | — |
| I-02 | Metric explanation sheet | 21-09 | `insights/…` | N | TODO | — | | — |
| I-03 | Account health: ring · band · tiles · measures vs target · not enough data · explanations | 21-08, 21-09 | `insights/health_screen.dart` | E+N | TODO | — | | — |

## Orders (phase 17)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| O-01 | Orders list: search · stage chips + counts · period + B2B · card · empty · no match · loading · error · refresh | 17-01, 10-01, 11-01, 12-01 | `orders/seller_orders_screen.dart` | E | TODO | — | `orders_ui_test.dart` | — |
| O-02 | Order detail: stage + timeline · customer & delivery (masked phone, call, SMS) · items/options · payment · invoice card · actions by stage · busy · failure · live update | 17-02…05 | `orders/seller_order_detail_screen.dart` | E+N (D9, D10) | TODO | — | | — |
| O-03 | Reject / cancel sheet: reasons · note · prepaid refund note · validation · submitting · failure keeps input | 17-06 | `orders/widgets/order_reason_sheet.dart` | E+N | TODO | — | `order_reason_sheet_test.dart` | — |
| O-04 | Invoice: bill of supply / tax invoice · copy number + toast · loading · error | 17-07, 19-06 | `orders/invoice_screen.dart` | E+N | TODO | — | `invoice_test.dart` | — |
| O-05 | Invoice card: generate · generating · failure · view | 17-07 | `orders/widgets/order_invoice_card.dart` | E | TODO | — | | — |

## Catalogue (phase 18)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| C-01 | Catalogue: search · sort menu · chips + counts · product card · visibility switch · overflow · empty · no match · loading · error | 18-01, 18-02, 10-01 | `products/seller_products_screen.dart` | E+N (D7) | TODO | — | `catalogue_ui_test.dart` | — |
| C-02 | Update-stock sheet: current · invalid · saving · failure keeps value | 18-03, 14-01 | same | E+N | TODO | — | | — |
| C-03 | Selection mode + bulk Publish (n) / Hide (n) with per-product results | 18-03, 08-01 | same | E+N (D8) | TODO | — | `catalogue_test.dart` | — |
| C-04 | Delete product dialog | 18-01, 14-01 | same | E | TODO | — | | — |
| C-05 | Product editor (new/edit): photo add/replace/states · core fields · link rows · error summary · save / draft · saving · failure · discard guard · 30-day stats | 18-04, 15-01, 24-07 | `home/add_product_screen.dart` (+ `products/editor/*`) | E+N (D6) | TODO | — | `catalogue_test.dart`, `variants_test.dart` | — |
| C-06 | Pack options: list · add/edit sheet · duplicate name · price > 0 · empty | 18-05 | `products/editor/pack_options_screen.dart` | E | TODO | — | `variants_test.dart` | — |
| C-07 | Pricing & tax: selling/MRP · centre pricing (linked products) · price source · reset · HSN · GST | 18-06 | `products/editor/pricing_tax_screen.dart` | E | TODO | — | | — |
| C-08 | Coverage: state / district / radius · use location · detecting · error · validation | 18-07 | `products/editor/coverage_screen.dart` | E | TODO | — | | — |
| C-09 | Wholesale: off · on · price < selling · MOQ > 0 · summary | 18-08 | `products/editor/wholesale_screen.dart` | E | TODO | — | | — |

## Payments (phase 19)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| P-01 | Payments: to be paid · paid 30 d · paid all time · payout account (on file / missing / unavailable) · monthly statement · recent settlements · empty · loading · error | 19-01, 19-02, 19-07 | `payments/payments_screen.dart` | E+N | TODO | — | `payments_test.dart` | — |
| P-02 | All settlements | 19-01 | `payments/…` | N | TODO | — | | — |
| P-03 | Settlement detail: timeline · financials · reference copy | 19-03, 19-04 | `payments/payments_screen.dart` | E+N | TODO | — | | — |
| P-04 | Monthly statements: list · detail · copy | 19-05 | `payments/statements.dart` | E | TODO | — | `statements_test.dart` | — |

## Quotes (phase 20)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| Q-01 | Quote inbox: 4 chip tabs + counts · card · empty · error · loading | 20-01 | `rfq/seller_rfq_inbox_screen.dart` | E | TODO | — | `quotes_test.dart` | — |
| Q-02 | Quote detail: header · offer on the table · vs listed · expiry warning · expired · history · footer by turn · waiting · accepted · declined · order placed + view order | 20-02…04, 20-06…08 | `rfq/seller_rfq_detail_screen.dart` | E | TODO | — | | — |
| Q-03 | Counter sheet: price · qty · validity chips (7 default) · note · live total · MOQ warning · validation · sending | 20-05, 20-06 | `rfq/widgets/quote_counter_sheet.dart` | E | TODO | — | | — |
| Q-04 | Decline sheet | 20-07 | `rfq/widgets/quote_decline_sheet.dart` | E | TODO | — | | — |
| Q-05 | Accept confirm | 20-07 | detail | E | TODO | — | | — |

## Account, store management & engagement (phases 22, 23)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| M-01 | Account: store header · status card (taking orders / paused / closed today) · store menu · tools menu · sign out | 22-01, 23-08 | `profile/seller_profile_screen.dart` | E+N | TODO | — | `account_screen_test.dart` | — |
| M-02 | Store status sheet: accepting · pause 1/3/7 days / until resumed · consequence · resume | 22-02 | `account/store_status.dart` | E | TODO | — | `account_test.dart` | — |
| M-03 | Weekly off & holidays: day chips · summary · holidays · date picker · empty · all-days error · 30 limit · saved | 22-03, 22-04 | `account/store_schedule.dart` | E | TODO | — | `store_schedule_test.dart` | — |
| M-04 | Business details (screen): fields · GSTIN optional · time pickers · radius · errors · saved | 22-05 | `profile/business_details_sheet.dart` → screen | E+N | TODO | — | `account_test.dart` | — |
| M-05 | Delivery fees (screen): flat / by order value · tiers · validation (localised) · saved | 22-06 | `profile/delivery_fee_sheet.dart` → screen | E+N | TODO | — | `delivery_fee_validation_test.dart` | — |
| M-06 | Storefront editor: cover/logo states · name · about · highlights ≤ 3 · save · failure · discard guard | 22-07 | `storefront/storefront_editor_screen.dart` | E+N | TODO | — | `storefront_test.dart` | — |
| M-07 | Storefront preview (full screen, "Preview only") | 22-07, 14-01 | same | E | TODO | — | | — |
| M-08 | Reviews & replies: summary + distribution · filters · reply sheet · 24 h edit · locked · sent · failed · empty | 22-08, 21-07 | `reviews/reviews_screen.dart` | E | TODO | — | `reviews_test.dart` | — |
| M-09 | Followers & posts: count + new · posts (photo, text, tag, time) · delete dialog · empty · errors | 22-09 | `posts/followers_screen.dart` | E+N | TODO | — | `followers_test.dart` | — |
| M-10 | New post: text · photo · remove photo · tag product · rule · posting · failure | 22-09 | `posts/create_post_screen.dart` | E | TODO | — | | — |

## AI, notifications, preferences, support (phase 23)

| ID | Screen / state | Boards | Route / widget | Func | Impl | Verified | Evidence / tests | Blockers |
|---|---|---|---|---|---|---|---|---|
| X-01 | AI assistant: loading · not connected (web-only notice) · chat · thinking · error + retry | 23-01 | `ai/seller_ai_chat_screen.dart` | E+N | TODO | — | | real Gemini not exercised (simulated) |
| X-02 | AI connection: web activation (web only) · connect form · connected · disconnect confirm · errors | 23-01 | `profile/seller_ai_integration_screen.dart` | E | TODO | — | | payment web-only (D12) |
| X-03 | Notifications: chips · today / earlier · unread / read · mark all read · empty · error | 23-02, 12-01 | `notifications/notifications_screen.dart` | E | TODO | — | `inbox_search_test.dart` | — |
| X-04 | Notification preferences + quiet hours: toggles · from/until pickers · save failed → rollback | 23-02, 23-03, 24-03 | `account/notification_settings_screen.dart` | E | TODO | — | `account_test.dart` | — |
| X-05 | Settings: appearance (System/Light/Dark) · rows · licences · version | 23-04, 24-02 | `account/settings_screen.dart` | E | TODO | — | | — |
| X-06 | Help & support: FAQ search · expand · no match · contacts · browse FAQs | 23-05, 23-06 | `account/help_screen.dart` | E | TODO | — | | policy URLs = configured AppConstants |
| X-07 | Seller policies: numbered policies · legal documents (open in browser) | 23-07 | new `account/policies_screen.dart` | N | TODO | — | | — |
| X-08 | Sign-out confirmation sheet · signing out · failure | 23-08, 14-01 | account + status screens | E+N | TODO | — | | — |

## End-to-end journeys (brief §15)

Tracked in `verification-report.md` §Journeys (executed / simulated / blocked, with the exact command).

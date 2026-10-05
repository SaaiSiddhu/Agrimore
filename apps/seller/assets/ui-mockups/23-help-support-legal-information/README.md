# Agrimore Seller — C23 help, support and legal information

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C23 owner approval is pending.

Compact blue-teal merchant FAQ and contact rows, copper external-handoff notes and cool-neutral policy groups.

[Ten-board gallery](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/HELP_SUPPORT_LEGAL_INFORMATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Seller HelpScreen filters six local translated FAQs by question/answer, announces nonempty-query count and has empty result state. SellerSupportCard uses AppConstants tel/mailto external launcher; it awaits but ignores false results and only logs exceptions. SellerPoliciesScreen shows local rules and configured terms/privacy external URLs, similarly ignores false return. No merchant ticket submission/tracking UI evidenced in inspected help.

## Target direction

Preserve searchable local FAQ and genuine phone/email handoffs; add visible launch failure/retry and truthful browser legal entries. Do not fabricate ticket tracking or send acknowledgement.

| Panel | Domain specimen |
| --- | --- |
| Merchant FAQ discovery | Card "Seller help", EMPTY "Search FAQs" field and two collapsed accordion rows "Orders and quotes" and "Payout account" with clear expand chevrons. Copper BOARD note "Search local questions and answers". No result counts, money, FAQ answer or guaranteed payout timing. |
| Configured contact actions | Card "Contact Agrimore", PRIMARY "Open phone app", SECONDARY "Open email app". Below "Continue in your phone or email app." Copper BOARD note "Configured contact / external handoff". No raw phone/email, live-chat icon, sent/connected confirmation or new ticket. |
| Contact launch recovery | Card "Could not open the phone app", body "Try opening it again." SECONDARY "Try again". Copper BOARD note "Visible failure feedback proposed". No app-opened/call-connected/copied/sent success tick. No different invented channel. |
| Merchant legal documents | Card "Policies and legal", two rows "Terms and conditions" and "Privacy policy", document icons and SMALL external-link symbols; "Opens in your browser". Copper BOARD note "Configured policy links / availability to verify". No raw URL, legal paragraph, dates, consent checkbox, refund/fee promise or compliant badge. |

Preservation and gaps:

- Launcher bool false and exceptions need readable feedback; opening phone/email is not call connection/message send.
- Shared contact values are configured in code, not validated live reachable by this task.
- External policy location is not proof approved/current content; do not invent operating hours or payout/refund SLA.

## Light

![Agrimore Seller C23 light](agrimore-seller-help-support-legal-information-light.png)

## Dark

![Agrimore Seller C23 dark](agrimore-seller-help-support-legal-information-dark.png)


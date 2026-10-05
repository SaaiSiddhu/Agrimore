# Agrimore Sales Associate — C22 account, appearance and privacy presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C22 owner approval is pending.

Premium royal-blue associate identity, indigo appearance/review context and pearl/slate privacy rows.

[Ten-board gallery](../../../../../docs/design-system/ACCOUNT_APPEARANCE_PRIVACY_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/ACCOUNT_APPEARANCE_PRIVACY_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Associate profile masks phone but renders email; appearance UI only offers Dark Mode switch. ThemeProvider already supports/persists System/Light/Dark, applies before saving and swallows persistence errors. Profile sign-out has mounted/navigator checks but no explicit captured opening owner/session/route recheck in this caller. Payout form legitimately edits owned raw bank/UPI values and requests approved destination changes; saving does not verify ownership. No self-delete UI evidenced.

## Target direction

Expose existing three-mode capability with a proposed selector, keep masked summaries separate from intentional payout editing/review, and add owner-scoped sign-out protection. Do not invent payout approval, commission values or account deletion.

| Panel | Domain specimen |
| --- | --- |
| Associate identity | Card "Associate profile", generic person outline icon, EMPTY name skeleton, label "Contact details"; SECONDARY "Edit profile". Indigo BOARD note "Signed-in associate identity". No initials/email/phone/commission rate/approved-role badge. |
| Appearance | Card "Appearance", THREE choices "System", "Light", "Dark", select matching board theme. Below "On this device". Indigo BOARD note "Proposed selector / existing three-mode provider". No cloud-sync/saved assertion. |
| Payout privacy and review | Card "Payout account", rows "Bank account" and "UPI", values ONLY "••••••••". SECONDARY "Review payout details". Indigo BOARD note "Masked summary / changes need review". No amount/account digits/UPI/payee/approval/checkmark/eye toggle. |
| Associate account actions | Card "Sign out of this account?", body "Return to sign-in on this device." SECONDARY "Keep working" and PRIMARY "Sign out". Indigo BOARD note "Current account / guarded confirmation". No Delete account, earnings loss assertion, signed-out success or operation-cancellation promise. |

Preservation and gaps:

- Three-choice selector is proposed UI exposing existing provider capability.
- Masked summary does not replace necessary access-controlled raw editing. Payout change review is not verified ownership.
- Local theme persistence failure needs honest feedback; no cloud sync or server account-setting claim.

## Light

![Agrimore Sales Associate C22 light](agrimore-sales-associate-account-appearance-privacy-presentation-light.png)

## Dark

![Agrimore Sales Associate C22 dark](agrimore-sales-associate-account-appearance-privacy-presentation-dark.png)


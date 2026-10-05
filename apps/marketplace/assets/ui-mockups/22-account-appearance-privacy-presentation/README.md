# Agrimore Marketplace — C22 account, appearance and privacy presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C22 owner approval is pending.

Calm professional green shopper identity, warm-gold appearance guidance and natural-stone privacy summaries.

[Ten-board gallery](../../../../../docs/design-system/ACCOUNT_APPEARANCE_PRIVACY_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/ACCOUNT_APPEARANCE_PRIVACY_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Profile loads account name/email/phone/photo; phone is readable. Settings uses the actual bool ThemeProvider and persisted Light/Dark preference, no System mode. Profile logout clears cart then calls FirebaseAuth directly after confirmation, without the owned provider path or a captured episode in this caller. DeleteAccountScreen already captures owner/episode, invalidates replacement sessions, gates acknowledgement/submitting and maps callable refusal versus unknown failure. Shared AuthService now delegates deletion to deleteUserData; do not describe an obsolete client-side deletion flow.

## Target direction

Keep two supported appearance choices. Separate contact editing, appearance and private summaries; propose masked summary values and owned/busy sign-out feedback. Preserve guarded deletion review and authoritative refusal handling.

| Panel | Domain specimen |
| --- | --- |
| Shopper identity | Card "Your account", generic outline person avatar, EMPTY name skeleton, labels "Contact details" and "Saved addresses" with neutral empty rows; SECONDARY "Edit profile". No name, photo, initials, phone, email or address. Gold board note "Identity follows the signed-in account". |
| Appearance | Card "Appearance", TWO labelled choices "Light" and "Dark" only. Select the board theme exactly. Below "On this device". Gold note "Two supported modes". No System choice, sync claim or saved toast. |
| Sensitive summaries | Card "Contact summary", rows "Phone" and "Email", values ONLY "••••••••". SECONDARY "Edit contact details". Gold BOARD note "Proposed masked summary". No eye/reveal toggle or pretend secure-storage guarantee. |
| Account actions | Card "Account actions", PRIMARY "Sign out"; separate neutral outlined row "Review account deletion" and small "Review requirements before continuing". Gold BOARD note "Separate actions / current account only". No Delete now, success, signed-out confirmation or irreversible-action checkmark. |

Preservation and gaps:

- Light/Dark only; do not invent working System mode or cross-device theme sync.
- Profile contact masking and logout owner/episode guard are proposals; preserve existing guarded deletion form.
- Deletion callable refuses balances, active orders and pending payouts; review does not certify eligibility or erase every financial/history record.

## Light

![Agrimore Marketplace C22 light](agrimore-marketplace-account-appearance-privacy-presentation-light.png)

## Dark

![Agrimore Marketplace C22 dark](agrimore-marketplace-account-appearance-privacy-presentation-dark.png)


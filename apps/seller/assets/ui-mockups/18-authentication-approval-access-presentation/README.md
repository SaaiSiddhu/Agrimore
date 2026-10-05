# Agrimore Seller — C18 authentication, approval and access presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C18 owner approval is pending.

Compact blue-teal merchant identity panels, copper application context, cool-neutral review surfaces and clear operational restriction cards.

[Ten-board gallery](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

SellerSignInScreen owns phone-code entry, Google phone-linking and email alternative. SellerAccess maps signedOut/loading/noApplication/draft/pending/rejected/suspended/approved to distinct routes. ApplicationStatusScreen has Check status, support and sign-out. Rejected accounts can reopenAfterRejection; suspended accounts have support/sign-out, not Fix and resubmit. Access-read exceptions set network error but route to noApplication; that read-failure presentation needs a distinct recovery state. resolveSellerAccess permits legacy seller role with null status, so the target cannot claim every current seller passed an explicit review.

## Target direction

Preserve existing sign-in options and access decisions while separating unresolved read failure from genuinely missing application. Show pending application without ETA or guaranteed approval; suspension does not offer application resubmission. Rejected correction is a separate existing path, not a suspension unlock.

| Panel | Domain specimen |
| --- | --- |
| Sign-in | Card "Seller sign-in", EMPTY "Mobile number", PRIMARY "Send code", OUTLINED "Continue with Google", text action "Use email instead". Copper note "One identity, separate seller access". Do not invent admin invitation or forced email verification. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, PRIMARY "Verify code", OUTLINED "Change number". Small notice "Phone verification does not approve your application"; separate Failed variant "Code not accepted". No phone values, code digits or timer. |
| Application review | Application card "Application under review", labelled steps "Submitted" with check, "Under review" highlighted, "Approval decision" upcoming neutral hollow marker (NOT checked). PRIMARY "Check status", OUTLINED "Contact support", text "Sign out". Copper guidance "Review does not guarantee approval". No date, percentage, approval promise or submit-again. |
| Suspension | Restriction card "Seller account suspended", shield-alert icon and semantic warning notice "Your seller workspace is unavailable." OUTLINED "Contact support" and "Sign out". Copper annotation "Suspension is separate from rejection". Small distinct text note "Rejected application: Fix and resubmit is a separate flow" without a resubmit button in suspended card. No unblock, reopen store, order-taking or self-approval action. |

Preservation and gaps:

- Failed access lookup currently selects noApplication; target should retain uncertainty and an explicit retry rather than imply application absence.
- Pending Check status refresh is a read, not approve or submit again; polling must be bounded and session-owned.
- Fix and resubmit is rejected-only and remains subject to existing callable conditions; never offer it for suspended.
- Legacy approval resolution is current source behavior, not owner-approved new authorization policy.
- Keep OTP identity proof separate from application status and merchant workspace permission.

## Light

![Agrimore Seller C18 light](agrimore-seller-authentication-approval-access-presentation-light.png)

## Dark

![Agrimore Seller C18 dark](agrimore-seller-authentication-approval-access-presentation-dark.png)


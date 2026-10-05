# Agrimore Delivery — C18 authentication, approval and access presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C18 owner approval is pending.

High-contrast black/white rider credential forms, burgundy restriction cues, burnt-orange field guidance and large task-ready controls.

[Ten-board gallery](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

DeliveryLoginScreen signs in with email/password and has a password-reset sheet. DeliveryAuthProvider distinguishes missing registration, profileUnavailable, wrong role, approved-operable and blocked KYC states. PendingApprovalScreen presents pending/rejected/suspended/deactivated; canResubmit is only pending/rejected. The screen includes support/sign-out and separately protected account deletion. No phone-OTP sign-in was found in the inspected login. Suspension is not the same as offline status or document-change request pending review.

## Target direction

Present credentials, account verification/read checking, pending rider application and suspended work access as distinct states. Preserve approved-only operations; missing profile and failed profile read get different guidance. Application editing never activates a rider or clears a suspension.

| Panel | Domain specimen |
| --- | --- |
| Sign-in | Card "Rider sign-in", EMPTY "Email" and "Password" fields, labelled eye icon "Show password", black PRIMARY "Sign in", secondary text "Forgot password?". Orange annotation "Email and password". No Google, phone-code field or MFA. |
| Account verification | Card "Checking rider access", indeterminate spinner, text "Checking your rider profile and account status." Distinct Failed variant "Account check unavailable" with safe helper "This does not mean your application was rejected." Board-only orange annotation "Read failure is not a review decision"; NO OTP or resend action, NO percentage and NO completed tick. |
| Application review | Card "Application under review", small "Pending" status, explanation "Your rider application is awaiting review. Delivery work is unavailable." PRIMARY "Edit application", OUTLINED "Contact support", text "Sign out". Orange note "Editing does not activate access". No Check status button absent this screen, approval ETA, earnings or online toggle. |
| Suspension | Card "Rider account suspended", burgundy shield-alert and message "Delivery work is unavailable for this account." OUTLINED "Contact support" and "Sign out". Orange note "Application editing is unavailable in this state". Do not render reason values, restore access, go online, edit/resubmit, delivery assignment or account deletion as recovery. |

Preservation and gaps:

- Keep email/password sign-in and existing reset mechanism; do not invent phone OTP, Google or MFA.
- ProfileUnavailable is an access-read problem, not pending or suspended. Target indeterminate account-check panel is proposed visual presentation, not a new verification provider.
- Pending/rejected may edit application; suspended/deactivated may not. Do not expose edit or resubmit inside the suspension specimen.
- Online/offline availability, account KYC and document/identity-change review remain separate domains.
- Human reason text must be safe, authorised and session-owned; specimens omit actual reasons, names and identity documents.

## Light

![Agrimore Delivery C18 light](agrimore-delivery-authentication-approval-access-presentation-light.png)

## Dark

![Agrimore Delivery C18 dark](agrimore-delivery-authentication-approval-access-presentation-dark.png)


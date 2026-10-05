# Agrimore Sales Associate — C18 authentication, approval and access presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C18 owner approval is pending.

Premium royal-blue associate forms, indigo jurisdiction-review context, pearl/slate cards and restrained status hierarchy.

[Ten-board gallery](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

LoginScreen supports phone-code and email/password modes, with ForgotPasswordScreen. AssociateOtpScreen verifies phone through shared auth service. EmployeeAuthProvider authenticates identity then requires employee role and an employees record: suspended is explicit, any other non-approved status currently becomes pending. Missing/non-associate profile is refused. App AuthGate chooses suspension before pending via error-string contains, then approved workspace. Pending/suspended screens have Contact Support and Sign Out; pending has no evidenced refresh action and copy currently promises immediate activation.

## Target direction

Present phone or email sign-in, genuine code verification, associate review and suspension without earning/activation guarantees. Use a future typed access state rather than parsing display text; pending remains separate from absent profile or failed access lookup. Do not imply successful OTP means approved associate.

| Panel | Domain specimen |
| --- | --- |
| Sign-in | Card "Sales Associate sign-in", compact mode labels "Mobile" active / "Email" inactive, EMPTY "Mobile number", royal-blue PRIMARY "Send code". Indigo note "Email and password also supported". No Google or new application button. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, PRIMARY "Verify code", OUTLINED "Change number". Small Failed variant "Code not accepted" with "Check the code and try again." Indigo annotation "Identity verification does not grant associate access". No code digits, phone value, counter or approval tick. |
| Associate review | Card "Application pending approval", explanation "Your associate details and jurisdiction are under review. Workspace access awaits an approval decision." OUTLINED "Contact support" and "Sign out". Indigo annotation "Review has no promised completion time". No Check status, resubmit, approval promise, code activation or Start earning CTA. |
| Suspension | Card "Associate account suspended", shield-alert and semantic error notice "Your associate workspace is unavailable." OUTLINED "Contact support" and "Sign out". Indigo annotation "Suspension is distinct from pending review". No restore access, earn/share code, appeal-submitted status, new application, fee or payout controls. |

Preservation and gaps:

- Error-string routing and every non-approved status collapsing to pending require a bounded typed presentation migration, preserving existing authorisation.
- Do not add Check status, Apply here or resubmit actions where not currently supported; application is reached from the customer app.
- Replace immediate-activation promise with truthful review copy; no commission, payout, approval or earning guarantees.
- Phone OTP comes before role approval; unregistered identity receives a distinct refusal, not a fake pending application.
- Support contacts exist but boards omit real email/phone and show only supported Help Support destination.

## Light

![Agrimore Sales Associate C18 light](agrimore-sales-associate-authentication-approval-access-presentation-light.png)

## Dark

![Agrimore Sales Associate C18 dark](agrimore-sales-associate-authentication-approval-access-presentation-dark.png)


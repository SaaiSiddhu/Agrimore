# Agrimore Admin — C18 authentication, approval and access presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C18 owner approval is pending.

Professional-blue controlled-entry forms, cyan role explanations, steel/slate status rows and precise refusal copy.

[Ten-board gallery](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

AuthScreen supports email/password and Google plus password-reset email. AuthProvider loads user profile and explicitly refuses non-admin role, clearing currentUser and signing out. Profile read failure has separate safe error and restoreSession method; app router reacts to provider and checks admin before protected routes. isLocked is a temporary sign-in-attempt state, not app-account suspension. No dedicated Admin application approval, phone OTP, MFA, invitation or self-provisioning flow was found in inspected gate.

## Target direction

Show credentials, profile/access checking, role denial and recoverable account-read failure. Admin does not share merchant review or associate pending workflow. Do not invent admin approval queue, suspended badge, self-unlock, invite, OTP or MFA. Retry profile lookup uses the existing restoreSession method as a proposed consistent presentation action.

| Panel | Domain specimen |
| --- | --- |
| Sign-in | Card "Admin sign-in", EMPTY "Email" and "Password", labelled eye "Show password", professional-blue PRIMARY "Sign in", OUTLINED "Continue with Google", text "Forgot password?". Cyan note "Admin role required". No sign-up/invite/MFA/phone field. |
| Access verification | Card "Checking admin access", indeterminate spinner and text "Checking your account and admin role." No filled check, percentage or work data. Cyan annotation "Sign-in is not permission". No OTP boxes, resend, admin application or approval queue. |
| Role restriction | Card "Admin access denied", shield icon and safe semantic error "This account cannot access the admin app." OUTLINED "Sign in with another account" routed to existing sign-in after refusal. Cyan note "No self-service role approval". No Apply for access, approve, invite, unlock, suspension badge or support endpoint. |
| Read recovery | Separate recovery card "Account check unavailable", safe notice "We could not load your account. Access remains restricted." PRIMARY "Try again", small caption "Proposed recovery action" and cyan note "Checks account access only". Distinct from Role restriction; no state-changing request, admin role assignment or success badge. |

Preservation and gaps:

- AuthScreen maps role refusal safely; retain this and backend/rules protection. A design board cannot certify authorization.
- Distinguish wrong credentials, sign-in-attempt throttling, non-admin role and access-read failure; no false Admin suspended status.
- Proposed Try again for account lookup must call existing restoreSession under current session ownership; it must never change role.
- Existing Google sign-in is supported; no fabricated second-factor challenge or self-registration.
- Return paths and router initialization need future rendered tests; no privileged screen may flash while access is unresolved.

## Light

![Agrimore Admin C18 light](agrimore-admin-authentication-approval-access-presentation-light.png)

## Dark

![Agrimore Admin C18 dark](agrimore-admin-authentication-approval-access-presentation-dark.png)


# Agrimore Marketplace — C18 authentication, approval and access presentation

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C18 owner approval is pending.

Welcoming professional-green buyer forms, warm-gold guidance, natural-stone surfaces and generous rounded profile cards.

[Ten-board gallery](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/AUTHENTICATION_APPROVAL_ACCESS_PRESENTATION_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

LoginScreen has phone entry/OTP entry and Google linked-identity resolution, including phone verification for an unlinked Google identity. AuthWrapper and PostAuthRouter separately enforce profile completion at cold start and immediate post-auth routing. AuthGate wraps individual protected features; AuthGuard is web-only and mobile passthrough. Public landing and the unguarded main-route entry exist, but this is not proof of unrestricted anonymous purchase or identical guest flows on every platform. Seller/associate application approval in the buyer app belongs to those roles, not normal shopper access.

## Target direction

Illustrate phone/Google sign-in, genuine phone-code verification, profile completion and a protected-feature sign-in prompt. Do not add buyer approval or suspension workflow without authoritative support. Preserve session ownership and the intended destination without promising a currently implemented return-to-feature route.

| Panel | Domain specimen |
| --- | --- |
| Sign-in | Card title "Sign in to Agrimore", empty "Mobile number" field, green PRIMARY "Send code", OUTLINED "Continue with Google". Small warm-gold note "Google may require phone verification". No email/password form, guest button or shopper approval badge. |
| Phone verification | Card "Verify your mobile", six EMPTY code boxes, no phone/code values. PRIMARY "Verify code", OUTLINED "Change number". Small separate Failed variant notice "Code not accepted" / "Check the code and try again." Resend code appears as a secondary text option with note "When available"; no fabricated countdown or channel promise. |
| Profile completion | Card "Complete your profile", small "Form excerpt", EMPTY "Name" field, PRIMARY "Continue". Natural-stone notice "Finish your profile to continue"; warm-gold board annotation "Profile completion, not approval". No invented submitted/approved state or claim this excerpt includes every required field. |
| Protected feature | Protected-feature card "Sign in to view your orders", lock icon, body "Your order history is available after sign-in." PRIMARY "Sign in", OUTLINED "Back". Separate gold annotation "Protected action / not an approval queue". Do not depict shopper suspension, seller KYC or a confirmed order. |

Preservation and gaps:

- Keep phone verification distinct from profile completion and role applications; normal buyer access does not require seller approval.
- Profile form is an excerpt, not the complete required-field contract. Current cold-start and immediate routing checkpoints must stay consistent.
- Public/guest behavior is route/platform-specific; no new Continue as guest button is invented.
- Use safe verification failure/rate-limit copy, backend-allowed resend and clear change-number action; never render test codes or real phone values.
- Return-to-intended-feature behavior needs explicit implementation verification; current feature redirect argument alone is not proof of automatic return.

## Light

![Agrimore Marketplace C18 light](agrimore-marketplace-authentication-approval-access-presentation-light.png)

## Dark

![Agrimore Marketplace C18 dark](agrimore-marketplace-authentication-approval-access-presentation-dark.png)


# Foundation 12 — Feedback, connectivity and recovery

[Feedback, connectivity and recovery board](01-feedback-connectivity-recovery.png)

One Storybook-style Flutter iOS/Android reference generated with built-in image generation. Primary burnt orange `#C2410C`. Light/dark specimens and Lucide-style icons.

Covers loading versus empty, offline saved data, stale timestamps, reconnecting, device permissions versus account authorization, retry with retained input, confirmed success, session expiry and changed/unassigned/missing-order recovery.

All records and timestamps are illustrative. Saved data is not live confirmation. Pending delivery transitions must not appear successful offline. Device settings do not fix backend authorization. Preserve safe in-session input, prevent duplicate requests, and check server state after uncertain failures. Recheck assignment before permitting actions and remove protected data when access ends. These are design targets requiring implementation and device verification.

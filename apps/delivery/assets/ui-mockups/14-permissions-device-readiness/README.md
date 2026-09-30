# Foundation 14 — Permissions and device readiness

[Permissions and device readiness board](01-permissions-device-readiness.png)

One Storybook-style Flutter iOS/Android reference generated with built-in image generation. Primary burnt orange `#C2410C`; light/dark app-owned guidance and Lucide-style icons.

Covers location disclosure, GPS off, denied/permanently denied permissions, background tracking, notification access, Android offer alerts, camera access and Android battery guidance.

These are app-owned explanations, not replacement operating-system dialogs. Continue requests the appropriate system flow; it does not grant permission. Request again only when permitted by the OS. Device-policy restrictions may require administrator action. Android full-screen alerts, persistent notifications and battery/autostart controls vary by OS/vendor and are not iOS features. iOS background handling is a design target requiring native integration and testing. Location permission alone does not guarantee offer eligibility or readiness; account, GPS, connectivity and presence checks still apply. Proof photos remain optional. No guarantee of background uptime or alerts after force-stop is implied.

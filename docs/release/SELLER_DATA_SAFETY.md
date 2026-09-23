# AgriMore Seller — Play data-safety inputs

Derived from the code at SELLER-RELEASE-1 (2026-09-23), not from intent. Every row names where the
data lives so the answer can be re-checked. Update this file whenever a phase adds a field.

## Data collected

| Play category | Data | Why | Stored at | Shared with |
|---|---|---|---|---|
| Personal info — name | Seller / owner name, shop name | Account, storefront | `users/{uid}`, `sellers/{uid}` (shop name public) | Buyers see the shop name |
| Personal info — phone | Mobile number (sign-in) | Authentication, buyer contact | Firebase Auth, `users/{uid}`, `sellers/{uid}.phone` | Buyers of an order see it on the order |
| Personal info — email | Only if the seller signs in with Google or email | Authentication | Firebase Auth, `users/{uid}` | No |
| Personal info — address | Shop address, city, state, pincode | Storefront, delivery coverage | `sellers/{uid}` (public) | Public storefront |
| Personal info — other IDs | GSTIN (optional) | Tax invoices | `sellers/{uid}.gstin` | Printed on the buyer's tax invoice |
| Financial info | Bank account + IFSC, or UPI ID | Settlements | `seller_payout_details/{uid}` (owner + admin only) | AgriMore admins; not buyers |
| Financial info — purchase history | Orders, settlements, invoices | Running the store | `orders`, `seller_payouts`, `invoices` | The order's buyer |
| Photos | KYC: ID proof, shop photo, GST certificate | Seller verification | Storage `seller_documents/{uid}/` (owner + admin) | AgriMore admins only |
| Photos | Product photos, storefront logo/cover, post photos | Catalogue, storefront | Storage `products/`, `sellers/{uid}/storefront/`, posts | Public |
| Location — precise | Only when the seller taps "Use my current location" (delivery radius) | Delivery coverage | Stored on the product (`lat`, `lng`) | Used for buyer delivery matching |
| App activity | Quotes, reviews replies, notification preferences | Features | `rfqs`, `products/*/reviews`, `users/{uid}/settings` | Counterparties see quotes/replies |
| App info — messages | AI assistant prompts (only if the seller connects their own key) | AI answers | Sent to the seller's chosen provider via `sellerAiChatProxy`; the key is stored encrypted server-side | OpenAI or Google, under the seller's own key |
| Device IDs | FCM push token | Order/quote/payment alerts | `users/{uid}.fcmToken(s)` | Firebase Cloud Messaging |

Not collected: contacts, SMS, call logs, calendar, health, audio, background location, advertising ID.
No analytics or crash-reporting SDK is in `apps/seller/pubspec.yaml` today (no `firebase_analytics`,
no `crashlytics`).

## Security

- In transit: HTTPS/TLS for Firebase, Storage and callables.
- At rest: Google-managed encryption; the AI API key is additionally encrypted with
  `AI_KEY_ENCRYPTION_SECRET` (secret name only) and never returned to any client.
- Access control: `firestore.rules` / `storage.rules` — payout details and KYC documents are owner + admin
  only; ratings, stats, invoices and order status are server-written only.

## Deletion — CURRENT STATE (must be fixed before declaring "users can request deletion")

`deleteUserData` (functions/src/customer/deleteUserData.ts) deletes customer data (user profile, wallet,
carts, wishlists, addresses, notifications, employee record) but **not** seller data: `sellers/{uid}`,
`seller_payout_details/{uid}`, `sellerRequests/{uid}`, Storage `seller_documents/{uid}/`, storefront images,
`ai_connections/{uid}`, `seller_stats_daily`. Phase SELLER-DELETE-1 closes this; until it ships, seller
deletion requests must be handled manually by an admin.

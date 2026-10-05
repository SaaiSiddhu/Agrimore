# Agrimore Sales Associate — C21 notifications, activity and destinations

**PROVISIONAL_DIRECTION / TARGET_IMPLEMENTATION · v1 · 2026-10-03.** C01 is approved and locked; C21 owner approval is pending.

Premium royal-blue associate notice rows, indigo read-status/time provenance guidance, pearl/slate surfaces and restrained attributed-activity navigation.

[Ten-board gallery](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_BOARDS_2026-10-03.md) · [Codebase/domain map](../../../../../docs/design-system/NOTIFICATIONS_ACTIVITY_DESTINATIONS_DOMAIN_MAP_2026-10-03.md) · [Exact prompts](prompts.md) · [Manifest](manifest.json).

## Current source

Associate inbox streams latest 50 rows, treats only read==true as read, otherwise unread. Individual tap updates read:true without awaited error feedback or row navigation. Mark-all queries read==false, commits batch, shows success or raw-error snackbar; no duplicate-tap guard in inspected StatelessWidget action. Bell queries read==false limit1 for presence, which omits missing-read rows that inbox considers unread. Display date uses SaFormatters.formatDate without time. Shared notification initialization has named routing but app has no named detail route map; onUnknownRoute returns AuthGate, so exact push notice destinations are not implemented merely by wiring navigatorKey.

## Target direction

Use explicit unread/read and date-only provenance, normalize legacy fields/badge query deliberately, add safe mark-read feedback with owner/route guards, and propose typed read-only destinations. Missing/unsupported related activity retains notice and offers Back to notifications; do not pretend shared pushNamed already opens a payout/order detail.

| Panel | Domain specimen |
| --- | --- |
| Associate unread and read | Two synthetic rows titled "Attributed order update", bell outline icons and EMPTY body skeletons. First royal-blue dot, bold title and explicit "Unread"; second normal "Read" with no dot. Indigo BOARD note "Read state is not payout status". No earnings, balance, account value or count. |
| Date-only notice hierarchy | Card "Notice date", exact fixed FORMAT EXAMPLE "18 Sep 2026"; secondary "Date unavailable". Indigo BOARD notes "Date-only format example" and "Do not invent a time". No clock time, age, Today, approval timer or payout date promise. |
| Proposed read-status feedback | Three SMALL independent states: DISABLED neutral "Marking as read…" and indeterminate spinner; confirmed inline "Marked as read"; failure "Could not update read status" with SECONDARY "Try again". Indigo BOARD note "Proposed guard / confirm after write". No Paid/settled/approved badge, erased list or all-history guarantee. |
| Related activity fallback | Card "Related activity unavailable", body "The related record cannot be opened from this notice." PRIMARY "Back to notifications". Indigo BOARD notes "Typed destinations proposed" and "Keep the notice readable". No View payout button implying implemented direct navigation, raw URL, record ID or fallback approval. |

Preservation and gaps:

- Read==false query excludes missing-read docs even though inbox displays them unread; no precise count/caught-up claim until schema/query compatibility is fixed.
- Mark-all unbounded read==false batch needs scalability, operation snapshot and partial failure policy; no generic all-history success from loaded list or bad query.
- Single tap has no visible write failure; propose guarded feedback. Raw errors in list/bulk action need human-readable sentences.
- Current formatter supplies date only; do not fabricate a clock time or substitute now when createdAt is absent.
- Exact named detail destinations need app-specific allowlisted routing; AuthGate fallback protects shell access but does not prove the intended record opened.

## Light

![Agrimore Sales Associate C21 light](agrimore-sales-associate-notifications-activity-destinations-light.png)

## Dark

![Agrimore Sales Associate C21 dark](agrimore-sales-associate-notifications-activity-destinations-dark.png)


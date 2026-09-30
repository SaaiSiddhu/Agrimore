# Foundation 07 — Navigation and app structure

[Navigation and app structure board](01-navigation-app-structure.png)

One Storybook-style reference for Flutter iOS/Android, generated with built-in image generation. Brand primary: burnt orange `#C2410C`.

Covers dashboard entry points, active delivery, earnings, history, inbox, profile, back/return behaviour, offer entry and notification routing. Light/dark destination examples preserve the dashboard-hub structure without introducing bottom tabs.

Source checks: app/app.dart, offers/offer_launch.dart, screens/home/dashboard_screen.dart and screens/inbox/inbox_screen.dart. Financial inbox notices currently open Earnings, from which statements are accessible. Offer requests wait for session and current-offer checks; tapping a notification does not accept an offer. List-position restoration is a design target, not verified implementation.

Names, notices and amounts are illustrative. Payout details refers to bank/UPI destinations and review, not customer payment methods. Generic notices without a destination must not get an actionable chevron despite the illustrative inbox row styling. Account recovery must follow the actual session gate. Raster concepts do not prove interaction or accessibility behaviour.

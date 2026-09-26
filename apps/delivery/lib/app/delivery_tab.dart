// lib/app/delivery_tab.dart
//
// Phase DLVNAV1 — the five destinations of [DeliveryShell]. Kept in its own
// dependency-free file so a tab-root screen (DashboardScreen, InboxScreen)
// can accept a callback typed on this enum without importing the shell
// itself.
enum DeliveryTab { home, deliveries, earnings, inbox, profile }

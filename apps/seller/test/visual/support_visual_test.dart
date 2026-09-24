import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/providers/seller_settings_provider.dart';
import 'package:seller/screens/account/help_screen.dart';
import 'package:seller/screens/account/notification_prefs.dart';
import 'package:seller/screens/account/notification_settings_screen.dart';
import 'package:seller/screens/account/policies_screen.dart';
import 'package:seller/screens/account/settings_screen.dart';
import 'package:seller/screens/notifications/inbox_rules.dart';
import 'package:seller/screens/notifications/notifications_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  final now = DateTime(2026, 9, 24, 12);
  testWidgets('notifications', (tester) async {
    await pumpSellerApp(
      tester,
      NotificationsScreen(now: now, entries: [
        InboxEntry(id: '1', title: 'New order received', body: 'Order 1042 · ₹580', type: 'new_order', unread: true, createdAt: now.subtract(const Duration(minutes: 2))),
        InboxEntry(id: '2', title: 'Quote request', body: 'Green Valley Foods asked for a quote', type: 'rfq', unread: false, createdAt: now.subtract(const Duration(days: 2))),
      ]),
    );
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'notifications');
  });
  testWidgets('notification_prefs', (tester) async {
    await pumpSellerApp(tester, NotificationSettingsScreen(initial: const NotificationPrefs(quietHours: true), saver: (_) async => true), size: const Size(390, 1200));
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'notification_prefs');
  });
  testWidgets('settings', (tester) async {
    await pumpSellerApp(tester, ChangeNotifierProvider(create: (_) => SellerSettingsProvider(), child: const SellerSettingsScreen(versionOverride: '1.0.0 (100)')));
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'settings');
  });
  testWidgets('help', (tester) async {
    await pumpSellerApp(tester, const HelpScreen(), size: const Size(390, 1400));
    await tester.tap(find.byType(InkWell).at(3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'help');
  });
  testWidgets('policies', (tester) async {
    await pumpSellerApp(tester, const SellerPoliciesScreen());
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'policies');
  });
}

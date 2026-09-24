// Phase DLV-S1 — the SOS button used to show "SOS Alert Sent! Live location
// shared with authorities and admin." and send nothing. The sheet it opens
// now may only hand off to the dialer, and must never claim more.
import 'package:delivery/safety/emergency_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<Uri>> pump(WidgetTester t, {bool opens = true, String? support = '+91 98765 43210'}) async {
    final dialled = <Uri>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmergencySheet(
          launcher: (uri) async {
            dialled.add(uri);
            return opens;
          },
          supportPhone: support,
        ),
      ),
    ));
    return dialled;
  }

  // Words that would claim an external action happened.
  final claims = RegExp(r'\b(sent|shared|alerted|notified|contacted|on (its|their) way)\b', caseSensitive: false);

  testWidgets('says what it does and claims nothing', (t) async {
    await pump(t);
    expect(find.text('Emergency help'), findsOneWidget);
    expect(find.textContaining('does not alert the police or Agrimore by itself'), findsOneWidget);
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(claims.hasMatch(w.data ?? ''), isFalse, reason: 'claims an action: "${w.data}"');
    }
  });

  testWidgets('Call 112 hands 112 to the dialer and still claims nothing', (t) async {
    final dialled = await pump(t);
    await t.tap(find.textContaining('Call 112'));
    await t.pumpAndSettle();
    expect(dialled.single.toString(), 'tel:112');
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(claims.hasMatch(w.data ?? ''), isFalse, reason: 'claims an action after tapping: "${w.data}"');
    }
  });

  testWidgets('support number goes to the dialer without spaces', (t) async {
    final dialled = await pump(t);
    await t.tap(find.text('Call Agrimore support'));
    await t.pumpAndSettle();
    expect(dialled.single.toString(), 'tel:+919876543210');
  });

  testWidgets('when the dialer cannot open, the rider is told to dial directly', (t) async {
    await pump(t, opens: false);
    await t.tap(find.textContaining('Call 112'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't open the phone app. Dial 112 directly."), findsOneWidget);
  });

  testWidgets('no support button without a usable number', (t) async {
    await pump(t, support: '');
    expect(find.text('Call Agrimore support'), findsNothing);
    expect(find.textContaining('Call 112'), findsOneWidget);
  });

  test('dial URIs', () {
    expect(dialUri('112').toString(), 'tel:112');
    expect(dialUri(' 044-2345 6789 ').toString(), 'tel:04423456789');
    expect(dialUri(''), isNull);
    expect(dialUri('call me'), isNull);
    expect(dialUri(null), isNull);
  });
}

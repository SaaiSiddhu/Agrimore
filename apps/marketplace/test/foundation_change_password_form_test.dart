@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/profile/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;

class PasswordFormAuth extends FormAuth {
  final changed = Completer<bool>();
  final requested = <Map<String, String?>>[];
  @override
  Future<bool> changePassword(
      {required String currentPassword, required String newPassword}) {
    requested
        .add({'owner': owner, 'current': currentPassword, 'new': newPassword});
    return changed.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Finder input(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label);
  Finder action() => find
      .ancestor(
          of: find.byIcon(Icons.lock_reset_rounded),
          matching: find.byType(InkWell))
      .first;
  Future<void> mount(WidgetTester tester, PasswordFormAuth auth,
      {bool dark = false, GlobalKey<NavigatorState>? nav}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
    final key = nav ?? GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark))
        ],
        child: MaterialApp(
            navigatorKey: key,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: const Scaffold(body: Text('Base fixture')))));
    key.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(input('Current Password'), 'fixture_old');
    await tester.enterText(input('New Password'), 'fixture_new');
    await tester.enterText(input('Confirm New Password'), 'fixture_new');
  }

  Future<void> submit(WidgetTester tester) async {
    await fill(tester);
    await tester.ensureVisible(action());
    await tester.tap(action());
    await tester.pump();
  }

  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('password opening session $owner clears staged input',
        (tester) async {
      final auth = PasswordFormAuth();
      await mount(tester, auth);
      await fill(tester);
      final old =
          tester.widget<TextField>(input('Current Password')).controller!;
      auth.change(owner);
      await tester.pumpAndSettle();
      expect(input('Current Password'), findsNothing);
      expect(old.text, isEmpty);
      expect(find.textContaining('Your session changed'), findsOneWidget);
    });
    testWidgets('password captured old action $owner cannot dispatch',
        (tester) async {
      final auth = PasswordFormAuth();
      await mount(tester, auth);
      await fill(tester);
      final callback = tester.widget<InkWell>(action()).onTap!;
      auth.change(owner);
      callback();
      await tester.pump();
      expect(auth.requested, isEmpty);
      auth.changed.complete(false);
      await tester.pumpAndSettle();
    });
    testWidgets('password stale success $owner cannot pop or display success',
        (tester) async {
      final auth = PasswordFormAuth();
      await mount(tester, auth);
      await submit(tester);
      auth.change(owner);
      auth.changed.complete(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Base fixture'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(find.text('Password changed.'), findsNothing);
    });
  }
  testWidgets('password disposed pending reply is ignored', (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await submit(tester);
    await tester.pumpWidget(const SizedBox());
    auth.changed.complete(true);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
  testWidgets('password thrown failure has safe static toast', (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.changed.completeError(StateError('unsafe fixture detail'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
    expect(find.text('Could not change your password. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('password refused failure has safe static toast', (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.changed.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
    expect(find.text('Could not change your password. Please try again.'),
        findsOneWidget);
  });
  testWidgets('password duplicated captured submit dispatches once',
      (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await fill(tester);
    final callback = tester.widget<InkWell>(action()).onTap!;
    callback();
    callback();
    await tester.pump();
    expect(auth.requested.length, 1);
    auth.changed.complete(false);
    await tester.pumpAndSettle();
  });
  testWidgets('password delayed pop respects an overlaid route',
      (tester) async {
    final auth = PasswordFormAuth();
    final nav = GlobalKey<NavigatorState>();
    await mount(tester, auth, nav: nav);
    await submit(tester);
    auth.changed.complete(true);
    await tester.pump();
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Overlay fixture'))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Overlay fixture'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('password normal current owner completes in dark $dark',
        (tester) async {
      final auth = PasswordFormAuth();
      await mount(tester, auth, dark: dark);
      await submit(tester);
      expect(auth.requested.single,
          {'owner': 'owner_a', 'current': 'fixture_old', 'new': 'fixture_new'});
      auth.changed.complete(true);
      await tester.pump();
      expect(find.text('Password changed.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Base fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('password frozen input is retained while action awaits',
      (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await submit(tester);
    expect(
        tester.widget<TextField>(input('Current Password')).enabled, isFalse);
    expect(tester.widget<TextField>(input('New Password')).enabled, isFalse);
    tester.widget<TextField>(input('New Password')).controller!.text =
        'edited_fixture';
    expect(auth.requested.single['new'], 'fixture_new');
    auth.changed.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('password account renews after success before delayed pop',
      (tester) async {
    final auth = PasswordFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.changed.complete(true);
    await tester.pump();
    auth.change('owner_a');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Base fixture'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(find.text('Password changed.'), findsNothing);
  });
  testWidgets('password unsigned opening shows no input', (tester) async {
    final auth = PasswordFormAuth()..owner = null;
    await mount(tester, auth);
    expect(input('Current Password'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(auth.requested, isEmpty);
  });
  testWidgets('password provider replacement clears previous controllers',
      (tester) async {
    final old = PasswordFormAuth();
    final replacement = PasswordFormAuth();
    final notifier = ValueNotifier<PasswordFormAuth>(old);
    await tester.pumpWidget(ValueListenableBuilder<PasswordFormAuth>(
        valueListenable: notifier,
        builder: (_, auth, child) => MultiProvider(providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<ThemeProvider>.value(
                  value: FormTheme(false))
            ], child: child),
        child: const MaterialApp(home: ChangePasswordScreen())));
    await tester.pumpAndSettle();
    await fill(tester);
    final controller =
        tester.widget<TextField>(input('Current Password')).controller!;
    notifier.value = replacement;
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(replacement.requested, isEmpty);
    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });
}

@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/user/profile/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

class DeletionFormAuth extends FormAuth {
  final deleted = Completer<bool>();
  int deletes = 0;
  bool signedOut = false;
  String? code;
  @override
  bool get hasSignedOutSession => signedOut;
  @override
  String? get errorCode => code;
  @override
  Future<bool> deleteAccount() {
    deletes++;
    return deleted.future;
  }

  void signOutFixture() {
    signedOut = true;
    change(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Finder button() => find.widgetWithText(ElevatedButton, 'Delete my account');
  Future<void> mount(WidgetTester tester, DeletionFormAuth auth,
      {bool dark = false, GlobalKey<NavigatorState>? nav}) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            navigatorKey: nav,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            routes: {
              '/login': (_) => const Scaffold(body: Text('Login fixture'))
            },
            home: const DeleteAccountScreen())));
    await tester.pumpAndSettle();
  }

  Future<void> acknowledge(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 150,
        scrollable: find.byType(Scrollable));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await acknowledge(tester);
    await tester.ensureVisible(button());
    await tester.tap(button());
    await tester.pump();
  }

  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets(
        'deletion opening session $owner cannot inherit acknowledgement',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth);
      await acknowledge(tester);
      auth.change(owner);
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(auth.deletes, 0);
    });
    testWidgets('deletion stale captured action $owner cannot dispatch',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth);
      await acknowledge(tester);
      final callback = tester.widget<ElevatedButton>(button()).onPressed!;
      auth.change(owner);
      callback();
      await tester.pump();
      expect(auth.deletes, 0);
      auth.deleted.complete(false);
      await tester.pumpAndSettle();
    });
    testWidgets('deletion pending $owner cannot redirect to login',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth);
      await submit(tester);
      auth.change(owner);
      auth.deleted.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Login fixture'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
    });
  }
  testWidgets('deletion revoking acknowledgement refuses captured action',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await acknowledge(tester);
    final callback = tester.widget<ElevatedButton>(button()).onPressed!;
    tester
        .widget<CheckboxListTile>(find.byType(CheckboxListTile))
        .onChanged!(false);
    callback();
    await tester.pump();
    expect(auth.deletes, 0);
    auth.deleted.complete(false);
    await tester.pumpAndSettle();
  });
  testWidgets('deletion captured duplicate issues only one command',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await acknowledge(tester);
    final callback = tester.widget<ElevatedButton>(button()).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(auth.deletes, 1);
    auth.deleted.complete(false);
    await tester.pumpAndSettle();
  });
  testWidgets('deletion refusal never renders raw provider detail',
      (tester) async {
    final auth = DeletionFormAuth()..code = 'failed-precondition';
    await mount(tester, auth);
    await submit(tester);
    auth.deleted.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
    expect(find.textContaining('Resolve open orders'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(button()).onPressed, isNotNull);
  });
  testWidgets('deletion foreign then signedout cannot confirm original action',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.change('owner_b');
    await tester.pump();
    auth.signOutFixture();
    auth.deleted.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Login fixture'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
  });
  testWidgets('deletion overlaid route survives confirmed own signout',
      (tester) async {
    final auth = DeletionFormAuth();
    final nav = GlobalKey<NavigatorState>();
    await mount(tester, auth, nav: nav);
    await submit(tester);
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Overlay fixture'))));
    await tester.pumpAndSettle();
    auth.signOutFixture();
    auth.deleted.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Overlay fixture'), findsOneWidget);
    expect(find.text('Login fixture'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('deletion phone disclosure wraps in dark $dark',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth, dark: dark);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    testWidgets('deletion confirmed own signout reaches login in dark $dark',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth, dark: dark);
      expect(tester.widget<ElevatedButton>(button()).onPressed, isNull);
      await submit(tester);
      expect(auth.deletes, 1);
      auth.signOutFixture();
      await tester.pump();
      auth.deleted.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Login fixture'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('deletion false signedout result expires old acknowledgement',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.signOutFixture();
    auth.deleted.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Login fixture'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });
  testWidgets('deletion confirmed unchanged opening SDK owner reaches login',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.deleted.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Login fixture'), findsOneWidget);
  });
  for (final throws in [false, true]) {
    testWidgets(
        'deletion generic failure throws $throws uses static retry copy',
        (tester) async {
      final auth = DeletionFormAuth();
      await mount(tester, auth);
      await submit(tester);
      if (throws) {
        auth.deleted.completeError(StateError('unsafe fixture detail'));
      } else {
        auth.deleted.complete(false);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
      expect(find.text('Could not confirm account deletion. Please try again.'),
          findsOneWidget);
      expect(tester.widget<ElevatedButton>(button()).onPressed, isNotNull);
    });
  }
  testWidgets('deletion disposed pending result does not navigate',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    await submit(tester);
    await tester.pumpWidget(const SizedBox());
    auth.signOutFixture();
    auth.deleted.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(auth.deletes, 1);
  });
  testWidgets('deletion unsigned opening cannot show acknowledgement',
      (tester) async {
    final auth = DeletionFormAuth()..owner = null;
    auth.signedOut = true;
    await mount(tester, auth);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(auth.deletes, 0);
  });
  testWidgets('deletion captured checkbox cannot acknowledge a renewed owner',
      (tester) async {
    final auth = DeletionFormAuth();
    await mount(tester, auth);
    final callback = tester
        .widget<CheckboxListTile>(find.byType(CheckboxListTile))
        .onChanged!;
    auth.change('owner_a');
    callback(true);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(auth.deletes, 0);
  });
  testWidgets('deletion replacement provider blocks old pending success',
      (tester) async {
    final old = DeletionFormAuth();
    final replacement = DeletionFormAuth();
    final notifier = ValueNotifier<DeletionFormAuth>(old);
    await tester.pumpWidget(ValueListenableBuilder<DeletionFormAuth>(
        valueListenable: notifier,
        builder: (_, auth, child) => ChangeNotifierProvider<AuthProvider>.value(
            value: auth, child: child),
        child: MaterialApp(routes: {
          '/login': (_) => const Scaffold(body: Text('Login fixture'))
        }, home: const DeleteAccountScreen())));
    await tester.pumpAndSettle();
    await submit(tester);
    notifier.value = replacement;
    await tester.pump();
    old.signOutFixture();
    old.deleted.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Login fixture'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(replacement.deletes, 0);
    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });
}

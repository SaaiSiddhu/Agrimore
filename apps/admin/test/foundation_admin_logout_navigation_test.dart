@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:agrimore_admin/app/themes/admin_theme.dart';
import 'package:agrimore_admin/screens/admin/settings/admin_settings_screen.dart';
import 'package:agrimore_admin/screens/admin/admin_shell.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// Official local initialization fixture; no account/provider operations.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LogoutAuth extends ChangeNotifier implements AuthProvider {
  String? owner = 'owner_a';
  String role = 'admin';
  int epoch = 1;
  final reply = Completer<void>();
  final requests = <String?>[];
  @override
  UserModel? get currentUser => owner == null
      ? null
      : UserModel(
          uid: owner!,
          email: 'fixture@example.invalid',
          name: 'Admin fixture',
          role: role,
          createdAt: DateTime(2026));
  @override
  bool get isLoggedIn => owner != null;
  @override
  bool get isAdmin => owner != null && role == 'admin';
  @override
  bool get isInitializing => false;
  @override
  int get sessionVersion => epoch;
  @override
  bool isSessionCurrent(String uid, int version) =>
      owner == uid && epoch == version;
  @override
  bool get hasSignedOutSession => owner == null;
  @override
  String? get error => 'PRIVATE fixture detail';
  @override
  Future<void> signOut() {
    requests.add(owner);
    return reply.future;
  }

  void change(String? uid) {
    owner = uid;
    epoch++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  late GoRouter router;
  late LogoutAuth auth;
  late ValueNotifier<AuthProvider> holder;
  Future<void> mount(WidgetTester tester, String screen,
      {bool dark = false, String role = 'admin'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth = LogoutAuth()..role = role;
    holder = ValueNotifier<AuthProvider>(auth);
    router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
          path: '/home',
          builder: (_, __) => screen == 'settings'
              ? const AdminSettingsScreen()
              : const AdminShell(
                  currentPath: '/dashboard',
                  child: Center(child: Text('Current destination')))),
      GoRoute(
          path: '/auth',
          builder: (_, __) => const Scaffold(body: Text('Auth destination'))),
      GoRoute(
          path: '/other',
          builder: (_, __) => const Scaffold(body: Text('Other destination'))),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      router.dispose();
      holder.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
        valueListenable: holder,
        builder: (_, provider, __) =>
            ChangeNotifierProvider<AuthProvider>.value(
                value: provider,
                child: MaterialApp.router(
                    theme: dark ? AdminTheme.darkTheme : AdminTheme.lightTheme,
                    routerConfig: router))));
    if (role != 'admin') {
      await tester.pump();
      await tester.pump();
      return;
    }
    await tester.pumpAndSettle();
    if (screen == 'shell') {
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Logout').first);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Logout').first);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Logout')));
    await tester.pumpAndSettle();
  }

  for (final screen in ['settings', 'shell']) {
    for (final dark in [false, true]) {
      testWidgets('$screen current confirmed logout dark $dark',
          (tester) async {
        await mount(tester, screen, dark: dark);
        await open(tester);
        await confirm(tester);
        expect(auth.requests, ['owner_a']);
        auth.change(null);
        auth.reply.complete();
        await tester.pumpAndSettle();
        expect(find.text('Auth destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    for (final uid in <String?>['owner_b', 'owner_a', null]) {
      testWidgets('$screen stale confirmation $uid refuses dispatch',
          (tester) async {
        await mount(tester, screen);
        await open(tester);
        auth.change(uid);
        await tester.pump();
        if (find
            .widgetWithText(ElevatedButton, 'Logout')
            .evaluate()
            .isNotEmpty) {
          await confirm(tester);
        }
        expect(auth.requests, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
    for (final failure in [false, true]) {
      testWidgets(
          '$screen newer admin ignores delayed ${failure ? 'failure' : 'success'}',
          (tester) async {
        await mount(tester, screen);
        await open(tester);
        await confirm(tester);
        auth.change('owner_b');
        await tester.pump();
        if (failure) {
          auth.reply.completeError(StateError('PRIVATE fixture detail'));
        } else {
          auth.reply.complete();
        }
        await tester.pumpAndSettle();
        expect(find.text('Auth destination'), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
        '$screen duplicate callers keep one confirmation and one dispatch',
        (tester) async {
      await mount(tester, screen);
      final VoidCallback callback = screen == 'settings'
          ? tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Logout'))
              .onPressed!
          : tester
              .widget<ListTile>(find.widgetWithText(ListTile, 'Logout'))
              .onTap!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await confirm(tester);
      expect(auth.requests, ['owner_a']);
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      auth.reply.complete();
      await tester.pumpAndSettle();
    });
    testWidgets('$screen cancel remains usable without dispatch',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(auth.requests, isEmpty);
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
    testWidgets('$screen renewed same account ignores old completion',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      await confirm(tester);
      auth.change('owner_a');
      auth.reply.complete();
      await tester.pumpAndSettle();
      expect(find.text('Auth destination'), findsNothing);
      expect(find.text('Unable to sign out. Please try again.'), findsNothing);
    });
    testWidgets('$screen overlay receives no old result or pop',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      await confirm(tester);
      router.routerDelegate.navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('Overlay destination'))));
      await tester.pumpAndSettle();
      auth.reply.complete();
      await tester.pumpAndSettle();
      expect(find.text('Overlay destination'), findsOneWidget);
      expect(find.text('Unable to sign out. Please try again.'), findsNothing);
    });
    testWidgets('$screen unconfirmed logout preserves route', (tester) async {
      await mount(tester, screen);
      await open(tester);
      await confirm(tester);
      auth.reply.complete();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('Auth destination'), findsNothing);
    });
    testWidgets('$screen current failure displays static safe copy',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      await confirm(tester);
      auth.reply.completeError(StateError('PRIVATE fixture detail'));
      await tester.pumpAndSettle();
      expect(
          find.text('Unable to sign out. Please try again.'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(tester.takeException(), isNull);
    });
    testWidgets('$screen provider replacement refuses old confirmation',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      final replacement = LogoutAuth();
      holder.value = replacement;
      await tester.pump();
      await confirm(tester);
      expect(auth.requests, isEmpty);
      expect(replacement.requests, isEmpty);
      replacement.dispose();
    });
    testWidgets('$screen navigation away before late result stays on new route',
        (tester) async {
      await mount(tester, screen);
      await open(tester);
      await confirm(tester);
      router.go('/other');
      await tester.pumpAndSettle();
      auth.reply.complete();
      await tester.pumpAndSettle();
      expect(find.text('Other destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('shell pending refusal never redirects a renewed admin',
      (tester) async {
    await mount(tester, 'shell', role: 'user');
    expect(auth.requests, ['owner_a']);
    auth.role = 'admin';
    auth.change('owner_b');
    await tester.pump();
    auth.reply.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text('Auth destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shell pending refusal never redirects replacement provider',
      (tester) async {
    await mount(tester, 'shell', role: 'user');
    expect(auth.requests, ['owner_a']);
    final replacement = LogoutAuth();
    holder.value = replacement;
    await tester.pump();
    auth.reply.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(replacement.requests, isEmpty);
    replacement.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('shell current non-admin refusal still routes to authentication', (tester) async {
    await mount(tester, 'shell', role: 'user');
    expect(auth.requests, ['owner_a']); auth.change(null); auth.reply.complete();
    await tester.pumpAndSettle(); expect(find.text('Auth destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}

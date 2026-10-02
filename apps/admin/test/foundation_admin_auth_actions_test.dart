@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:agrimore_admin/app/themes/admin_theme.dart';
import 'package:agrimore_admin/screens/auth/auth_screen.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Official local platform fixture; no device persistence.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class PageAuth extends ChangeNotifier implements AuthProvider {
  String? owner;
  int epoch = 1;
  String? message = 'PRIVATE fixture provider detail';
  final reply = Completer<bool>();
  final calls = <String>[];
  final rememberChoices = <bool>[];
  String? password;
  int listenerBalance = 0;
  @override
  void addListener(VoidCallback listener) {
    listenerBalance++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerBalance--;
    super.removeListener(listener);
  }

  @override
  int get sessionVersion => epoch;
  @override
  String? get userUid => owner;
  @override
  bool get isAdmin => owner != null;
  @override
  bool get isLoading => false;
  @override
  bool get isInitializing => false;
  @override
  bool get isLocked => false;
  @override
  bool get hasSignedOutSession => owner == null;
  @override
  String? get error => message;
  @override
  UserModel? get currentUser => owner == null
      ? null
      : UserModel(
          uid: owner!,
          email: 'fixture@example.invalid',
          name: 'Fixture',
          role: 'admin',
          createdAt: DateTime(2026));
  @override
  bool isSessionCurrent(String uid, int version) =>
      owner == uid && epoch == version;
  @override
  void setRememberMe(bool value) {
    rememberChoices.add(value);
  }

  @override
  Future<bool> signInWithEmail(
      {required String email, required String password}) {
    calls.add('email');
    this.password = password;
    return reply.future;
  }

  @override
  Future<bool> signInWithGoogle() {
    calls.add('google');
    return reply.future;
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) {
    calls.add('reset');
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

class _PendingPreferences extends SharedPreferencesStorePlatform {
  final reply = Completer<Map<String, Object>>();
  @override
  Future<Map<String, Object>> getAll() => reply.future;
  @override
  Future<bool> setValue(String type, String key, Object value) async => true;
  @override
  Future<bool> clear() async => true;
  @override
  Future<bool> remove(String key) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await loader.load();
  });
  late PageAuth auth;
  late ValueNotifier<AuthProvider> holder;
  late GoRouter router;
  late List<PageAuth> providers;
  Future<void> mount(WidgetTester tester,
      {bool dark = false,
      bool desktop = false,
      void Function()? configurePreferences}) async {
    SharedPreferences.setMockInitialValues({});
    configurePreferences?.call();
    tester.view.physicalSize =
        desktop ? const Size(1280, 900) : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth = PageAuth();
    providers = [auth];
    holder = ValueNotifier<AuthProvider>(auth);
    router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const AuthScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (_, __) =>
              const Scaffold(body: Text('Dashboard destination'))),
      GoRoute(
          path: '/other',
          builder: (_, __) => const Scaffold(body: Text('Other destination'))),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      router.dispose();
      holder.dispose();
      for (final provider in providers) {
        provider.dispose();
      }
    });
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
        valueListenable: holder,
        builder: (_, provider, __) => ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: MaterialApp.router(
                theme: (dark ? AdminTheme.darkTheme : AdminTheme.lightTheme).copyWith(
                    elevatedButtonTheme: ElevatedButtonThemeData(
                        style: (dark ? AdminTheme.darkTheme : AdminTheme.lightTheme)
                            .elevatedButtonTheme
                            .style!
                            .copyWith(
                                textStyle: const WidgetStatePropertyAll(
                                    TextStyle(fontFamily: 'NotoSans', fontSize: 15, fontWeight: FontWeight.w600)))),
                    outlinedButtonTheme: OutlinedButtonThemeData(style: (dark ? AdminTheme.darkTheme : AdminTheme.lightTheme).outlinedButtonTheme.style!.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'NotoSans', fontSize: 15, fontWeight: FontWeight.w600)))),
                    textTheme: (dark ? AdminTheme.darkTheme : AdminTheme.lightTheme).textTheme.apply(fontFamily: 'NotoSans'),
                    primaryTextTheme: (dark ? AdminTheme.darkTheme : AdminTheme.lightTheme).primaryTextTheme.apply(fontFamily: 'NotoSans')),
                routerConfig: router))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'fixture@example.invalid');
    await tester.enterText(
        find.byType(TextFormField).last, ' fixture-password ');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  VoidCallback callback(WidgetTester tester, String action) {
    if (action == 'email') {
      return tester
          .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Sign In to Dashboard'))
          .onPressed!;
    }
    if (action == 'google') {
      return tester
          .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Continue with Google'))
          .onPressed!;
    }
    final gesture = find
        .ancestor(
            of: find.text('Forgot password?'),
            matching: find.byType(GestureDetector))
        .first;
    return tester.widget<GestureDetector>(gesture).onTap!;
  }

  Future<void> start(WidgetTester tester, String action) async {
    callback(tester, action)();
    await tester.pump();
    expect(auth.calls, [action]);
  }

  Future<void> finish(WidgetTester tester, String action,
      {bool failed = false}) async {
    if (failed) {
      auth.reply.completeError(StateError('PRIVATE fixture exception'));
    } else {
      auth.reply.complete(true);
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  for (final action in ['email', 'google', 'reset']) {
    for (final dark in [false, true]) {
      for (final desktop in [false, true]) {
        testWidgets(
            '$action confirmed dark$dark desktop$desktop remains usable',
            (tester) async {
          await mount(tester, dark: dark, desktop: desktop);
          await start(tester, action);
          if (action != 'reset') {
            auth.change('owner_a');
          }
          await finish(tester, action);
          if (action == 'reset') {
            expect(router.routeInformationProvider.value.uri.path, '/home');
            expect(find.text('Check your email for a password reset link.'),
                findsOneWidget);
          } else {
            expect(find.text('Dashboard destination'), findsOneWidget);
          }
        });
      }
    }
    for (final scenario in [
      'switch',
      'renew',
      'replacement',
      'leave',
      'dispose',
      'overlay'
    ]) {
      for (final failed in [false, true]) {
        testWidgets(
            '$action $scenario rejects late ${failed ? 'exception' : 'success'}',
            (tester) async {
          await mount(tester);
          await start(tester, action);
          if (action != 'reset') {
            auth.change('owner_a');
            await tester.pump();
          }
          switch (scenario) {
            case 'switch':
              auth.change('owner_b');
            case 'renew':
              auth.change(auth.owner);
            case 'replacement':
              final replacement = PageAuth()..change('owner_b');
              providers.add(replacement);
              holder.value = replacement;
            case 'leave':
              router.go('/other');
            case 'dispose':
              await tester.pumpWidget(const SizedBox());
            case 'overlay':
              unawaited(showDialog<void>(
                  context: tester.element(find.byType(AuthScreen)),
                  builder: (_) =>
                      const AlertDialog(content: Text('Current overlay'))));
          }
          await tester.pump();
          await finish(tester, action, failed: failed);
          expect(find.text('Dashboard destination'), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(find.text('Check your email for a password reset link.'),
              findsNothing);
          if (scenario == 'overlay') {
            expect(find.text('Current overlay'), findsOneWidget);
          }
          if (scenario == 'replacement') {
            expect(
                tester
                    .widget<ElevatedButton>(find.byType(ElevatedButton))
                    .onPressed,
                isNotNull);
          }
        });
      }
    }
    for (final failed in [false, true]) {
      testWidgets('$action owned failure uses safe feedback', (tester) async {
        await mount(tester);
        await start(tester, action);
        if (failed) {
          auth.reply.completeError(StateError('PRIVATE fixture exception'));
        } else {
          auth.reply.complete(false);
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(
            find.text(action == 'reset'
                ? 'Failed to send reset email. Please try again.'
                : 'Sign in failed. Please try again.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final first in ['email', 'google', 'reset']) {
    for (final second in ['email', 'google', 'reset']) {
      testWidgets('duplicate $first/$second dispatches once', (tester) async {
        await mount(tester);
        final one = callback(tester, first);
        final two = callback(tester, second);
        one();
        two();
        await tester.pump();
        final calls = List<String>.of(auth.calls);
        auth.reply.complete(false);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, [first]);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final action in ['email', 'google', 'reset']) {
    testWidgets(
        '$action replacement permits fresh action and keeps its busy state',
        (tester) async {
      await mount(tester);
      await start(tester, action);
      final replacement = PageAuth();
      providers.add(replacement);
      holder.value = replacement;
      await tester.pump();
      callback(tester, action)();
      await tester.pump();
      expect(replacement.calls, [action]);
      auth.reply.complete(false);
      await tester.pump();
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      expect(find.text('Sign in failed. Please try again.'), findsNothing);
      replacement.reply.complete(false);
      await tester.pump();
      await tester.pump();
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        '$action covered route completion releases busy state for retry',
        (tester) async {
      await mount(tester);
      await start(tester, action);
      unawaited(showDialog<void>(
          context: tester.element(find.byType(AuthScreen)),
          builder: (_) => const AlertDialog(content: Text('Current overlay'))));
      await tester.pump();
      auth.reply.complete(false);
      await tester.pump();
      Navigator.of(tester.element(find.text('Current overlay'))).pop();
      await tester.pumpAndSettle();
      callback(tester, action)();
      await tester.pump();
      expect(auth.calls, [action, action]);
      expect(tester.takeException(), isNull);
    });
  }
  for (final action in ['email', 'google']) {
    testWidgets('$action temporary session listener releases after completion',
        (tester) async {
      await mount(tester);
      final listeners = auth.listenerBalance;
      await start(tester, action);
      expect(auth.listenerBalance, listeners + 1);
      auth.reply.complete(false);
      await tester.pump();
      expect(auth.listenerBalance, listeners);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('late stored preferences preserve typed email and edited choice',
      (tester) async {
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _PendingPreferences();
    try {
      await mount(tester,
          configurePreferences: () =>
              SharedPreferencesStorePlatform.instance = store);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      store.reply.complete({
        'flutter.remember_email': 'old@example.invalid',
        'flutter.remember_me': false
      });
      await tester.pump();
      await tester.pump();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'fixture@example.invalid');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      if (!store.reply.isCompleted) {
        store.reply.complete({});
      }
      SharedPreferencesStorePlatform.instance = previous;
    }
  });
  testWidgets(
      'email preserves password whitespace and supplies remember choice',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await start(tester, 'email');
    expect(auth.password, ' fixture-password ');
    expect(auth.rememberChoices, [true]);
    auth.change('owner_a');
    await finish(tester, 'email');
  });
  for (final action in ['email', 'google']) {
    testWidgets('$action owned nonadmin refusal remains visible',
        (tester) async {
      await mount(tester);
      await start(tester, action);
      auth.message = 'Access denied. You are not an admin.';
      auth.change(null);
      auth.reply.complete(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
          find.text('Access denied. This account cannot access the admin app.'),
          findsOneWidget);
      expect(find.text('Dashboard destination'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$action unconfirmed admin cannot navigate', (tester) async {
      await mount(tester);
      await start(tester, action);
      await finish(tester, action);
      expect(find.text('Dashboard destination'), findsNothing);
    });
  }
}

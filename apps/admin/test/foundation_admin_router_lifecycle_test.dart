@TestOn('vm')
library;

import 'package:agrimore_admin/app/app.dart';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:agrimore_admin/providers/theme_provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  bool initializing = false;
  int reads = 0;
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
  bool get isLoggedIn {
    reads++;
    return false;
  }

  @override
  bool get isAdmin => false;
  @override
  bool get isInitializing => initializing;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  String? get userUid => null;
  @override
  UserModel? get currentUser => null;
  @override
  int get sessionVersion => 1;
  @override
  bool get isLocked => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Theme extends ChangeNotifier implements ThemeProvider {
  bool dark = false;
  @override
  bool get isDarkMode => dark;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Replace only the test engine's placeholder metrics with bundled font.
    final font = FontLoader('Ahem')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await font.load();
  });
  late _Auth auth;
  late _Theme theme;
  late ValueNotifier<AuthProvider> holder;
  late List<_Auth> providers;
  late List<(GoRouter, _Auth)> routers;
  Future<void> mount(WidgetTester tester, {bool dark = false}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth = _Auth();
    theme = _Theme()..dark = dark;
    providers = [auth];
    routers = [];
    holder = ValueNotifier<AuthProvider>(auth);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
      // Original faulty root leaves its router alive. Release only that fixture
      // resource after the test's leak assertion; never double-dispose a fix.
      for (final (router, owner) in routers) {
        if (owner.listenerBalance > 0) router.dispose();
      }
      holder.dispose();
      theme.dispose();
      for (final provider in providers) {
        provider.dispose();
      }
    });
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
      valueListenable: holder,
      builder: (_, value, __) => MultiProvider(providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: value),
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
      ], child: const AdminApp()),
    ));
    await tester.pump();
  }

  GoRouter rootRouter(WidgetTester tester) {
    final router = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .routerConfig! as GoRouter;
    if (!routers.any((entry) => identical(entry.$1, router))) {
      routers.add((router, holder.value as _Auth));
    }
    return router;
  }

  Future<void> replace(WidgetTester tester) async {
    final next = _Auth();
    providers.add(next);
    holder.value = next;
    await tester.pump();
    await tester.pump();
    rootRouter(tester);
  }

  void rootTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      }
    });
  }

  for (final dark in [false, true]) {
    rootTest(
        'root $dark provider replacement rebuilds router and releases retired listeners',
        (tester) async {
      await mount(tester, dark: dark);
      final old = rootRouter(tester);
      await replace(tester);
      final next = rootRouter(tester);
      expect(next, isNot(same(old)));
      expect(auth.listenerBalance, 0);
      next.go('/auth');
      await tester.pump();
      await tester.pump();
      final openingReads = auth.reads;
      final fresh = holder.value as _Auth;
      final freshReads = fresh.reads;
      fresh.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(fresh.reads, greaterThan(freshReads));
      expect(auth.reads, openingReads);
    });
    rootTest(
        'root $dark ordinary auth notification preserves router and destination',
        (tester) async {
      await mount(tester, dark: dark);
      final router = rootRouter(tester);
      router.go('/auth');
      await tester.pump();
      await tester.pump();
      auth.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(rootRouter(tester), same(router));
      expect(router.routeInformationProvider.value.uri.path, '/auth');
    });
    rootTest('root $dark theme notification preserves router', (tester) async {
      await mount(tester, dark: dark);
      final router = rootRouter(tester);
      theme.dark = !dark;
      theme.notifyListeners();
      await tester.pump();
      expect(rootRouter(tester), same(router));
    });
    rootTest('root $dark removal releases router listeners', (tester) async {
      await mount(tester, dark: dark);
      rootRouter(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(auth.listenerBalance, 0);
    });
    rootTest(
        'root $dark repeated provider replacements release every old owner',
        (tester) async {
      await mount(tester, dark: dark);
      rootRouter(tester);
      for (var i = 0; i < 3; i++) {
        await replace(tester);
        expect(
            providers.take(providers.length - 1).map((p) => p.listenerBalance),
            everyElement(0));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(providers.map((p) => p.listenerBalance), everyElement(0));
    });
  }

  rootTest('current splash initialization completion remains usable',
      (tester) async {
    await mount(tester);
    final router = rootRouter(tester);
    auth.initializing = true;
    final splash =
        tester.widget<PremiumSplashScreen>(find.byType(PremiumSplashScreen));
    final context = tester.element(find.byType(PremiumSplashScreen));
    final result = splash.onNavigation!(context);
    auth.initializing = false;
    await tester.pump(const Duration(milliseconds: 100));
    await result;
    await tester.pump();
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/auth');
  });
  rootTest('covered splash cannot navigate after initialization completes',
      (tester) async {
    await mount(tester);
    final router = rootRouter(tester);
    auth.initializing = true;
    final splash =
        tester.widget<PremiumSplashScreen>(find.byType(PremiumSplashScreen));
    final context = tester.element(find.byType(PremiumSplashScreen));
    final result = splash.onNavigation!(context);
    final overlay = DialogRoute<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Fixture overlay')));
    Navigator.of(context).push(overlay);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ModalRoute.of(context)!.isCurrent, isFalse);
    auth.initializing = false;
    await tester.pump(const Duration(milliseconds: 100));
    await result;
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/splash');
  });
  rootTest('replaced provider cannot complete old splash navigation',
      (tester) async {
    await mount(tester);
    rootRouter(tester);
    auth.initializing = true;
    final splash =
        tester.widget<PremiumSplashScreen>(find.byType(PremiumSplashScreen));
    final context = tester.element(find.byType(PremiumSplashScreen));
    final result = splash.onNavigation!(context);
    await replace(tester);
    auth.initializing = false;
    await tester.pump(const Duration(milliseconds: 100));
    await result;
    await tester.pump();
    expect(
        rootRouter(tester).routeInformationProvider.value.uri.path, '/splash');
  });
  rootTest('disposed splash completion is inert', (tester) async {
    await mount(tester);
    rootRouter(tester);
    auth.initializing = true;
    final splash =
        tester.widget<PremiumSplashScreen>(find.byType(PremiumSplashScreen));
    final context = tester.element(find.byType(PremiumSplashScreen));
    final result = splash.onNavigation!(context);
    await tester.pumpWidget(const SizedBox());
    auth.initializing = false;
    await tester.pump(const Duration(milliseconds: 100));
    await result;
    expect(tester.takeException(), isNull);
  });
}

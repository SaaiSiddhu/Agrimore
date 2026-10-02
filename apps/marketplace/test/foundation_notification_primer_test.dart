@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/auth/enable_notifications_screen.dart';
import 'package:agrimore_marketplace/screens/auth/post_auth_router.dart';
// Official cached native plugin registration; no additional dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:firebase_core/firebase_core.dart';
// Official native fixture; every permission request is intercepted locally.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  String? uid = 'owner_a';
  int epoch = 1;
  bool observed = true;
  bool profile = true;
  bool incomplete = false;
  @override
  String? get sessionOwner => observed ? uid : null;
  @override
  String? get userUid => profile ? uid : null;
  @override
  int get sessionVersion => epoch;
  @override
  bool isSessionCurrent(String owner, int version) =>
      observed && uid == owner && epoch == version;
  @override
  bool get needsProfileCompletion => incomplete;
  @override
  UserModel? get currentUser => !profile || uid == null
      ? null
      : UserModel(
          uid: uid!,
          role: 'user',
          name: 'Fixture',
          phone: '+919000000000',
          email: 'fixture@example.invalid',
          createdAt: DateTime(2026));
  void change(String? owner) {
    uid = owner;
    epoch++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Preferences extends SharedPreferencesStorePlatform {
  final reads = Completer<Map<String, Object>>();
  final firstWrite = Completer<bool>();
  final writes = <(String, Object)>[];
  bool holdRead = false;
  bool holdWrite = false;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<Map<String, Object>> getAll() async {
    if (failRead) throw StateError('PRIVATE preference read');
    return holdRead ? await reads.future : <String, Object>{};
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failWrite) throw StateError('PRIVATE preference write');
    writes.add((key, value));
    return holdWrite && writes.length == 1 ? await firstWrite.future : true;
  }

  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> clear() async => true;
}

Map<String, int> _settings(int status) => {
      'authorizationStatus': status,
      'alert': 1,
      'announcement': 0,
      'badge': 1,
      'carPlay': 0,
      'lockScreen': 1,
      'notificationCenter': 1,
      'showPreviews': 1,
      'sound': 1,
      'timeSensitive': 1,
      'criticalAlert': 0,
      'providesAppNotificationSettings': 0
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    final font = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await font.load();
  });
  late _Auth auth;
  late List<_Auth> providers;
  late ValueNotifier<AuthProvider> holder;
  late GlobalKey<NavigatorState> navigator;
  late _Preferences preferences;
  late SharedPreferencesStorePlatform previousPreferences;
  late List<Completer<Map<String, int>>> permissions;
  late List<String> nativeCalls;
  bool localReady = true;
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    previousPreferences = SharedPreferencesStorePlatform.instance;

    permissions = [];
    nativeCalls = [];
    localReady = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_messaging'),
            (call) async {
      nativeCalls.add(call.method);
      if (call.method == 'Messaging#requestPermission') {
        final reply = Completer<Map<String, int>>();
        permissions.add(reply);
        return reply.future;
      }
      if (call.method == 'Messaging#getToken') return {'token': null};
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
      nativeCalls.add('local:${call.method}');
      return call.method == 'initialize' ? localReady : null;
    });
  });
  tearDown(() {
    SharedPreferencesStorePlatform.instance = previousPreferences;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/firebase_messaging'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            null);
  });
  Future<void> mount(WidgetTester tester,
      {bool router = false,
      bool fresh = false,
      bool dark = false,
      bool desktop = false,
      String phone = '+919000000000'}) async {
    // Held futures must be created inside the widget test's fake-async zone.
    SharedPreferences.setMockInitialValues({});
    preferences = _Preferences();
    SharedPreferencesStorePlatform.instance = preferences;
    auth = _Auth();
    providers = [auth];
    holder = ValueNotifier<AuthProvider>(auth);
    navigator = GlobalKey<NavigatorState>();
    tester.view.physicalSize =
        desktop ? const Size(1280, 900) : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      holder.dispose();
      for (final p in providers) {
        p.dispose();
      }
    });
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
        valueListenable: holder,
        builder: (_, provider, __) =>
            ChangeNotifierProvider<AuthProvider>.value(
                value: provider,
                child: MaterialApp(
                    navigatorKey: navigator,
                    theme: theme.copyWith(
                        textTheme:
                            theme.textTheme.apply(fontFamily: 'NotoSans')),
                    home: router
                        ? Scaffold(
                            body: Builder(
                                builder: (context) => TextButton(
                                    onPressed: () =>
                                        PostAuthRouter.routeAfterAuth(context,
                                            phone: phone,
                                            isNewUser: fresh),
                                    child: const Text('Route owned login'))))
                        : EnableNotificationsScreen(
                            isNewUser: fresh, phone: phone),
                    routes: {
                      '/main': (_) =>
                          const Scaffold(body: Text('Main destination')),
                      '/complete-profile': (_) =>
                          const Scaffold(body: Text('Profile destination')),
                      '/onboarding-address': (_) =>
                          const Scaffold(body: Text('Address destination')),
                      '/other': (_) =>
                          const Scaffold(body: Text('Other destination'))
                    }))));
    await tester.pumpAndSettle();
    tester
        .element(
            find.byType(router ? TextButton : EnableNotificationsScreen).first)
        .read<AuthProvider>();
  }

  void screenTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final reply in permissions) {
          if (!reply.isCompleted) {
            reply.complete(_settings(0));
          }
        }
        if (!preferences.reads.isCompleted) {
          preferences.reads.complete({});
        }
        if (!preferences.firstWrite.isCompleted) {
          preferences.firstWrite.complete(true);
        }
        await drain(tester);
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  VoidCallback action(WidgetTester tester, String name) => name == 'enable'
      ? tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!
      : tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed!;
  Future<void> invalidate(WidgetTester tester, String kind) async {
    switch (kind) {
      case 'switch':
        auth.change('owner_b');
      case 'renew':
        auth.change(auth.uid);
      case 'signout':
        auth.change(null);
      case 'replace':
        final next = _Auth();
        providers.add(next);
        holder.value = next;
      case 'leave':
        navigator.currentState!.pushReplacementNamed('/other');
      case 'cover':
        navigator.currentState!.push(DialogRoute<void>(
            context: tester.element(find.byType(EnableNotificationsScreen)),
            builder: (_) =>
                const AlertDialog(content: Text('Fixture overlay'))));
      case 'dispose':
        await tester.pumpWidget(const SizedBox());
    }
    await drain(tester);
  }

  for (final which in ['enable', 'notnow']) {
    for (final boundary in ['permission', 'read', 'write']) {
      if (which == 'notnow' && boundary == 'permission') {
        continue;
      }
      for (final kind in [
        'switch',
        'renew',
        'signout',
        'replace',
        'leave',
        'cover',
        'dispose'
      ]) {
        screenTest('$which held $boundary $kind drops old flags and route',
            (tester) async {
          await mount(tester);
          preferences.holdRead = boundary == 'read';
          preferences.holdWrite = boundary == 'write';
          action(tester, which)();
          await drain(tester);
          if (which == 'enable' && boundary != 'permission') {
            expect(permissions, hasLength(1));
            permissions.single.complete(_settings(0));
            await drain(tester);
          }
          final writes = preferences.writes.length;
          expect(writes, boundary == 'write' ? 1 : 0);
          await invalidate(tester, kind);
          if (boundary == 'permission') {
            permissions.single.complete(_settings(0));
          }
          if (boundary == 'read') {
            preferences.reads.complete({});
          }
          if (boundary == 'write') {
            preferences.firstWrite.complete(true);
          }
          await drain(tester);
          expect(preferences.writes.length, writes);
          expect(find.text('Main destination'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final first in ['enable', 'notnow']) {
    for (final second in ['enable', 'notnow']) {
      for (final boundary in ['read', 'write']) {
        screenTest(
            'duplicate $first/$second held $boundary dispatches one primer action',
            (tester) async {
          await mount(tester);
          preferences.holdRead = boundary == 'read';
          preferences.holdWrite = boundary == 'write';
          final again = action(tester, second);
          action(tester, first)();
          await drain(tester);
          if (first == 'enable' && boundary == 'write') {
            permissions.single.complete(_settings(0));
            await drain(tester);
          }
          again();
          await drain(tester);
          expect(permissions.length, first == 'enable' ? 1 : 0);
          if (first == 'enable' && boundary == 'read') {
            permissions.single.complete(_settings(0));
            await drain(tester);
          }
          if (boundary == 'read') {
            preferences.reads.complete({});
          } else {
            preferences.firstWrite.complete(true);
          }
          await drain(tester);
          expect(preferences.writes, hasLength(2));
          expect(find.text('Main destination'), findsOneWidget);
        });
      }
    }
  }
  for (final outcome in [
    'authorized',
    'denied',
    'provisional',
    'error',
    'localfailure',
    'notnow'
  ]) {
    for (final dark in [false, true]) {
      for (final desktop in [false, true]) {
        screenTest(
            'current $outcome dark$dark desktop$desktop preserves login and truthful flag',
            (tester) async {
          await mount(tester, dark: dark, desktop: desktop);
          localReady = outcome != 'localfailure';
          action(tester, outcome == 'notnow' ? 'notnow' : 'enable')();
          await drain(tester);
          if (outcome != 'notnow') {
            expect(permissions, hasLength(1));
            if (outcome == 'error') {
              permissions.single.completeError(
                  PlatformException(code: 'PRIVATE fixture permission'));
            } else {
              permissions.single.complete(
                  _settings(outcome == 'authorized' || outcome == 'localfailure'
                      ? 1
                      : outcome == 'provisional'
                          ? 2
                          : 0));
            }
          }
          await drain(tester);
          expect(find.text('Main destination'), findsOneWidget);
          expect(
              preferences.writes
                  .where((w) =>
                      w.$1.endsWith(StorageConstants.keyNotificationsEnabled))
                  .single
                  .$2,
              outcome == 'authorized');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final failure in ['read', 'write']) {
    screenTest(
        'current preference $failure failure does not block confirmed login',
        (tester) async {
      await mount(tester);
      preferences.failRead = failure == 'read';
      preferences.failWrite = failure == 'write';
      action(tester, 'notnow')();
      await drain(tester);
      expect(find.text('Main destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final missing in ['sdk', 'profile', 'observer', 'cover', 'dispose']) {
    screenTest('postauth refuses missing or stale $missing', (tester) async {
      await mount(tester, router: true);
      final routeAction = tester
          .widget<TextButton>(
              find.widgetWithText(TextButton, 'Route owned login'))
          .onPressed!;
      if (missing == 'sdk') {
        auth.uid = null;
      }
      if (missing == 'profile') {
        auth.profile = false;
      }
      if (missing == 'observer') {
        auth.observed = false;
      }
      if (missing == 'cover') {
        navigator.currentState!.push(DialogRoute<void>(
            context: tester.element(find.byType(TextButton)),
            builder: (_) =>
                const AlertDialog(content: Text('Router overlay'))));
        await drain(tester);
      }
      if (missing == 'dispose') {
        await tester.pumpWidget(const SizedBox());
      }
      routeAction();
      await drain(tester);
      expect(find.text('Main destination'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final fresh in [false, true]) {
    for (final incomplete in [false, true]) {
      screenTest(
          'postauth current fresh$fresh incomplete$incomplete preserves destination',
          (tester) async {
        await mount(tester, router: true, fresh: fresh);
        auth.incomplete = incomplete;
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Route owned login'))
            .onPressed!();
        await drain(tester);
        expect(
            find.text(incomplete
                ? 'Profile destination'
                : fresh
                    ? 'Address destination'
                    : 'Main destination'),
            findsOneWidget);
      });
    }
  }
  for (final missing in ['sdk', 'profile', 'observer']) {
    for (final which in ['enable', 'notnow']) {
      screenTest('primer missing $missing refuses $which before dispatch',
          (tester) async {
        await mount(tester);
        if (missing == 'sdk') {
          auth.uid = null;
        }
        if (missing == 'profile') {
          auth.profile = false;
        }
        if (missing == 'observer') {
          auth.observed = false;
        }
        action(tester, which)();
        await drain(tester);
        expect(permissions, isEmpty);
        expect(preferences.writes, isEmpty);
        expect(find.text('Main destination'), findsNothing);
      });
    }
  }
  for (final kind in [
    'switch',
    'renew',
    'signout',
    'replace',
    'leave',
    'cover',
    'dispose'
  ]) {
    screenTest('enable held permission $kind drops late failure',
        (tester) async {
      await mount(tester);
      action(tester, 'enable')();
      await drain(tester);
      await invalidate(tester, kind);
      permissions.single
          .completeError(PlatformException(code: 'PRIVATE permission detail'));
      await drain(tester);
      expect(preferences.writes, isEmpty);
      expect(find.text('Main destination'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final which in ['enable', 'notnow']) {
    screenTest('$which paused observer drops held read', (tester) async {
      await mount(tester);
      preferences.holdRead = true;
      action(tester, which)();
      await drain(tester);
      if (which == 'enable') {
        permissions.single.complete(_settings(0));
        await drain(tester);
      }
      auth.observed = false;
      auth.notifyListeners();
      await drain(tester);
      preferences.reads.complete({});
      await drain(tester);
      expect(preferences.writes, isEmpty);
      expect(find.text('Main destination'), findsNothing);
    });
  }
  for (final fresh in [false, true]) {
    for (final incomplete in [false, true]) {
      screenTest(
          'primer current fresh$fresh incomplete$incomplete preserves destination',
          (tester) async {
        await mount(tester, fresh: fresh);
        auth.incomplete = incomplete;
        action(tester, 'notnow')();
        await drain(tester);
        expect(
            find.text(incomplete
                ? 'Profile destination'
                : fresh
                    ? 'Address destination'
                    : 'Main destination'),
            findsOneWidget);
      });
    }
  }
  screenTest('shared startup retains Future void catchError compatibility',
      (tester) async {
    await mount(tester);
    bool recovered = false;
    final Future<void> startup =
        NotificationService.initialize().catchError((Object _) {
      recovered = true;
    });
    await drain(tester);
    permissions.single
        .completeError(PlatformException(code: 'PRIVATE startup detail'));
    await drain(tester);
    await startup;
    expect(recovered, isTrue);
    expect(preferences.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final router in [false, true]) {
    screenTest(
        'profile completion uses owned profile phone when caller empty router$router',
        (tester) async {
      await mount(tester, router: router, phone: '');
      auth.incomplete = true;
      if (router) {
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Route owned login'))
            .onPressed!();
      } else {
        action(tester, 'notnow')();
      }
      await drain(tester);
      final target = find.text('Profile destination');
      expect(target, findsOneWidget);
      expect(ModalRoute.of(tester.element(target))!.settings.arguments,
          {'phone': '+919000000000'});
    });
  }
}

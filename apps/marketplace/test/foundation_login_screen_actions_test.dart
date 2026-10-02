@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/auth/login_screen.dart';
import 'package:agrimore_marketplace/screens/auth/enable_notifications_screen.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Official local platform fixture; no device persistence.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final _pending = PendingGoogleIdentity(
    credential:
        const AuthCredential(providerId: 'fixture', signInMethod: 'fixture'),
    idToken: 'local-fixture');

class _Auth extends ChangeNotifier implements AuthProvider {
  String? owner;
  int epoch = 1;
  int listenerBalance = 0;
  bool newUser = false;
  String? message = 'PRIVATE fixture provider detail';
  String? code;
  final calls = <(String, Completer<Object?>)>[];
  @override
  void addListener(VoidCallback f) {
    listenerBalance++;
    super.addListener(f);
  }

  @override
  void removeListener(VoidCallback f) {
    listenerBalance--;
    super.removeListener(f);
  }

  @override
  String? get userUid => owner;
  @override
  String? get sessionOwner => owner;
  @override
  int get sessionVersion => epoch;
  @override
  bool get hasSignedOutSession => owner == null;
  @override
  bool get isLoggedIn => owner != null;
  @override
  bool get isLoading => false;
  @override
  bool get isInitializing => false;
  @override
  bool get isLocked => false;
  @override
  bool get isNewUser => newUser;
  @override
  bool get needsProfileCompletion => false;
  @override
  String? get error => message;
  @override
  String? get errorCode => code;
  @override
  UserModel? get currentUser => owner == null
      ? null
      : UserModel(
          uid: owner!,
          email: 'fixture@example.invalid',
          name: 'Fixture',
          role: 'user',
          createdAt: DateTime(2026));
  @override
  bool isSessionCurrent(String uid, int version) =>
      owner == uid && epoch == version;
  Future<T> request<T>(String method) {
    final reply = Completer<Object?>();
    calls.add((method, reply));
    return reply.future.then((v) => v as T);
  }

  @override
  Future<PhoneOtpSendResult?> sendPhoneOTP(String phone,
          {String channel = 'sms'}) =>
      request(channel == 'voice' ? 'voice' : 'send');
  @override
  Future<PendingGoogleIdentity?> acquireGoogleCredential() =>
      request('acquire');
  @override
  Future<GoogleIdentityResolution?> resolveGoogleIdentity(
          PendingGoogleIdentity identity) =>
      request('resolve');
  @override
  Future<bool> signInWithLinkedGoogle(PendingGoogleIdentity identity,
          {String? expectedUid}) =>
      request('linked');
  @override
  Future<bool> verifyPhoneOTP(
          {required String phone, required String otp, String? name}) =>
      request('verify');
  @override
  Future<bool> linkGoogleToCurrentUser(PendingGoogleIdentity identity) =>
      request('link');
  void change(String? uid) {
    owner = uid;
    epoch++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Preferences extends SharedPreferencesStorePlatform {
  final reply = Completer<Map<String, Object>>();
  final writes = <String>[];
  bool fail = false;
  @override
  Future<Map<String, Object>> getAll() {
    if (fail) {
      throw StateError('private cache detail');
    }
    return reply.future;
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes.add(key);
    return true;
  }

  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> clear() async => true;
}

Object? _value(String method) => switch (method) {
      'send' => PhoneOtpSendResult(userExists: true, channel: 'sms'),
      'voice' => PhoneOtpSendResult(userExists: true, channel: 'voice'),
      'acquire' => _pending,
      'resolve' =>
        GoogleIdentityResolution(linked: true, expectedUid: 'owner_a'),
      _ => false
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Ahem', 'NotoSans']) {
      final font = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
    }
  });
  late _Auth auth;
  late ValueNotifier<AuthProvider> holder;
  late List<_Auth> providers;
  late GlobalKey<NavigatorState> navigator;
  Future<void> mount(WidgetTester tester,
      {bool dark = false, bool desktop = false, bool primed = false}) async {
    SharedPreferences.setMockInitialValues({StorageConstants.keyNotificationsPrimed: primed});
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
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
        valueListenable: holder,
        builder: (_, p, __) => (ChangeNotifierProvider<AuthProvider>.value(
            value: p,
            child: MaterialApp(
                navigatorKey: navigator,
                theme:
                    (dark ? AppTheme.darkTheme : AppTheme.lightTheme).copyWith(
                  textTheme: (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                      .textTheme
                      .apply(fontFamily: 'NotoSans'),
                  primaryTextTheme:
                      (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                          .primaryTextTheme
                          .apply(fontFamily: 'NotoSans'),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                      style: ((dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                                  .elevatedButtonTheme
                                  .style ??
                              ElevatedButton.styleFrom())
                          .copyWith(
                              textStyle: const WidgetStatePropertyAll(TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)))),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                      style: ((dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                                  .outlinedButtonTheme
                                  .style ??
                              OutlinedButton.styleFrom())
                          .copyWith(
                              textStyle: const WidgetStatePropertyAll(TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)))),
                ),
                home: const LoginScreen(),
                routes: {
                  '/other': (_) =>
                      const Scaffold(body: Text('Other destination')),
                  '/main': (_) =>
                      const Scaffold(body: Text('Main destination')),
                  '/complete-profile': (_) =>
                      const Scaffold(body: Text('Profile destination')),
                  '/onboarding-address': (_) =>
                      const Scaffold(body: Text('Address destination'))
                })))));
    await tester.pumpAndSettle();
    tester.element(find.byType(LoginScreen)).read<AuthProvider>();
    await tester.enterText(find.byType(TextFormField), '9000000000');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  void screenTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final provider in providers) {
          for (final (method, reply) in provider.calls) {
            if (!reply.isCompleted) {
              reply.complete(_value(method));
            }
          }
        }
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    });
  }

  VoidCallback phone(WidgetTester t) => t
      .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'))
      .onPressed!;
  VoidCallback google(WidgetTester t) => t
      .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Continue with Google'))
      .onPressed!;
  VoidCallback resend(WidgetTester t) => t
      .widget<GestureDetector>(find
          .ancestor(
              of: find.textContaining("Didn't get the OTP?",
                  findRichText: true),
              matching: find.byType(GestureDetector))
          .first)
      .onTap!;
  VoidCallback voice(WidgetTester t) => t
      .widget<GestureDetector>(find
          .ancestor(
              of: find.text('Call me instead'),
              matching: find.byType(GestureDetector))
          .first)
      .onTap!;
  Future<void> otp(WidgetTester tester) async {
    phone(tester)();
    await tester.pump();
    auth.calls.last.$2
        .complete(PhoneOtpSendResult(userExists: true, channel: 'sms'));
    await tester.pumpAndSettle();
  }

  Future<void> verify(WidgetTester tester) async {
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
    }
    await tester.pump();
  }

  Future<void> prepare(WidgetTester tester, String action) async {
    if (['verify', 'resend', 'voice'].contains(action)) {
      await otp(tester);
    }
    if (['resend', 'voice'].contains(action)) {
      await tester.enterText(find.byType(TextField).first, '9');
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
    }
    switch (action) {
      case 'send':
        phone(tester)();
      case 'acquire':
        google(tester)();
      case 'resolve':
      case 'linked':
        google(tester)();
        await tester.pump();
        auth.calls.last.$2.complete(_pending);
        await tester.pump();
        await tester.pump();
        if (action == 'linked') {
          auth.calls.last.$2.complete(
              GoogleIdentityResolution(linked: true, expectedUid: 'owner_a'));
          await tester.pump();
          await tester.pump();
        }
      case 'verify':
        await verify(tester);
      case 'resend':
        resend(tester)();
      case 'voice':
        voice(tester)();
    }
    await tester.pump();
    expect(auth.calls.last.$1, action == 'resend' ? 'send' : action);
  }

  Future<void> invalidate(WidgetTester tester, String scenario) async {
    switch (scenario) {
      case 'switch':
        auth.change('owner_b');
      case 'renew':
        auth.change(auth.owner);
      case 'replace':
        final next = _Auth();
        providers.add(next);
        holder.value = next;
        await tester.pump();
      case 'leave':
        navigator.currentState!.pushReplacementNamed('/other');
        await tester.pumpAndSettle();
      case 'cover':
        navigator.currentState!.push(DialogRoute<void>(
            context: tester.element(find.byType(LoginScreen)),
            builder: (_) =>
                const AlertDialog(content: Text('Fixture overlay'))));
        // Covered login retains an indeterminate spinner; drain only the route transition.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      case 'dispose':
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
    }
    await tester.pump();
  }

  const actions = [
    'send',
    'acquire',
    'resolve',
    'linked',
    'verify',
    'resend',
    'voice'
  ];
  for (final action in actions) {
    for (final scenario in [
      'switch',
      'renew',
      'replace',
      'leave',
      'cover',
      'dispose'
    ]) {
      for (final fails in [false, true]) {
        screenTest(
            '$action $scenario suppresses late ${fails ? 'throw' : 'result'}',
            (tester) async {
          await mount(tester);
          await prepare(tester, action);
          if (action == 'verify' || action == 'linked') {
            auth.change('owner_a');
            await tester.pump();
          }
          await invalidate(tester, scenario);
          final count = auth.calls.length;
          final reply = auth.calls.last.$2;
          if (fails) {
            reply.completeError(StateError('PRIVATE provider failure'));
          } else {
            reply.complete(action == 'verify' || action == 'linked'
                ? true
                : action == 'resolve'
                    ? GoogleIdentityResolution(linked: false)
                    : _value(auth.calls.last.$1));
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(find.byType(EnableNotificationsScreen), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(auth.calls.length, count);
          if (action == 'resolve') {
            expect(find.widgetWithText(TextButton, 'Not now'), findsNothing);
          }
          if (action == 'voice') {
            expect(
                find.textContaining("We're calling you now",
                    findRichText: true),
                findsNothing);
          }
          if (action == 'resend' &&
              ['switch', 'renew', 'cover'].contains(scenario)) {
            expect(
                tester
                    .widget<TextField>(find.byType(TextField).first)
                    .controller!
                    .text,
                '9');
          }
          if (action == 'send' &&
              ['switch', 'renew', 'replace', 'cover'].contains(scenario)) {
            expect(find.byKey(const ValueKey('otp')), findsNothing);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
    for (final dark in [false, true]) {
      for (final desktop in [false, true]) {
        screenTest('$action current dark$dark desktop$desktop remains usable',
            (tester) async {
          await mount(tester, dark: dark, desktop: desktop);
          await prepare(tester, action);
          switch (action) {
            case 'send':
            case 'resend':
            case 'voice':
              auth.calls.last.$2.complete(_value(auth.calls.last.$1));
              await tester.pumpAndSettle();
              expect(find.byKey(const ValueKey('otp')), findsOneWidget);
            case 'acquire':
              auth.message = null;
              auth.calls.last.$2.complete(null);
              await tester.pumpAndSettle();
              expect(find.widgetWithText(ElevatedButton, 'Continue'),
                  findsOneWidget);
            case 'resolve':
              auth.calls.last.$2
                  .complete(GoogleIdentityResolution(linked: false));
              await tester.pumpAndSettle();
              expect(
                  find.widgetWithText(TextButton, 'Not now'), findsOneWidget);
            case 'linked':
            case 'verify':
              auth.newUser = action == 'verify';
              auth.change('owner_a');
              auth.calls.last.$2.complete(true);
              await tester.pumpAndSettle();
              expect(find.byType(EnableNotificationsScreen), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final first in ['send', 'acquire']) {
    for (final second in ['send', 'acquire']) {
      screenTest('duplicate $first/$second dispatches once', (tester) async {
        await mount(tester);
        final again = second == 'send' ? phone(tester) : google(tester);
        await prepare(tester, first);
        again();
        await tester.pump();
        expect(auth.calls.length, 1);
      });
    }
  }
  for (final first in ['resend', 'voice']) {
    for (final second in ['resend', 'voice']) {
      screenTest('duplicate OTP $first/$second dispatches once',
          (tester) async {
        await mount(tester);
        await otp(tester);
        await tester.pump(const Duration(seconds: 31));
        await tester.pump();
        final again = second == 'resend' ? resend(tester) : voice(tester);
        (first == 'resend' ? resend(tester) : voice(tester))();
        await tester.pump();
        again();
        await tester.pump();
        expect(auth.calls.length, 2);
      });
    }
  }
  for (final action in ['verify', 'resend', 'voice']) {
    screenTest('$action change number suppresses old completion',
        (tester) async {
      await mount(tester);
      await prepare(tester, action);
      if (action == 'verify') {
        auth.change('owner_a');
        await tester.pump();
      }
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Change number'))
          .onPressed!();
      await tester.pumpAndSettle();
      auth.calls.last.$2
          .complete(action == 'verify' ? true : _value(auth.calls.last.$1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone')), findsOneWidget);
      expect(find.byType(EnableNotificationsScreen), findsNothing);
    });
  }
  screenTest('delayed test OTP cannot verify after change number',
      (tester) async {
    await mount(tester);
    phone(tester)();
    await tester.pump();
    auth.calls.last.$2.complete(PhoneOtpSendResult(
        userExists: true, channel: 'sms', testOtp: '123456'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Change number'))
        .onPressed!();
    await tester.pump();
    phone(tester)();
    await tester.pump();
    auth.calls.last.$2
        .complete(PhoneOtpSendResult(userExists: true, channel: 'sms', testOtp: '654321'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(auth.calls.where((c) => c.$1 == 'verify'), isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    expect(auth.calls.where((c) => c.$1 == 'verify'), hasLength(1));
  });
  screenTest(
      'late preference read cannot remember or navigate for switched login',
      (tester) async {
    await mount(tester);
    await prepare(tester, 'verify');
    auth.change('owner_a');
    final previous = SharedPreferencesStorePlatform.instance;
    final store = _Preferences();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = store;
    try {
      auth.calls.last.$2.complete(true);
      await tester.pump();
      await tester.pump();
      auth.change('owner_b');
      await tester.pump();
      store.reply.complete({});
      await tester.pumpAndSettle();
      expect(store.writes, isEmpty);
      expect(find.byType(EnableNotificationsScreen), findsNothing);
    } finally {
      if (!store.reply.isCompleted) {
        store.reply.complete({});
      }
      SharedPreferencesStorePlatform.instance = previous;
    }
  });
  screenTest('completed page action balances temporary provider listener',
      (tester) async {
    await mount(tester);
    final before = auth.listenerBalance;
    await prepare(tester, 'send');
    auth.calls.last.$2.complete(null);
    await tester.pumpAndSettle();
    expect(auth.listenerBalance, before);
  });
  for (final action in actions) {
    screenTest('$action current failure has safe feedback and permits retry', (tester) async {
      await mount(tester);
      await prepare(tester, action);
      auth.calls.last.$2.completeError(StateError('PRIVATE transport failure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
      if (['send', 'acquire', 'resolve', 'linked'].contains(action)) {
        expect(phone(tester), isNotNull);
        expect(google(tester), isNotNull);
      } else {
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }
    });
  }
  for (final scenario in ['switch', 'renew', 'replace', 'leave', 'cover', 'dispose']) {
    screenTest('pending Google link $scenario cannot continue old login', (tester) async {
      await mount(tester);
      await prepare(tester, 'resolve');
      auth.calls.last.$2.complete(GoogleIdentityResolution(linked: false));
      await tester.pumpAndSettle();
      await otp(tester);
      await verify(tester);
      auth.change('owner_a');
      auth.calls.last.$2.complete(true);
      await tester.pump();
      await tester.pump();
      expect(auth.calls.last.$1, 'link');
      await invalidate(tester, scenario);
      final count = auth.calls.length;
      auth.calls.last.$2.complete(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(auth.calls.length, count);
      expect(find.byType(EnableNotificationsScreen), findsNothing);
      expect(find.textContaining('Google could not be connected'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final second in ['verify', 'resend', 'voice']) {
    screenTest('verify blocks concurrent OTP $second', (tester) async {
      await mount(tester);
      await otp(tester);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      final resendAction = resend(tester);
      final voiceAction = voice(tester);
      await verify(tester);
      if (second == 'verify') {
        await tester.enterText(find.byType(TextField).last, '6');
      } else {
        (second == 'resend' ? resendAction : voiceAction)();
      }
      await tester.pump();
      expect(auth.calls.length, 2);
    });
  }
  screenTest('old cleanup cannot release a newer send after change number', (tester) async {
    await mount(tester);
    await prepare(tester, 'resend');
    final old = auth.calls.last.$2;
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Change number')).onPressed!();
    await tester.pumpAndSettle();
    phone(tester)();
    await tester.pump();
    final count = auth.calls.length;
    old.complete(null);
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed, isNull);
    expect(auth.calls.length, count);
    auth.calls.last.$2.complete(_value('send'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('otp')), findsOneWidget);
  });
  screenTest('test OTP delayed callback ignores covered route', (tester) async {
    await mount(tester);
    phone(tester)();
    await tester.pump();
    auth.calls.last.$2.complete(PhoneOtpSendResult(userExists: true, channel: 'sms', testOtp: '123456'));
    await tester.pump();
    await invalidate(tester, 'cover');
    await tester.pump(const Duration(seconds: 1));
    expect(auth.calls.where((c) => c.$1 == 'verify'), isEmpty);
  });

  for (final scenario in ['switch', 'renew']) {
    screenTest('completed unlinked Google credential retires on $scenario', (tester) async {
      await mount(tester);
      await prepare(tester, 'resolve');
      auth.calls.last.$2.complete(GoogleIdentityResolution(linked: false));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Not now'), findsOneWidget);
      auth.change(scenario == 'switch' ? 'owner_b' : null);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Not now'), findsNothing);
    });
  }
  for (final action in ['linked', 'verify']) {
    screenTest('$action current primed login routes to main', (tester) async {
      await mount(tester, primed: true);
      await prepare(tester, action);
      auth.change('owner_a');
      auth.calls.last.$2.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Main destination'), findsOneWidget);
      expect(find.byType(EnableNotificationsScreen), findsNothing);
    });
  }
  for (final throws in [false, true]) {
    screenTest('Google link failure throw$throws preserves confirmed phone login', (tester) async {
      await mount(tester);
      await prepare(tester, 'resolve');
      auth.calls.last.$2.complete(GoogleIdentityResolution(linked: false));
      await tester.pumpAndSettle();
      await otp(tester);
      await verify(tester);
      auth.change('owner_a');
      auth.calls.last.$2.complete(true);
      await tester.pump();
      await tester.pump();
      expect(auth.calls.last.$1, 'link');
      if (throws) {
        auth.calls.last.$2.completeError(StateError('PRIVATE linking detail'));
      } else {
        auth.calls.last.$2.complete(false);
      }
      await tester.pumpAndSettle();
      expect(auth.owner, 'owner_a');
      expect(find.byType(EnableNotificationsScreen), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  screenTest('delayed test OTP cannot dispatch after signed-out renewal', (tester) async {
    await mount(tester);
    phone(tester)();
    await tester.pump();
    auth.calls.last.$2.complete(PhoneOtpSendResult(userExists: true, channel: 'sms', testOtp: '123456'));
    await tester.pump();
    auth.change(null);
    await tester.pump(const Duration(milliseconds: 500));
    expect(auth.calls.where((c) => c.$1 == 'verify'), isEmpty);
  });

}

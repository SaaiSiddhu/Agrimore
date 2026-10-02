@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/profile/change_email_screen.dart';
import 'package:agrimore_marketplace/screens/user/profile/change_phone_screen.dart';
import 'package:agrimore_marketplace/screens/user/profile/widgets/verification_flow_widgets.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// Official cached core harness; native query requests stay inside the fixture.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// Cached native SDK codec for controlled query replies.
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;

class ContactAuth extends FormAuth {
  final sent = Completer<bool>();
  final verified = Completer<bool>();
  final saved = Completer<bool>();
  final contactCalls = <Map<String, Object?>>[];
  void record(String method, String value) =>
      contactCalls.add({'method': method, 'owner': owner, 'value': value});
  @override
  Future<bool> sendEmailOtpForProfile(String email) {
    record('send', email);
    return sent.future;
  }

  @override
  Future<PhoneOtpSendResult?> sendPhoneOTP(String phone,
      {String channel = 'sms'}) async {
    record('send', phone);
    return await sent.future
        ? PhoneOtpSendResult(userExists: false, channel: 'sms')
        : null;
  }

  @override
  Future<bool> verifyEmailOtpForProfile(
      {required String email, required String otp}) {
    record('verify', email);
    return verified.future;
  }

  @override
  Future<bool> changeEmailAddress({required String email}) {
    record('save', email);
    return saved.future;
  }

  @override
  Future<bool> changePhoneNumber({required String phone, required String otp}) {
    record('save', phone);
    return saved.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const queryChannel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.queryGet';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  int queries = 0;
  Completer<ByteData?>? heldQuery;
  int holdAt = 1;
  bool querySuccess = false;
  ByteData? emptyQuery() => fs.FirebaseFirestoreHostApi.codec.encodeMessage([
        fs.PigeonQuerySnapshot(
            documents: [],
            documentChanges: [],
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ]);
  ByteData? refused() => const StandardMessageCodec().encodeMessage(
      ['fixture-unavailable', 'Local advisory query unavailable', null]);
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    queries = 0;
    heldQuery = null;
    holdAt = 1;
    querySuccess = false;
    messenger.setMockMessageHandler(queryChannel, (_) async {
      queries++;
      if (heldQuery != null && queries == holdAt)
        return await heldQuery!.future;
      return querySuccess ? emptyQuery() : refused();
    });
  });
  tearDown(() {
    messenger.setMockMessageHandler(queryChannel, null);
  });
  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester, ContactAuth auth, bool email,
      {bool dark = false}) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
        ],
        child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: email
                ? const ChangeEmailScreen(
                    currentEmail: 'fixture@example.invalid')
                : const ChangePhoneScreen(currentPhone: '+910000000000'))));
    await tester.pumpAndSettle();
  }

  String target(bool email) => email ? 'changed@example.test' : '0000000001';
  String wire(bool email) => email ? target(email) : '+91${target(email)}';
  Future<void> send(WidgetTester tester, bool email) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), target(email));
    await tester.pump();
    await tester.ensureVisible(find.text(email ? 'Send Code' : 'Send OTP'));
    await tester.tap(find.text(email ? 'Send Code' : 'Send OTP'));
    await drain(tester);
  }

  Future<void> digits(WidgetTester tester) async {
    for (final digit in '102938'.split('')) {
      final key = find.descendant(
          of: find.byType(NumericKeypad), matching: find.text(digit));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pump();
    }
  }

  for (final email in [true, false]) {
    final name = email ? 'email' : 'phone';
    for (final owner in <String?>['owner_b', null, 'owner_a']) {
      testWidgets('$name opening form expires on session $owner',
          (tester) async {
        final auth = ContactAuth();
        await mount(tester, auth, email);
        auth.change(owner);
        await tester.pump();
        expect(find.text('Continue'), findsNothing);
        expect(find.text(email ? 'fixture@example.invalid' : '+910000000000'),
            findsNothing);
        expect(auth.contactCalls, isEmpty);
      });
    }
    testWidgets('$name stale advisory reply cannot dispatch send',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      heldQuery = Completer<ByteData?>();
      await send(tester, email);
      expect(queries, 1);
      auth.change('owner_b');
      await tester.pump();
      heldQuery!.complete(refused());
      await drain(tester);
      expect(auth.contactCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$name stale send success cannot reveal verification target',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      expect(auth.contactCalls.single['value'], wire(email));
      auth.change('owner_b');
      await tester.pump();
      auth.sent.complete(true);
      await drain(tester);
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.textContaining(target(email)), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$name send failure renders safe copy', (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      auth.sent.complete(false);
      await drain(tester);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        '$name sent target remains frozen when input changes during send',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = email ? 'other@example.test' : '0000000002';
      await tester.pump();
      auth.sent.complete(true);
      await drain(tester);
      await tester.pumpAndSettle();
      await digits(tester);
      expect(auth.contactCalls.last['value'], wire(email));
      if (email) {
        auth.verified.complete(true);
        await drain(tester);
      }
      auth.saved.complete(true);
      await drain(tester);
      await tester.pumpAndSettle();
      expect(
          find.text(email ? 'Email Address Updated!' : 'Phone Number Updated!'),
          findsOneWidget);
      expect(
          auth.contactCalls.where((c) => c['method'] == 'save').single['value'],
          wire(email));
    });
    testWidgets('$name late save success after signout cannot publish success',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      auth.sent.complete(true);
      await drain(tester);
      await tester.pumpAndSettle();
      await digits(tester);
      if (email) {
        auth.verified.complete(true);
        await drain(tester);
      }
      expect(auth.contactCalls.last['method'], 'save');
      auth.change(null);
      await tester.pump();
      auth.saved.complete(true);
      await drain(tester);
      expect(find.byType(VerificationSuccessView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('email stale verification cannot dispatch profile save',
      (tester) async {
    final auth = ContactAuth();
    await mount(tester, auth, true);
    await send(tester, true);
    auth.sent.complete(true);
    await drain(tester);
    await tester.pumpAndSettle();
    await digits(tester);
    auth.change('owner_b');
    await tester.pump();
    auth.verified.complete(true);
    await drain(tester);
    expect(auth.contactCalls.where((c) => c['method'] == 'save'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final email in [true, false]) {
    final name = email ? 'email' : 'phone';
    for (final dark in [false, true]) {
      testWidgets(
          '$name normal confirmed flow in ${dark ? "dark" : "light"} with all advisory queries',
          (tester) async {
        querySuccess = true;
        final auth = ContactAuth();
        await mount(tester, auth, email, dark: dark);
        await send(tester, email);
        expect(queries, 3);
        expect(auth.contactCalls.single['value'], wire(email));
        auth.sent.complete(true);
        await drain(tester);
        await tester.pumpAndSettle();
        await digits(tester);
        if (email) {
          auth.verified.complete(true);
          await drain(tester);
        }
        auth.saved.complete(true);
        await drain(tester);
        await tester.pumpAndSettle();
        expect(find.byType(VerificationSuccessView), findsOneWidget);
        expect(
            auth.contactCalls
                .where((c) => c['method'] == 'save')
                .single['value'],
            wire(email));
        expect(tester.takeException(), isNull);
      });
    }
    for (final stage in [1, 2, 3]) {
      testWidgets('$name stops at stale advisory query $stage', (tester) async {
        querySuccess = true;
        holdAt = stage;
        heldQuery = Completer<ByteData?>();
        final auth = ContactAuth();
        await mount(tester, auth, email);
        await send(tester, email);
        expect(queries, stage);
        auth.change('owner_a');
        await tester.pump();
        heldQuery!.complete(emptyQuery());
        await drain(tester);
        expect(queries, stage);
        expect(auth.contactCalls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$name provider replacement invalidates the form',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      final replacement = ContactAuth();
      await mount(tester, replacement, email);
      expect(find.text('Continue'), findsNothing);
      expect(replacement.contactCalls, isEmpty);
    });
    testWidgets('$name dispose while send reply held ignores reply',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      await tester.pumpWidget(const SizedBox());
      auth.sent.complete(true);
      await drain(tester);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$name thrown send error is handled with static feedback',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      auth.sent.completeError(StateError('unsafe fixture detail'));
      await drain(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Could not send a verification code. Please try again.'),
          findsOneWidget);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
    });
    testWidgets('$name declined save cannot claim success', (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      auth.sent.complete(true);
      await drain(tester);
      await tester.pumpAndSettle();
      await digits(tester);
      if (email) {
        auth.verified.complete(true);
        await drain(tester);
      }
      auth.saved.complete(false);
      await drain(tester);
      expect(find.byType(VerificationSuccessView), findsNothing);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
    });
    testWidgets('$name expired countdown never updates disposed state',
        (tester) async {
      final auth = ContactAuth();
      await mount(tester, auth, email);
      await send(tester, email);
      auth.sent.complete(true);
      await drain(tester);
      auth.change('owner_b');
      await tester.pump();
      await tester.pump(const Duration(seconds: 35));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('email refused verification cannot dispatch save',
      (tester) async {
    final auth = ContactAuth();
    await mount(tester, auth, true);
    await send(tester, true);
    auth.sent.complete(true);
    await drain(tester);
    await tester.pumpAndSettle();
    await digits(tester);
    auth.verified.complete(false);
    await drain(tester);
    expect(auth.contactCalls.where((c) => c['method'] == 'save'), isEmpty);
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

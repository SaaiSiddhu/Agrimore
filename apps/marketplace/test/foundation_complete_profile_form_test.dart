@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/auth/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

class CompletionAuth extends FormAuth {
  final contacts = <Map<String, Object?>>[];
  final sent = Completer<bool>();
  final verified = Completer<bool>();
  final completed = Completer<bool>();
  @override
  Future<bool> sendEmailOtpForProfile(String email) {
    contacts.add({'method': 'send', 'owner': owner, 'email': email});
    return sent.future;
  }

  @override
  Future<bool> verifyEmailOtpForProfile(
      {required String email, required String otp}) {
    contacts.add({'method': 'verify', 'owner': owner, 'email': email});
    return verified.future;
  }

  @override
  Future<bool> completeUserProfile(
      {required String name,
      required String email,
      required DateTime dateOfBirth,
      required String gender}) {
    contacts.add({
      'method': 'complete',
      'owner': owner,
      'email': email,
      'name': name,
      'date': dateOfBirth,
      'gender': gender
    });
    return completed.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Finder input(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint);
  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester, CompletionAuth auth,
      {bool dark = false, GlobalKey<NavigatorState>? nav}) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            navigatorKey: nav,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            routes: {
              '/main': (_) => const Scaffold(body: Text('Main fixture'))
            },
            home: const CompleteProfileScreen(phone: '+910000000001'))));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.enterText(input('you@example.com'), 'sent@example.test');
    await press(tester, 'Send Code');
  }

  Future<void> verify(WidgetTester tester, CompletionAuth auth) async {
    await send(tester);
    auth.sent.complete(true);
    await tester.pumpAndSettle();
    await tester.enterText(input('6-digit code'), '102938');
    await press(tester, 'Verify');
    auth.verified.complete(true);
    await tester.pumpAndSettle();
  }

  Future<void> details(WidgetTester tester) async {
    await tester.enterText(input('Enter your full name'), 'Opening Person');
    await press(tester, 'Select date of birth');
    await tester.pumpAndSettle();
    await press(tester, 'OK');
    await tester.pumpAndSettle();
    await press(tester, 'Female');
  }

  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('completion opening session $owner hides staged form',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      await tester.enterText(input('Enter your full name'), 'Private Person');
      auth.change(owner);
      await tester.pumpAndSettle();
      expect(find.text('Private Person'), findsNothing);
      expect(find.text('+910000000001'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(auth.contacts, isEmpty);
    });
    testWidgets('completion stale send $owner cannot show verify',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      await send(tester);
      auth.change(owner);
      auth.sent.complete(true);
      await tester.pumpAndSettle();
      expect(input('6-digit code'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(auth.contacts.length, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets('completion stale verify $owner cannot confirm email',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      await send(tester);
      auth.sent.complete(true);
      await tester.pumpAndSettle();
      await tester.enterText(input('6-digit code'), '102938');
      await press(tester, 'Verify');
      auth.change(owner);
      auth.verified.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('sent@example.test'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(auth.contacts.length, 2);
    });
    testWidgets('completion stale save $owner cannot navigate', (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      await verify(tester, auth);
      await details(tester);
      await press(tester, 'Get Started');
      auth.change(owner);
      auth.completed.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Main fixture'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
      expect(auth.contacts.length, 3);
    });
  }
  testWidgets('completion verification uses frozen sent target',
      (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await send(tester);
    tester.widget<TextField>(input('you@example.com')).controller!.text =
        'edited@example.test';
    auth.sent.complete(true);
    await tester.pumpAndSettle();
    await tester.enterText(input('6-digit code'), '102938');
    await press(tester, 'Verify');
    expect(auth.contacts.last['email'], 'sent@example.test');
    auth.verified.complete(true);
    await tester.pumpAndSettle();
    await details(tester);
    await press(tester, 'Get Started');
    expect(auth.contacts.last['email'], 'sent@example.test');
    auth.completed.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
  });
  testWidgets('completion send refusal has safe copy', (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await send(tester);
    auth.sent.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
    expect(find.text('Could not send a verification code. Please try again.'),
        findsOneWidget);
  });
  testWidgets('completion does not replace an overlaid route after save',
      (tester) async {
    final auth = CompletionAuth();
    final nav = GlobalKey<NavigatorState>();
    await mount(tester, auth, nav: nav);
    await verify(tester, auth);
    await details(tester);
    await press(tester, 'Get Started');
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Overlay fixture'))));
    await tester.pumpAndSettle();
    auth.completed.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Overlay fixture'), findsOneWidget);
    expect(find.text('Main fixture'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('completion current owner succeeds in light/dark $dark',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth, dark: dark);
      await verify(tester, auth);
      await details(tester);
      await press(tester, 'Get Started');
      expect(auth.contacts.last['method'], 'complete');
      expect(auth.contacts.last['owner'], 'owner_a');
      expect(auth.contacts.last['name'], 'Opening Person');
      expect(auth.contacts.last['gender'], 'female');
      expect(auth.contacts.last['email'], 'sent@example.test');
      auth.completed.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Main fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final step in ['send', 'verify', 'complete']) {
    testWidgets('completion disposed during $step has no continuation',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      if (step == 'complete') {
        await verify(tester, auth);
        await details(tester);
        await press(tester, 'Get Started');
      } else {
        await send(tester);
        if (step == 'verify') {
          auth.sent.complete(true);
          await tester.pumpAndSettle();
          await tester.enterText(input('6-digit code'), '102938');
          await press(tester, 'Verify');
        }
      }
      await tester.pumpWidget(const SizedBox());
      if (step == 'send') auth.sent.complete(true);
      if (step == 'verify') auth.verified.complete(true);
      if (step == 'complete') auth.completed.complete(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          auth.contacts.length,
          step == 'send'
              ? 1
              : step == 'verify'
                  ? 2
                  : 3);
    });
    testWidgets('completion thrown $step has safe copy and can retry',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      if (step == 'complete') {
        await verify(tester, auth);
        await details(tester);
        await press(tester, 'Get Started');
        auth.completed.completeError(StateError('unsafe fixture detail'));
      } else {
        await send(tester);
        if (step == 'send') {
          auth.sent.completeError(StateError('unsafe fixture detail'));
        } else {
          auth.sent.complete(true);
          await tester.pumpAndSettle();
          await tester.enterText(input('6-digit code'), '102938');
          await press(tester, 'Verify');
          auth.verified.completeError(StateError('unsafe fixture detail'));
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
      final message = step == 'send'
          ? 'Could not send a verification code. Please try again.'
          : step == 'verify'
              ? 'Could not verify your code. Please try again.'
              : 'Could not complete your profile. Please try again.';
      expect(find.text(message), findsOneWidget);
      final label = step == 'send'
          ? 'Send Code'
          : step == 'verify'
              ? 'Verify'
              : 'Get Started';
      expect(
          tester
              .widget<ElevatedButton>(find.ancestor(
                  of: find.text(label), matching: find.byType(ElevatedButton)))
              .onPressed,
          isNotNull);
    });
  }
  testWidgets('completion renewal during date picker ignores reply',
      (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await press(tester, 'Select date of birth');
    await tester.pumpAndSettle();
    auth.change('owner_a');
    await tester.pump();
    await press(tester, 'OK');
    await tester.pumpAndSettle();
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('completion disposed date picker reply does not setState',
      (tester) async {
    final auth = CompletionAuth();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('Base fixture')))));
    final route = MaterialPageRoute<void>(
        builder: (_) => const CompleteProfileScreen(phone: '+910000000001'));
    nav.currentState!.push(route);
    await tester.pumpAndSettle();
    await press(tester, 'Select date of birth');
    await tester.pumpAndSettle();
    nav.currentState!.removeRoute(route);
    await tester.pumpAndSettle();
    await press(tester, 'OK');
    await tester.pumpAndSettle();
    expect(find.text('Base fixture'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('completion duplicate captured send is refused', (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await tester.enterText(input('you@example.com'), 'sent@example.test');
    final callback = tester
        .widget<ElevatedButton>(find.ancestor(
            of: find.text('Send Code'), matching: find.byType(ElevatedButton)))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(auth.contacts.length, 1);
    auth.sent.complete(false);
    await tester.pumpAndSettle();
  });
  testWidgets('completion pending verify refuses captured resend',
      (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await send(tester);
    auth.sent.complete(true);
    await tester.pumpAndSettle();
    final resend = tester
        .widget<TextButton>(find.ancestor(
            of: find.text('Resend code'), matching: find.byType(TextButton)))
        .onPressed!;
    await tester.enterText(input('6-digit code'), '102938');
    await press(tester, 'Verify');
    resend();
    await tester.pump();
    expect(auth.contacts.length, 2);
    auth.verified.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Could not verify your code. Please try again.'),
        findsOneWidget);
  });
  testWidgets('completion save freezes verified email and name',
      (tester) async {
    final auth = CompletionAuth();
    await mount(tester, auth);
    await send(tester);
    final email =
        tester.widget<TextField>(input('you@example.com')).controller!;
    auth.sent.complete(true);
    await tester.pumpAndSettle();
    await tester.enterText(input('6-digit code'), '102938');
    await press(tester, 'Verify');
    auth.verified.complete(true);
    await tester.pumpAndSettle();
    email.text = 'edited@example.test';
    await details(tester);
    await press(tester, 'Get Started');
    tester.widget<TextField>(input('Enter your full name')).controller!.text =
        'Edited Person';
    expect(auth.contacts.last['email'], 'sent@example.test');
    expect(auth.contacts.last['name'], 'Opening Person');
    auth.completed.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Could not complete your profile. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
  });
  testWidgets('completion unsigned opening cannot send', (tester) async {
    final auth = CompletionAuth()..owner = null;
    await mount(tester, auth);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(input('you@example.com'), findsNothing);
    expect(auth.contacts, isEmpty);
  });
  testWidgets('completion provider replacement hides former form',
      (tester) async {
    final old = CompletionAuth();
    final replacement = CompletionAuth();
    final notifier = ValueNotifier<CompletionAuth>(old);
    await tester.pumpWidget(ValueListenableBuilder<CompletionAuth>(
        valueListenable: notifier,
        builder: (_, auth, child) => ChangeNotifierProvider<AuthProvider>.value(
            value: auth, child: child),
        child: const MaterialApp(
            home: CompleteProfileScreen(phone: '+910000000001'))));
    await tester.pumpAndSettle();
    notifier.value = replacement;
    await tester.pumpAndSettle();
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(find.text('+910000000001'), findsNothing);
    expect(old.contacts, isEmpty);
    expect(replacement.contacts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });
  for (final width in [390.0, 800.0]) {
    for (final dark in [false, true]) {
      testWidgets('completion layout at $width dark $dark', (tester) async {
        final auth = CompletionAuth();
        await mount(tester, auth, dark: dark);
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.text('Your information is secure and private'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final action in ['verify', 'resend']) {
    testWidgets(
        'completion $action keeps confirmed sent email after field edit',
        (tester) async {
      final auth = CompletionAuth();
      await mount(tester, auth);
      await send(tester);
      auth.sent.complete(true);
      await tester.pumpAndSettle();
      tester.widget<TextField>(input('you@example.com')).controller!.text =
          'edited@example.test';
      if (action == 'verify') {
        await tester.enterText(input('6-digit code'), '102938');
        await press(tester, 'Verify');
        expect(auth.contacts.last['email'], 'sent@example.test');
        auth.verified.complete(false);
      } else {
        await press(tester, 'Resend code');
        expect(auth.contacts.last['email'], 'sent@example.test');
        expect(auth.contacts.last['method'], 'send');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

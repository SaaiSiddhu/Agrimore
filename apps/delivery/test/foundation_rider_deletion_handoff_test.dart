import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:delivery/design_system/design_system.dart' show DeliveryTheme;
import 'package:delivery/account/rider_account.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/auth/pending_approval_screen.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'auth_session_test.dart' as fixture;
import 'rider_profile_screen_test.dart' as profile;

class HeldAccount implements RiderAccountBackend {
  Completer<void>? _result;
  Completer<void> get result => _result ??= Completer<void>();
  int calls = 0;
  @override
  Future<void> deleteAccount() {
    calls++;
    return result.future;
  }

  @override
  Future<void> updateContact(Map<String, dynamic> contact) async {}
}

class HeldLocation extends LocationProvider {
  final log = <String>[];
  Completer<void>? offline;
  @override
  void stopTracking() => log.add('stop');
  @override
  Future<void> setOnlineStatus(String partnerId, bool isOnline) async {
    log.add('offline $partnerId $isOnline');
    await offline?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Inter', 'packages/agrimore_ui/Inter']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
      }
      await loader.load();
    }
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide');
    icons.addFont(rootBundle.load(
        'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w400.ttf'));
    await icons.load();
  });
  for (final pending in [false, true]) {
    final name = pending ? 'pending status' : 'profile';
    group(name, () {
      late fixture.FakeGateway gateway;
      late DeliveryAuthProvider auth;
      late fixture.FakeStore store;
      late fixture.FakePush push;
      late HeldAccount backend;
      late HeldLocation location;
      late DeliveryOrderProvider orders;
      final boundary = GlobalKey();
      setUp(() {
        gateway = fixture.FakeGateway()..uid = 'rA';
        store = fixture.FakeStore();
        for (final uid in ['rA', 'rB']) {
          store.users[uid] = fixture.doc({
            'role': 'delivery_partner',
            'name': uid,
            'email': '$uid@example.invalid'
          });
          store.partners[uid] =
              fixture.doc({'status': pending ? 'pending' : 'approved'});
        }
        push = fixture.FakePush()..token = null;
        auth = DeliveryAuthProvider(
            gateway: gateway, store: store, pushTokens: push);
        backend = HeldAccount();
        location = HeldLocation();
        orders = profile.fakeOrders('rA');
      });
      tearDown(() async {
        auth.dispose();
        orders.dispose();
        location.dispose();
        await push.refresh.close();
        for (final stream in store.partnerStreams.values) {
          await stream.close();
        }
      });
      Future<void> flush(WidgetTester t) async {
        await t.runAsync(() => pumpEventQueue());
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
      }

      Future<void> mount(WidgetTester t,
          {Brightness brightness = Brightness.light}) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.runAsync(() => pumpEventQueue());
        await t.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
            ChangeNotifierProvider<LocationProvider>.value(value: location),
            ChangeNotifierProvider<DeliveryOrderProvider>.value(value: orders),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? DeliveryTheme.dark()
                  : DeliveryTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: pending
                  ? DeliveryPendingApprovalScreen(backend: backend)
                  : RiderProfileScreen(
                      backend: backend,
                      partnerSource: (_) => Stream.value(
                          const {'name': 'Rider A', 'city': 'Madurai'}),
                      accountSource: (_) =>
                          Stream.value(RiderAccount.fromMap(const {})),
                    ),
            ),
          ),
        ));
        await flush(t);
        expect(auth.user?.uid, 'rA');
      }

      Future<void> open(WidgetTester t) async {
        final entry = find.text('Delete my account');
        await t.scrollUntilVisible(entry, 350,
            scrollable: find.byType(Scrollable).first);
        await t.ensureVisible(entry);
        await flush(t);
        await t.tap(entry);
        await flush(t);
        expect(find.text('Delete your account?'), findsOneWidget);
      }

      Future<void> confirm(WidgetTester t) async {
        await t.tap(find.text('Delete').last);
        await flush(t);
      }

      testWidgets('old confirmation cannot dispatch under another SDK owner',
          (t) async {
        await mount(t);
        await open(t);
        gateway.uid = 'rB'; // SDK changed; auth event deliberately delayed.
        await confirm(t);
        expect(backend.calls, 0);
        expect(gateway.log, isEmpty);
      });
      testWidgets('old confirmation cannot dispatch under a renewed same UID',
          (t) async {
        await mount(t);
        await open(t);
        gateway.emit('rA');
        await flush(t);
        await confirm(t);
        expect(backend.calls, 0);
      });
      for (final failure in [false, true]) {
        testWidgets(
            'late ${failure ? 'refusal' : 'success'} does not notify or sign out B',
            (t) async {
          await mount(t);
          await open(t);
          await confirm(t);
          expect(backend.calls, 1);
          gateway.emit('rB');
          await flush(t);
          if (failure) {
            backend.result.completeError(
                const AccountActionException(AccountActionFailure.cashHeld));
          } else {
            backend.result.complete();
          }
          await flush(t);
          expect(gateway.uid, 'rB');
          expect(gateway.log, isEmpty);
          expect(find.text('Your account was deleted.'), findsNothing);
          expect(
              find.text(
                  "You still hold customers' cash. Deposit it with Agrimore first."),
              findsNothing);
        });
      }
      testWidgets('same UID renewal fences a late deletion success', (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        gateway.emit('rA');
        await flush(t);
        backend.result.complete();
        await flush(t);
        expect(gateway.uid, 'rA');
        expect(gateway.log, isEmpty);
        expect(find.text('Your account was deleted.'), findsNothing);
      });
      testWidgets(
          'confirmed deletion remains successful after its own SDK signout',
          (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        gateway.emit(null);
        await flush(t);
        backend.result.complete();
        await flush(t);
        expect(gateway.log, isEmpty,
            reason: 'already signed out; no second token invalidation/logout');
        expect(find.text('Your account was deleted.'), findsOneWidget);
      });
      testWidgets(
          'newer account followed by logout is not an old deletion completion',
          (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        gateway.emit('rB');
        await flush(t);
        gateway.emit(null);
        await flush(t);
        backend.result.complete();
        await flush(t);
        expect(gateway.log, isEmpty);
        expect(find.text('Your account was deleted.'), findsNothing);
      });
      testWidgets(
          'owned confirmed success still reports deletion and signs out',
          (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        backend.result.complete();
        await flush(t);
        expect(backend.calls, 1);
        expect(gateway.log, ['signOut']);
        expect(gateway.uid, isNull);
        expect(find.text('Your account was deleted.'), findsOneWidget);
      });
      testWidgets(
          'owned refusal still reports actionable cash reason without logout',
          (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        backend.result.completeError(
            const AccountActionException(AccountActionFailure.cashHeld));
        await flush(t);
        expect(gateway.uid, 'rA');
        expect(gateway.log, isEmpty);
        expect(
            find.text(
                "You still hold customers' cash. Deposit it with Agrimore first."),
            findsOneWidget);
      });
      testWidgets('late result after screen disposal has no logout or feedback',
          (t) async {
        await mount(t);
        await open(t);
        await confirm(t);
        await t.pumpWidget(const SizedBox());
        backend.result.complete();
        await flush(t);
        expect(gateway.uid, 'rA');
        expect(gateway.log, isEmpty);
        expect(t.takeException(), isNull);
      });
      for (final brightness in Brightness.values) {
        testWidgets(
            'canonical phone ${brightness.name} dialog cancels without mutation',
            (t) async {
          await mount(t, brightness: brightness);
          await open(t);
          final output = Platform.environment['F2F_PREVIEW_OUT'];
          if (output != null) {
            final render = boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            await t.runAsync(() async {
              final picture = await render.toImage(pixelRatio: 1);
              final data =
                  await picture.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '$output/${pending ? 'pending' : 'profile'}-${brightness.name}.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              picture.dispose();
            });
          }
          await t.tap(find.text('Cancel'));
          await flush(t);
          expect(backend.calls, 0);
          expect(gateway.uid, 'rA');
          expect(t.takeException(), isNull);
        });
      }
      if (!pending) {
        testWidgets(
            'old signout confirmation cannot stop or logout a new rider',
            (t) async {
          await mount(t);
          final entry = find.byKey(const ValueKey('sign-out'));
          await t.scrollUntilVisible(entry, 350);
          await t.ensureVisible(entry);
          await flush(t);
          await t.tap(entry);
          await flush(t);
          expect(find.text('Sign out of this device?'), findsOneWidget);
          location.log.clear();
          gateway.uid = 'rB';
          await t.tap(find.text('Sign out').last);
          await flush(t);
          expect(gateway.log, isEmpty);
          expect(location.log, isEmpty);
        });
      }
      testWidgets('owned shared logout waits for offline before SDK signout',
          (t) async {
        await mount(t);
        late BuildContext context;
        await t.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
            ChangeNotifierProvider<LocationProvider>.value(value: location),
          ],
          child: Builder(builder: (value) {
            context = value;
            return const SizedBox();
          }),
        ));
        location.log.clear();
        location.offline = Completer<void>();
        final logout = riderSignOut(context);
        expect(location.log, ['stop', 'offline rA false']);
        await flush(t);
        expect(gateway.log, isEmpty);
        location.offline!.complete();
        await logout;
        await flush(t);
        expect(gateway.uid, isNull);
        expect(gateway.log, ['signOut']);
      });
      testWidgets('offline await preserves newer session during shared logout',
          (t) async {
        await mount(t);
        late BuildContext context;
        await t.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
            ChangeNotifierProvider<LocationProvider>.value(value: location),
          ],
          child: Builder(builder: (value) {
            context = value;
            return const SizedBox();
          }),
        ));
        location.log.clear();
        location.offline = Completer<void>();
        final logout = riderSignOut(context);
        expect(location.log, ['stop', 'offline rA false']);
        gateway.emit('rB');
        await flush(t);
        location.offline!.complete();
        await logout;
        await flush(t);
        expect(gateway.uid, 'rB');
        expect(gateway.log, isEmpty);
      });
    });
  }
}

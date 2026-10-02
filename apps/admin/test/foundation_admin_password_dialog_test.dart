@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_admin/providers/auth_provider.dart';
import 'package:agrimore_admin/app/themes/admin_theme.dart';
import 'package:agrimore_admin/screens/admin/settings/admin_settings_screen.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_core/firebase_core.dart';
// Official local Firebase initialization fixture; no provider operations.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class DialogAuth extends ChangeNotifier implements AuthProvider {
  String? owner = 'owner_a';
  String role = 'admin';
  int epoch = 1;
  final reply = Completer<bool>();
  final requests = <Map<String, String?>>[];
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
  int get sessionVersion => epoch;
  @override
  bool isSessionCurrent(String uid, int version) =>
      owner == uid && epoch == version;
  @override
  Future<bool> changePassword(
      {required String currentPassword, required String newPassword}) {
    requests
        .add({'owner': owner, 'current': currentPassword, 'new': newPassword});
    return reply.future;
  }

  @override
  String? get error => 'PRIVATE fixture detail';
  void change(String? uid) {
    owner = uid;
    epoch++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DialogSessionUser implements User {
  DialogSessionUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DialogSessionService implements AuthService {
  String? owner = 'owner_a';
  final events = StreamController<User?>.broadcast();
  @override
  String? get currentUserId => owner;
  @override
  Stream<User?> get authStateChanges => events.stream;
  @override
  Future<UserModel> getUserData(String uid) async => UserModel(
      uid: uid,
      email: 'fixture@example.invalid',
      name: 'Admin fixture',
      role: 'admin',
      createdAt: DateTime(2026));
  void change(String? uid) {
    owner = uid;
    events.add(uid == null ? null : DialogSessionUser(uid));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
    (_) async => const StandardMessageCodec().encodeMessage([null]),
  );
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  Finder input(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);
  Future<void> mount(WidgetTester tester, DialogAuth auth,
      {bool dark = false,
      GlobalKey<NavigatorState>? nav,
      ValueNotifier<AuthProvider>? holder}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
    final selected = holder ?? ValueNotifier<AuthProvider>(auth);
    await tester.pumpWidget(ValueListenableBuilder<AuthProvider>(
        valueListenable: selected,
        builder: (_, provider, __) =>
            ChangeNotifierProvider<AuthProvider>.value(
                value: provider,
                child: MaterialApp(
                    navigatorKey: nav,
                    theme: dark ? AdminTheme.darkTheme : AdminTheme.lightTheme,
                    home: const AdminSettingsScreen()))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Change Password'));
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(input('Current Password'), 'fixture_old');
    await tester.enterText(input('New Password'), 'fixture_new');
    await tester.enterText(input('Confirm Password'), 'fixture_new');
  }

  Future<void> submit(WidgetTester tester) async {
    await fill(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Change'));
    await tester.pump();
  }

  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('admin dialog session $uid hides fields and clears old input',
        (tester) async {
      final auth = DialogAuth();
      await mount(tester, auth);
      await fill(tester);
      final old =
          tester.widget<TextField>(input('Current Password')).controller!;
      auth.change(uid);
      await tester.pumpAndSettle();
      expect(input('Current Password'), findsNothing);
      expect(old.text, isEmpty);
      expect(find.textContaining('Your session changed'), findsOneWidget);
    });
    testWidgets('admin dialog captured stale action $uid cannot dispatch',
        (tester) async {
      final auth = DialogAuth();
      await mount(tester, auth);
      await fill(tester);
      final callback = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Change'))
          .onPressed!;
      auth.change(uid);
      callback();
      await tester.pump();
      expect(auth.requests, isEmpty);
      auth.reply.complete(false);
      await tester.pumpAndSettle();
    });
    testWidgets(
        'admin dialog stale completion $uid does not pop or show success',
        (tester) async {
      final auth = DialogAuth();
      await mount(tester, auth);
      await submit(tester);
      auth.change(uid);
      auth.reply.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Password changed successfully!'), findsNothing);
      expect(find.textContaining('Your session changed'), findsOneWidget);
    });
  }
  for (final dark in [false, true]) {
    testWidgets('admin dialog current owner success dark $dark',
        (tester) async {
      final auth = DialogAuth();
      await mount(tester, auth, dark: dark);
      await submit(tester);
      expect(auth.requests, hasLength(1));
      auth.reply.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Password changed successfully!'), findsOneWidget);
    });
  }
  testWidgets(
      'admin dialog pending fields disabled and duplicate captured action stopped',
      (tester) async {
    final auth = DialogAuth();
    await mount(tester, auth);
    await fill(tester);
    final callback = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Change'))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(auth.requests, hasLength(1));
    expect(
        tester.widget<TextField>(input('Current Password')).enabled, isFalse);
    expect(tester.widget<TextField>(input('New Password')).enabled, isFalse);
    expect(
        tester.widget<TextField>(input('Confirm Password')).enabled, isFalse);
    auth.reply.complete(false);
    await tester.pumpAndSettle();
  });
  for (final throws in [false, true]) {
    testWidgets('admin dialog safe failure throws $throws', (tester) async {
      final auth = DialogAuth();
      await mount(tester, auth);
      await submit(tester);
      if (throws) {
        auth.reply.completeError(StateError('PRIVATE'));
      } else {
        auth.reply.complete(false);
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.text('Could not change your password. Please try again.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }
  testWidgets('admin dialog completion does not pop overlaid route',
      (tester) async {
    final auth = DialogAuth();
    final nav = GlobalKey<NavigatorState>();
    await mount(tester, auth, nav: nav);
    await submit(tester);
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Overlay fixture'))));
    await tester.pumpAndSettle();
    auth.reply.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Overlay fixture'), findsOneWidget);
    expect(find.text('Password changed successfully!'), findsNothing);
  });
  testWidgets('admin dialog disposed completion produces no feedback',
      (tester) async {
    final auth = DialogAuth();
    final nav = GlobalKey<NavigatorState>();
    await mount(tester, auth, nav: nav);
    await submit(tester);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    auth.reply.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Password changed successfully!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin dialog signedout opening has no fields', (tester) async {
    final auth = DialogAuth()..owner = null;
    await mount(tester, auth);
    expect(input('Current Password'), findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
    expect(auth.requests, isEmpty);
  });
  testWidgets('admin dialog role loss clears previous input', (tester) async {
    final auth = DialogAuth();
    await mount(tester, auth);
    await fill(tester);
    final old = tester.widget<TextField>(input('Current Password')).controller!;
    auth.role = 'seller';
    auth.notifyListeners();
    await tester.pumpAndSettle();
    expect(input('Current Password'), findsNothing);
    expect(old.text, isEmpty);
  });
  testWidgets('admin dialog provider replacement clears opening input',
      (tester) async {
    final auth = DialogAuth();
    final replacement = DialogAuth();
    final holder = ValueNotifier<AuthProvider>(auth);
    await mount(tester, auth, holder: holder);
    await fill(tester);
    final old = tester.widget<TextField>(input('Current Password')).controller!;
    final callback = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Change'))
        .onPressed!;
    holder.value = replacement;
    await tester.pumpAndSettle();
    callback();
    await tester.pumpAndSettle();
    expect(input('Current Password'), findsNothing);
    expect(old.text, isEmpty);
    expect(auth.requests, isEmpty);
    expect(replacement.requests, isEmpty);
  });
  testWidgets('admin dialog inputs frozen across pending operation',
      (tester) async {
    final auth = DialogAuth();
    await mount(tester, auth);
    await submit(tester);
    final field = tester.widget<TextField>(input('New Password'));
    field.controller!.text = 'altered_fixture';
    expect(auth.requests.single['current'], 'fixture_old');
    expect(auth.requests.single['new'], 'fixture_new');
    auth.reply.complete(false);
    await tester.pumpAndSettle();
    expect(field.enabled, isFalse);
  });
  testWidgets('admin dialog stale failure has no feedback', (tester) async {
    final auth = DialogAuth();
    await mount(tester, auth);
    await submit(tester);
    auth.change('owner_b');
    auth.reply.completeError(StateError('PRIVATE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.text('Could not change your password. Please try again.'),
        findsNothing);
    expect(find.textContaining('Your session changed'), findsOneWidget);
  });

  Future<void> drain() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('actual admin dialog session accessors reject owner drift and renewal',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = DialogSessionService();
    final auth = AuthProvider(authService: service);
    service.change('owner_a');
    await drain();
    final epoch = auth.sessionVersion;
    expect(auth.isSessionCurrent('owner_a', epoch), isTrue);
    service.owner = 'owner_b';
    expect(auth.isSessionCurrent('owner_a', epoch), isFalse);
    service.change('owner_a');
    await drain();
    expect(auth.sessionVersion, greaterThan(epoch));
    expect(auth.isSessionCurrent('owner_a', epoch), isFalse);
    expect(auth.isSessionCurrent('owner_a', auth.sessionVersion), isTrue);
    auth.dispose();
    await service.events.close();
  });
  test(
      'actual admin dialog session accessors reject lost observer and disposal',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = DialogSessionService();
    final auth = AuthProvider(authService: service);
    service.change('owner_a');
    await drain();
    final epoch = auth.sessionVersion;
    await service.events.close();
    await drain();
    expect(auth.isSessionCurrent('owner_a', epoch), isFalse);
    auth.dispose();
    expect(auth.isSessionCurrent('owner_a', auth.sessionVersion), isFalse);
  });
}

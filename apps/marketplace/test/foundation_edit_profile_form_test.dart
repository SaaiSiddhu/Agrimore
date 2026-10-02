@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/profile/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// Same cached transitive Storage SDK used by the production screen.
// ignore: depend_on_referenced_packages
import 'package:firebase_storage/firebase_storage.dart';
// Official cached platform harness; all transports remain local fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class FormCore extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
            name: '[DEFAULT]',
            options: CoreFirebaseOptions(
                apiKey: 'fixture',
                projectId: 'demo-agrimore-foundation',
                appId: 'fixture',
                messagingSenderId: 'fixture',
                storageBucket: 'demo-agrimore-foundation.appspot.com'),
            pluginConstants: {})
      ];
}

class FormAuth extends ChangeNotifier implements AuthProvider {
  String? owner = 'owner_a';
  int version = 1;
  final calls = <Map<String, Object?>>[];
  final reply = Completer<bool>();
  final dobReply = Completer<bool>();
  final dates = <DateTime>[];
  @override
  Future<bool> changeDateOfBirth({required DateTime dateOfBirth}) {
    dates.add(dateOfBirth);
    return dobReply.future;
  }

  @override
  UserModel? get currentUser => owner == null
      ? null
      : UserModel(
          uid: owner!,
          email: 'fixture@example.invalid',
          name: 'Opening Name',
          role: 'buyer',
          createdAt: DateTime(2026),
          gender: 'female');
  @override
  int get sessionVersion => version;
  @override
  bool isSessionCurrent(String uid, int epoch) =>
      owner == uid && version == epoch;
  @override
  Future<bool> updateUserProfile(
      {String? name, String? phone, String? photoUrl, String? gender}) {
    calls.add({'owner': owner, 'name': name, 'gender': gender});
    return reply.future;
  }

  @override
  String? get error => 'unsafe fixture detail';
  void change(String? uid) {
    owner = uid;
    version++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FormTheme extends ChangeNotifier implements ThemeProvider {
  FormTheme(this.dark);
  final bool dark;
  @override
  bool get isDarkMode => dark;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HeldImage extends XFile {
  HeldImage() : super('/fixture-local-only');
  final bytes = Completer<Uint8List>();
  int reads = 0;
  @override
  Future<Uint8List> readAsBytes() {
    reads++;
    return bytes.future;
  }
}

class FormPicker implements ImagePicker {
  final reply = Completer<XFile?>();
  int calls = 0;
  @override
  Future<XFile?> pickImage(
      {required ImageSource source,
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      bool requestFullMetadata = true}) {
    calls++;
    return reply.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FormObserver extends NavigatorObserver {
  int pops = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(FormCore());
  int storageCalls = 0;
  const storageChannel =
      'dev.flutter.pigeon.firebase_storage_platform_interface.FirebaseStorageHostApi.referencePutData';
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    storageCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(storageChannel, (_) async {
      storageCalls++;
      return const StandardMessageCodec().encodeMessage(['fixture-observer']);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel(
          'plugins.flutter.io/firebase_storage/taskEvent/fixture-observer'),
      MockStreamHandler.inline(onListen: (_, events) {
        events.success({
          'taskState': 4,
          'error': {
            'code': 'fixture-denied',
            'message': 'Local fixture stops upload'
          }
        });
        events.endOfStream();
      }),
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(storageChannel, null);
  });
  Future<void> mount(WidgetTester tester, FormAuth auth,
      {bool dark = false, FormObserver? observer, FormPicker? picker}) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
        ],
        child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            navigatorObservers: [if (observer != null) observer],
            home: EditProfileScreen(imagePicker: picker))));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
  }

  for (final dark in [false, true]) {
    testWidgets(
        'owned form retains legitimate save in ${dark ? "dark" : "light"}',
        (tester) async {
      final auth = FormAuth();
      await mount(tester, auth, dark: dark);
      await save(tester);
      expect(auth.calls.single,
          {'owner': 'owner_a', 'name': 'Opening Name', 'gender': 'female'});
      auth.reply.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('unsafe fixture detail'), findsNothing);
    });
  }
  for (final owner in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('changed session $owner hides opening data and blocks save',
        (tester) async {
      final auth = FormAuth();
      await mount(tester, auth);
      auth.change(owner);
      await tester.pump();
      expect(find.text('Opening Name'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
      expect(auth.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('late save success cannot display feedback in changed session',
      (tester) async {
    final auth = FormAuth();
    await mount(tester, auth);
    await save(tester);
    auth.change('owner_b');
    await tester.pump();
    auth.reply.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Profile updated successfully'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dispose before delayed avatar animation is harmless',
      (tester) async {
    final auth = FormAuth();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(false)),
    ], child: const MaterialApp(home: EditProfileScreen())));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('delayed save navigation never pops a newer route',
      (tester) async {
    final auth = FormAuth();
    final observer = FormObserver();
    await mount(tester, auth, observer: observer);
    await save(tester);
    auth.reply.complete(true);
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New route'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New route'), findsOneWidget);
    expect(observer.pops, 0);
  });
  testWidgets('renewed session during success delay cannot navigate',
      (tester) async {
    final auth = FormAuth();
    final observer = FormObserver();
    await mount(tester, auth, observer: observer);
    await save(tester);
    auth.reply.complete(true);
    await tester.pump();
    auth.change('owner_a');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(observer.pops, 0);
    expect(find.text('Save Changes'), findsNothing);
  });
  testWidgets('late save error after disposal is ignored', (tester) async {
    final auth = FormAuth();
    await mount(tester, auth);
    await save(tester);
    await tester.pumpWidget(const SizedBox());
    auth.reply.completeError(StateError('unsafe fixture detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'provider replacement invalidates even the same owner and version',
      (tester) async {
    final original = FormAuth();
    await mount(tester, original);
    final replacement = FormAuth();
    await mount(tester, replacement);
    expect(find.text('Save Changes'), findsNothing);
    expect(replacement.calls, isEmpty);
  });
  testWidgets('gender picker reply cannot revive a changed form',
      (tester) async {
    final auth = FormAuth();
    await mount(tester, auth);
    await tester.ensureVisible(find.text('Gender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gender'));
    await tester.pumpAndSettle();
    auth.change('owner_b');
    await tester.pump();
    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    expect(find.text('Save Changes'), findsNothing);
    expect(auth.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('date picker reply after owner switch dispatches no command',
      (tester) async {
    final auth = FormAuth();
    await mount(tester, auth);
    await tester.ensureVisible(find.text('Date of Birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date of Birth'));
    await tester.pumpAndSettle();
    auth.change('owner_b');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(auth.dates, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late date command reply cannot update another session',
      (tester) async {
    final auth = FormAuth();
    await mount(tester, auth);
    await tester.ensureVisible(find.text('Date of Birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date of Birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(auth.dates, hasLength(1));
    auth.change('owner_b');
    await tester.pump();
    auth.dobReply.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Date of birth updated'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final dispose in [false, true]) {
    testWidgets(
        'late image picker after ${dispose ? "dispose" : "session change"} is ignored',
        (tester) async {
      final auth = FormAuth();
      final picker = FormPicker();
      await mount(tester, auth, picker: picker);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      if (dispose) {
        await tester.pumpWidget(const SizedBox());
      } else {
        auth.change('owner_b');
        await tester.pump();
      }
      picker.reply.complete(XFile('/fixture-not-read-after-stale-reply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(auth.calls, isEmpty);
    });
  }
  testWidgets('expired form uses readable dark theme text', (tester) async {
    final auth = FormAuth();
    await mount(tester, auth, dark: true);
    auth.change(null);
    await tester.pump();
    final message = tester.widget<Text>(
        find.text('Your session changed. Reopen your profile to continue.'));
    final context = tester.element(
        find.text('Your session changed. Reopen your profile to continue.'));
    expect(
        message.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });
  testWidgets('failed image picker is handled with static safe feedback',
      (tester) async {
    final auth = FormAuth();
    final picker = FormPicker();
    await mount(tester, auth, picker: picker);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    picker.reply.completeError(StateError('unsafe fixture detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not select your photo. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('unsafe fixture detail'), findsNothing);
  });
  testWidgets(
      'held photo bytes cannot initiate upload or save after account switch',
      (tester) async {
    final auth = FormAuth();
    final picker = FormPicker();
    final image = HeldImage();
    await mount(tester, auth, picker: picker);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    picker.reply.complete(image);
    await tester.pump();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(image.reads, greaterThanOrEqualTo(2));
    auth.change('owner_b');
    await tester.pump();
    image.bytes.complete(Uint8List(0));
    await tester.runAsync(() async {
      for (var turn = 0; turn < 4; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pumpAndSettle();
    expect(storageCalls, 0);
    expect(auth.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test(
      'storage transport positive control records and refuses actual SDK upload',
      () async {
    await expectLater(
        FirebaseStorage.instance
            .ref('users/fixture/never-uploaded.jpg')
            .putData(Uint8List(0)),
        throwsA(isA<FirebaseException>()));
    expect(storageCalls, 1);
  });
}

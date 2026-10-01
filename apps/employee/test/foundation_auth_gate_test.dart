@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:agrimore_services/agrimore_services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:employee/app/app.dart';
import 'package:employee/providers/auth_provider.dart';
import 'package:employee/providers/theme_provider.dart';
import 'package:employee/screens/auth/login_screen.dart';
import 'package:employee/screens/auth/pending_approval_screen.dart';
import 'package:employee/screens/auth/suspended_screen.dart';
import 'package:employee/screens/shell/employee_shell_screen.dart';

class _RootAuth extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  late StreamController<UserPlatform?> changes;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  Stream<UserPlatform?> authStateChanges() => changes.stream;
  @override
  UserPlatform? get currentUser => uid == null ? null : _RootUser(this, uid!);
  @override
  Future<void> signOut() async {
    uid = null;
    changes.add(null);
  }
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _RootUser extends UserPlatform {
  _RootUser(FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: true,
                    email: 'fixture@example.invalid'),
                providerData: []));
}

class _Service implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const reads = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');
  final previewOut = Platform.environment['AGRIMORE_PREVIEW_OUT'];
  final previewKey = GlobalKey();
  late _RootAuth firebase;
  late EmployeeAuthProvider auth;
  late EmployeeThemeProvider theme;
  late Future<List<Object?>> Function(fs.DocumentReferenceRequest) read;
  List<Object?> document(String path, Map<String, Object?>? data) => [
        fs.PigeonDocumentSnapshot(
            path: path,
            data: data,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
  List<Object?> approved(fs.DocumentReferenceRequest r) => document(
      r.path,
      r.path.startsWith('users/')
          ? {
              'role': 'employee',
              'name': 'Current',
              'email': 'fixture@example.invalid'
            }
          : {'status': 'approved'});
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(RepaintBoundary(
        key: previewKey,
        child: MultiProvider(providers: [
          ChangeNotifierProvider<EmployeeAuthProvider>.value(value: auth),
          ChangeNotifierProvider<EmployeeThemeProvider>.value(value: theme),
        ], child: const App())));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    // Avoid pumpAndSettle: an intentionally held session can keep a spinner active.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (previewOut == null) return;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    await settle(tester);
    final render =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await render.toImage(pixelRatio: 1);
      final bytes = (await picture.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(previewOut).create(recursive: true);
      await File('$previewOut/$name.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      picture.dispose();
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  setUpAll(() async {
    await Firebase.initializeApp();
    if (previewOut != null) {
      final loader = FontLoader('Inter');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(rootBundle
            .load('packages/agrimore_ui/assets/fonts/Inter-$weight.ttf'));
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final outlineIcons = FontLoader('packages/lucide_icons_flutter/Lucide');
      outlineIcons.addFont(rootBundle.load(
          'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w400.ttf'));
      await outlineIcons.load();
    }
    firebase = _RootAuth();
    FirebaseAuthPlatform.instance = firebase;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebase.uid = 'owner_a';
    firebase.changes = StreamController<UserPlatform?>.broadcast();
    read = (r) async => approved(r);
    messenger.setMockDecodedMessageHandler<Object?>(
        reads,
        (message) async =>
            read((message! as List)[1] as fs.DocumentReferenceRequest));
    messenger.setMockMethodCallHandler(
        messaging,
        (call) async =>
            call.method == 'Messaging#getToken' ? {'token': null} : null);
    // Shell streams remain local and silent; no SDK operation reaches a service.
    for (final name in ['documentReferenceSnapshot', 'querySnapshot']) {
      final channel =
          'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.$name';
      messenger.setMockMessageHandler(
          channel,
          (_) async => fs.FirebaseFirestoreHostApi.codec
              .encodeMessage(['fixture-$name']));
      messenger.setMockMethodCallHandler(
          MethodChannel(
              'plugins.flutter.io/firebase_firestore/${name == 'querySnapshot' ? 'query' : 'document'}/fixture-$name'),
          (_) async => null);
    }
    auth = EmployeeAuthProvider(authService: _Service());
    theme = EmployeeThemeProvider();
  });
  tearDown(() async {
    auth.dispose();
    theme.dispose();
    await firebase.changes.close();
    messenger.setMockDecodedMessageHandler<Object?>(reads, null);
    messenger.setMockMethodCallHandler(messaging, null);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'signed-in SDK alone cannot open shell ${dark ? 'dark' : 'light'}',
        (tester) async {
      await theme.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      await mount(tester);
      expect(find.byType(EmployeeShellScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      await capture(tester, 'unresolved-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'held approval keeps workspace closed ${dark ? 'dark' : 'light'}',
        (tester) async {
      await theme.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      final pending = Completer<List<Object?>>();
      read = (r) async =>
          r.path.startsWith('employees/') ? pending.future : approved(r);
      firebase.changes.add(firebase.currentUser);
      await mount(tester);
      await settle(tester);
      final shells = find.byType(EmployeeShellScreen).evaluate().length;
      pending.complete(document('employees/owner_a', {'status': 'pending'}));
      await settle(tester);
      expect(shells, 0);
      await capture(
          tester, 'approval-resolved-pending-${dark ? 'dark' : 'light'}');
      expect(find.byType(EmployeePendingApprovalScreen), findsOneWidget);
      expect(find.byType(EmployeeShellScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
    for (final status in ['pending', 'suspended']) {
      testWidgets(
          '$status routes to its established screen ${dark ? 'dark' : 'light'}',
          (tester) async {
        await theme.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
        read = (r) async => r.path.startsWith('employees/')
            ? document(r.path, {'status': status})
            : approved(r);
        firebase.changes.add(firebase.currentUser);
        await mount(tester);
        await settle(tester);
        expect(find.byType(EmployeeShellScreen), findsNothing);
        expect(
            find.byType(status == 'pending'
                ? EmployeePendingApprovalScreen
                : SuspendedScreen),
            findsOneWidget);
        await capture(tester, '$status-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
        'approved current employee opens real shell ${dark ? 'dark' : 'light'}',
        (tester) async {
      await theme.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      firebase.changes.add(firebase.currentUser);
      await mount(tester);
      await settle(tester);
      expect(find.byType(EmployeeShellScreen), findsOneWidget);
      await capture(tester, 'approved-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
  }
}

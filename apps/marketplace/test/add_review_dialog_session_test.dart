import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart' as app_auth;
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/shop/widgets/add_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;

class ReviewAuth extends Fake implements AuthService {
  String? owner = 'owner_a';
  Completer<UserModel>? profile;
  final reads = <String>[];
  @override
  String? get currentUserId => owner;
  @override
  String? getCurrentUserId() => owner;
  @override
  Future<UserModel> getUserData(String uid) {
    reads.add(uid);
    return profile?.future ??
        Future.value(UserModel(
            uid: uid,
            email: 'fixture@example.invalid',
            name: 'Fixture',
            role: 'buyer',
            createdAt: DateTime.utc(2026)));
  }
}

class ReviewSave extends Fake implements DatabaseService {
  final writes = <ReviewModel>[];
  final result = Completer<String>();
  bool Function()? current;
  DatabaseService factory(bool Function() guard) {
    current = guard;
    return this;
  }

  @override
  Future<String> addReview(ReviewModel value) {
    writes.add(value);
    return result.future;
  }

  @override
  Future<void> updateReview(ReviewModel value) async {
    writes.add(value);
    await result.future;
  }
}

class ReviewFixture {
  FormAuth auth = FormAuth();
  ReviewAuth service = ReviewAuth();
  final save = ReviewSave();
  final product = ValueNotifier('A');
  bool? receipt;
  ReviewModel? edit;
  Completer<List<XFile>>? pickReply;
  Completer<String>? uploadReply;
  final uploads = <String>[];
  Future<List<XFile>> pick() async =>
      pickReply == null ? [] : await pickReply!.future;
  Future<String> upload(String path, Uint8List bytes) {
    uploads.add(path);
    return uploadReply?.future ??
        Future.value('https://fixture.invalid/photo.jpg');
  }

  Future<bool> purchase(String uid, String product) async => false;
  Future<void> mount(WidgetTester t, {bool dark = false}) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<app_auth.AuthProvider>.value(value: auth),
          Provider<AuthService>.value(value: service),
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(dark)),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (ctx) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          receipt = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => ValueListenableBuilder<String>(
                                  valueListenable: product,
                                  builder: (_, id, __) => AddReviewDialog(
                                      productId: id,
                                      productName: 'Fixture',
                                      reviewToEdit: edit,
                                      purchaseCheck: purchase,
                                      databaseFactory: save.factory,
                                      pickImages: pick,
                                      uploadImage: upload)));
                        },
                        child: const Text('Open review')))))));
    await t.pump();
  }

  Future<void> open(WidgetTester t) async {
    await t.tap(find.text('Open review'));
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t) async {
    await t.enterText(find.byType(TextFormField).at(0), 'Draft title');
    await t.enterText(find.byType(TextFormField).at(1), 'Draft comment');
  }

  Future<void> submit(WidgetTester t) async {
    final label = edit == null ? 'Submit Review' : 'Update Review';
    await t.ensureVisible(find.text(label));
    await t.tap(find.text(label));
    await t.pump();
    await t.pump();
  }

  Future<void> finish(WidgetTester t) async {
    save.result.complete('owner_a');
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('owned confirmed save alone dismisses dialog true', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    expect(f.receipt, isNull);
    await f.finish(t);
    expect(f.receipt, true);
    expect(f.save.writes.single.userId, 'owner_a');
  });
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('opening auth lifetime expires $uid', (t) async {
      final f = ReviewFixture();
      await f.mount(t);
      await f.open(t);
      f.auth.change(uid);
      f.service.owner = uid;
      await t.pump();
      expect(find.text('Submit Review'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });
  }
  testWidgets('signed-out opening cannot render form', (t) async {
    final f = ReviewFixture();
    f.auth.owner = null;
    f.service.owner = null;
    await f.mount(t);
    await f.open(t);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('late saved result cannot dismiss true after account switch',
      (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.auth.change('owner_b');
    f.service.owner = 'owner_b';
    await t.pump();
    await f.finish(t);
    expect(f.receipt, isNot(true));
  });
  testWidgets('passed writer guard expires with same UID epoch', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.auth.change('owner_a');
    await t.pump();
    expect(f.save.current!(), false);
    await f.finish(t);
  });
  testWidgets('captured submit cannot dispatch twice', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    final action = t
        .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Submit Review'))
        .onPressed!;
    action();
    await t.pump();
    await t.pump();
    action();
    await t.pump();
    await t.pump();
    expect(f.save.writes.length, 1);
    await f.finish(t);
  });
  testWidgets('draft fields and captured stars cannot mutate pending request',
      (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    expect(t.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        false);
    await f.finish(t);
  });
  testWidgets('profile result after switch cannot begin save', (t) async {
    final f = ReviewFixture();
    f.service.profile = Completer<UserModel>();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.auth.change('owner_b');
    f.service.owner = 'owner_b';
    await t.pump();
    f.service.profile!.complete(UserModel(
        uid: 'owner_a',
        email: 'fixture@example.invalid',
        name: 'Fixture',
        role: 'buyer',
        createdAt: DateTime.utc(2026)));
    await t.pump();
    await t.pump();
    expect(f.save.writes, isEmpty);
    if (!f.save.result.isCompleted) f.save.result.complete('owner_a');
    await t.pumpAndSettle();
  });
  testWidgets('save failure copy never exposes transport detail', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.save.result.completeError(StateError('unsafe fixture SDK'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('unsafe fixture SDK'), findsNothing);
  });
  testWidgets('retained dialog cannot adopt changed product', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    f.product.value = 'B';
    await t.pump();
    expect(find.byType(TextFormField), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('owned dialog renders phone light/dark $dark', (t) async {
      final f = ReviewFixture();
      await f.mount(t, dark: dark);
      await f.open(t);
      expect(find.text('Submit Review'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('profile exception is safe and allows retry', (t) async {
    final f = ReviewFixture();
    f.service.profile = Completer<UserModel>();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.service.profile!.completeError(StateError('unsafe profile'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('unsafe profile'), findsNothing);
    expect(f.save.writes, isEmpty);
    expect(
        t
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Submit Review'))
            .onPressed,
        isNotNull);
  });
  testWidgets('auth provider replacement expires retained dialog', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    f.auth = FormAuth();
    await f.mount(t);
    await t.pump();
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('auth service replacement expires retained dialog', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    f.service = ReviewAuth();
    await f.mount(t);
    await t.pump();
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('late picker after account change cannot show photos', (t) async {
    final f = ReviewFixture();
    f.pickReply = Completer<List<XFile>>();
    await f.mount(t);
    await f.open(t);
    await t.ensureVisible(find.text('Tap to add photos'));
    await t.tap(find.text('Tap to add photos'));
    await t.pump();
    f.auth.change('owner_b');
    f.service.owner = 'owner_b';
    await t.pump();
    f.pickReply!.complete([
      XFile.fromData(Uint8List.fromList([1]), name: 'fixture.jpg')
    ]);
    await t.pump();
    expect(find.byType(TextFormField), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('late picker after disposal cannot set state', (t) async {
    final f = ReviewFixture();
    f.pickReply = Completer<List<XFile>>();
    await f.mount(t);
    await f.open(t);
    await t.ensureVisible(find.text('Tap to add photos'));
    await t.tap(find.text('Tap to add photos'));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    f.pickReply!.complete([
      XFile.fromData(Uint8List.fromList([1]), name: 'fixture.jpg')
    ]);
    await t.pump();
    expect(t.takeException(), isNull);
  });
  Future<void> addPhoto(WidgetTester t, ReviewFixture f) async {
    f.pickReply = Completer<List<XFile>>();
    await t.ensureVisible(find.text('Tap to add photos'));
    await t.tap(find.text('Tap to add photos'));
    await t.pump();
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    f.pickReply!.complete([XFile.fromData(png, name: 'fixture.jpg')]);
    await t.pumpAndSettle();
  }

  testWidgets('upload failure aborts save and stays open', (t) async {
    final f = ReviewFixture();
    f.uploadReply = Completer<String>();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await addPhoto(t, f);
    await f.submit(t);
    f.uploadReply!.completeError(StateError('unsafe upload'));
    await t.pump();
    await t.pump();
    expect(f.save.writes, isEmpty);
    expect(f.receipt, isNull);
    expect(find.textContaining('unsafe upload'), findsNothing);
    expect(
        find.text(
            'Could not upload review photos. Try again or remove the photos.'),
        findsOneWidget);
  });
  testWidgets('late upload after sign-out cannot begin review write',
      (t) async {
    final f = ReviewFixture();
    f.uploadReply = Completer<String>();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await addPhoto(t, f);
    await f.submit(t);
    expect(f.uploads.single, startsWith('reviews/A/owner_a/'));
    f.auth.change(null);
    f.service.owner = null;
    await t.pump();
    f.uploadReply!.complete('https://fixture.invalid/photo.jpg');
    await t.pump();
    await t.pump();
    expect(f.save.writes, isEmpty);
    expect(f.receipt, isNot(true));
  });
  testWidgets('unconfirmed save ID cannot dismiss true', (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    f.save.result.complete('wrong-owner');
    await t.pump();
    await t.pump();
    expect(f.receipt, isNull);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
  ReviewModel editing(String owner, {String product = 'A'}) => ReviewModel(
      reviewId: 'legacy',
      productId: product,
      userId: owner,
      userName: 'Fixture',
      userAvatar: '',
      rating: 4,
      title: 'Saved title',
      comment: 'Saved comment',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026));
  testWidgets('owned edit awaits confirmed update and keeps target', (t) async {
    final f = ReviewFixture();
    f.edit = editing('owner_a');
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    expect(f.receipt, isNull);
    expect(f.save.writes.single.reviewId, 'legacy');
    f.save.result.complete('legacy');
    await t.pumpAndSettle();
    expect(f.receipt, true);
  });
  for (final owner in ['owner_b', '']) {
    testWidgets('foreign edit cannot render or write $owner', (t) async {
      final f = ReviewFixture();
      f.edit = editing(owner);
      await f.mount(t);
      await f.open(t);
      expect(find.byType(TextFormField), findsNothing);
      expect(f.save.writes, isEmpty);
    });
  }
  for (final id in ['', 'A/B']) {
    testWidgets('invalid product route refuses form $id', (t) async {
      final f = ReviewFixture();
      f.product.value = id;
      await f.mount(t);
      await f.open(t);
      expect(find.byType(TextFormField), findsNothing);
      expect(f.service.reads, isEmpty);
    });
  }
  testWidgets('pending profile wait keeps original title and rating draft',
      (t) async {
    final f = ReviewFixture();
    f.service.profile = Completer<UserModel>();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    final star = t
        .widget<GestureDetector>(find
            .ancestor(
                of: find.byIcon(Icons.star_rounded).first,
                matching: find.byType(GestureDetector))
            .first)
        .onTap!;
    await f.submit(t);
    star();
    t.widget<TextFormField>(find.byType(TextFormField).first).controller!.text =
        'Late draft';
    f.service.profile!.complete(UserModel(
        uid: 'owner_a',
        email: 'fixture@example.invalid',
        name: 'Fixture',
        role: 'buyer',
        createdAt: DateTime.utc(2026)));
    await t.pump();
    await t.pump();
    expect(f.save.writes.single.rating, 5);
    expect(f.save.writes.single.title, 'Draft title');
    await f.finish(t);
  });
  testWidgets('save completion after disposal cannot produce UI receipt',
      (t) async {
    final f = ReviewFixture();
    await f.mount(t);
    await f.open(t);
    await f.fill(t);
    await f.submit(t);
    await t.pumpWidget(const SizedBox());
    await f.finish(t);
    expect(f.receipt, isNot(true));
    expect(t.takeException(), isNull);
  });
}

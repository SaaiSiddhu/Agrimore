import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/posts/followers_screen.dart';

/// SELLER-FOLLOWERS-1: counts only (no follower identities), posts listed
/// newest first, deletion asks first.
class _Fake implements FollowersSource {
  final deleted = <String>[];
  final _posts = StreamController<List<SellerPost>>.broadcast();
  List<SellerPost> current = [
    SellerPost(id: 'p1', text: 'Fresh mangoes today', createdAt: DateTime(2026, 9, 22)),
    const SellerPost(id: 'p2', imageUrl: 'https://x/y.jpg'),
  ];

  @override
  Future<int> followers() async => 128;
  @override
  Future<int> newFollowersSince(DateTime since) async => 7;
  @override
  Stream<List<SellerPost>> posts() async* {
    yield current;
    yield* _posts.stream;
  }

  @override
  Future<void> deletePost(String id) async {
    deleted.add(id);
    current = current.where((p) => p.id != id).toList();
    _posts.add(current);
  }
}

void main() {
  testWidgets('counts, posts, delete with confirmation', (tester) async {
    final fake = _Fake();
    late AppLocalizations l10n;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
        ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(const [])),
      ],
      child: MaterialApp(
        theme: SellerTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Post photos never load in tests; with animations off their
        // skeleton stays still so pumpAndSettle can settle.
        builder: (context, app) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: app!),
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return FollowersScreen(source: fake, now: DateTime(2026, 9, 23));
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(SellerFormat.count(128)), findsOneWidget);
    expect(find.text(l10n.followersNew(7)), findsOneWidget);
    expect(find.text('Fresh mangoes today'), findsOneWidget);
    expect(find.text(l10n.postsNoText), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.productDelete).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.postsDeleteTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.productDelete));
    await tester.pumpAndSettle();
    expect(fake.deleted, ['p1']);
    expect(find.text('Fresh mangoes today'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

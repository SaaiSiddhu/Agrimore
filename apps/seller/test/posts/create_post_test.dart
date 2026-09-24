import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/providers/seller_post_provider.dart';
import 'package:seller/screens/posts/create_post_screen.dart';

import '../support/seller_fixtures.dart';

/// Publishes without Firebase; records what it was asked to post.
class _FakePoster extends SellerPostProvider {
  _FakePoster(this.result);
  final bool result;
  String? postedText;

  @override
  Future<bool> createPost(
      {required String sellerId,
      String? text,
      Uint8List? imageBytes,
      String? imageFileName,
      String? productId}) async {
    postedText = text;
    return result;
  }
}

void main() {
  Future<void> openComposer(WidgetTester tester, _FakePoster poster) async {
    final l10n = await pumpSellerApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => CreatePostScreen(provider: poster))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      user: fixtureSeller(),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fresh mangoes today');
    await tester.pump();
    await tester.tap(find.text(l10n.postPublish));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'publishing closes the composer without a discard prompt and confirms',
      (tester) async {
    final poster = _FakePoster(true);
    await openComposer(tester, poster);
    expect(poster.postedText, 'Fresh mangoes today');
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(CreatePostScreen), findsNothing);
    expect(find.text('Posted to your followers'), findsOneWidget);
  });

  testWidgets('a failed post keeps the composer and the text', (tester) async {
    await openComposer(tester, _FakePoster(false));
    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.text('Fresh mangoes today'), findsOneWidget);
  });
}

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaInfoBanner Component Tests', () {
    testWidgets('renders info banner with message and info icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const Scaffold(
            body: SaInfoBanner(
              message: 'Your application is under review.',
              variant: SaBannerVariant.info,
            ),
          ),
        ),
      );

      expect(find.text('Your application is under review.'), findsOneWidget);
      expect(find.byIcon(SaIcons.info), findsOneWidget);
    });

    testWidgets('renders error banner with error icon and action button',
        (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: Scaffold(
            body: SaInfoBanner(
              message: 'Unable to load. Try again.',
              variant: SaBannerVariant.error,
              actionLabel: 'Try again',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Unable to load. Try again.'), findsOneWidget);
      expect(find.byIcon(SaIcons.circleAlert), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });

    testWidgets('renders warning and success variants with respective icons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                SaInfoBanner(
                  message: 'Warning notice',
                  variant: SaBannerVariant.warning,
                ),
                SaInfoBanner(
                  message: 'Success notice',
                  variant: SaBannerVariant.success,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(SaIcons.triangleAlert), findsOneWidget);
      expect(find.byIcon(SaIcons.circleCheck), findsOneWidget);
    });
  });
}

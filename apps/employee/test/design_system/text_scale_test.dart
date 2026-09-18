import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Accessibility & Text Scaling Resilience Tests', () {
    testWidgets('SaLoadingButton renders without overflow at 200% text scale',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(SaTokens.pagePadding),
                  child: SaLoadingButton(
                    text: 'Continue',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('SaInfoBanner wraps multi-line text without overflow at 150% text scale',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(SaTokens.pagePadding),
                child: const SaInfoBanner(
                  title: 'Important Account Notice',
                  message:
                      'Your application is currently under review by our team. '
                      'This process typically takes 24-48 business hours.',
                  variant: SaBannerVariant.info,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Important Account Notice'), findsOneWidget);
    });
  });
}

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaLoadingButton Component Tests', () {
    testWidgets('renders default primary state and responds to tap',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: Scaffold(
            body: SaLoadingButton(
              text: 'Continue',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows spinner and loadingText when isLoading is true, ignoring taps',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: Scaffold(
            body: SaLoadingButton(
              text: 'Continue',
              isLoading: true,
              loadingText: 'Signing in...',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Signing in...'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Signing in...'));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('renders disabled state when onPressed is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: const Scaffold(
            body: SaLoadingButton(
              text: 'Disabled Action',
              onPressed: null,
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('renders outlined variant with border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SalesAssociateTheme.lightTheme,
          home: Scaffold(
            body: SaLoadingButton(
              text: 'Outlined Action',
              variant: SaButtonVariant.outlined,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Outlined Action'), findsOneWidget);
    });
  });
}

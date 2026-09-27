// ADMR-35 — the first genuine testWidgets/pumpWidget coverage in this
// app's test suite. Every other admin test exercises pure Dart logic
// because the real screens require a live Firebase app to construct; this
// dialog is a plain Flutter widget with no such dependency, so it is
// exercised for real: built, tapped, typed into, and its actual return
// value asserted — not just the decision function behind it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrimore_admin/screens/admin/orders/widgets/order_reason_dialog.dart';

Future<String?> _pumpAndOpen(WidgetTester tester) async {
  String? captured;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          captured = await promptOrderActionReason(
            context: context,
            title: 'Cancel Orders',
            message: 'Cancel 3 order(s)?',
          );
        },
        child: const Text('Open'),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('promptOrderActionReason', () {
    testWidgets('shows the title and message', (tester) async {
      await _pumpAndOpen(tester);
      expect(find.text('Cancel Orders'), findsOneWidget);
      expect(find.text('Cancel 3 order(s)?'), findsOneWidget);
    });

    testWidgets('the confirm button is disabled until a valid reason is typed',
        (tester) async {
      await _pumpAndOpen(tester);

      final confirmButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'ok');
      await tester.pump();
      final stillDisabled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(stillDisabled.onPressed, isNull,
          reason: '2 characters is below the default minLength of 3');

      await tester.enterText(find.byType(TextField), 'Customer requested it');
      await tester.pump();
      final enabled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('confirming returns the trimmed reason', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await promptOrderActionReason(
                context: context,
                title: 'T',
                message: 'M',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Damaged in transit  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(result, 'Damaged in transit');
    });

    testWidgets('cancelling returns null and types nothing', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await promptOrderActionReason(
                context: context,
                title: 'T',
                message: 'M',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('respects a custom confirmLabel and minLength', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => promptOrderActionReason(
              context: context,
              title: 'T',
              message: 'M',
              confirmLabel: 'Yes, Cancel',
              minLength: 10,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Yes, Cancel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'short');
      await tester.pump();
      final disabled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Yes, Cancel'),
      );
      expect(disabled.onPressed, isNull,
          reason: '"short" (5 chars) is below the custom minLength of 10');
    });
  });
}

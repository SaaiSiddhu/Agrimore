import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';

import '../support/seller_harness.dart';

void main() {
  group('SellerButton', () {
    testWidgets('loading disables the button, keeps its label and blocks a second submit', (tester) async {
      var submits = 0;
      var loading = false;
      await pumpSeller(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: SellerButton(
              label: 'Save product',
              loadingLabel: 'Saving…',
              loading: loading,
              onPressed: () => setState(() {
                submits++;
                loading = true;
              }),
            ),
          ),
        ),
      );
      final width = tester.getSize(find.byType(FilledButton)).width;
      await tester.tap(find.text('Save product'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byType(SellerSpinner), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(submits, 1, reason: 'a loading button ignores repeat taps');
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(tester.getSize(find.byType(FilledButton)).width, greaterThanOrEqualTo(SellerSize.touchTarget));
      expect(width, greaterThanOrEqualTo(SellerSize.touchTarget));
    });

    testWidgets('every button and icon button is at least 48 × 48', (tester) async {
      await pumpSeller(
        tester,
        Wrap(children: [
          SellerButton(label: 'A', onPressed: () {}),
          SellerButton.secondary(label: 'B', onPressed: () {}),
          SellerButton.tertiary(label: 'C', onPressed: () {}),
          SellerButton.tonal(label: 'D', onPressed: () {}),
          SellerIconButton(icon: SellerIcons.bell, label: 'Notifications', onPressed: () {}),
        ]),
      );
      for (final type in [FilledButton, OutlinedButton, TextButton]) {
        for (final e in find.byType(type).evaluate()) {
          final size = tester.getSize(find.byWidget(e.widget));
          expect(size.height, greaterThanOrEqualTo(SellerSize.touchTarget), reason: '$type height');
          expect(size.width, greaterThanOrEqualTo(SellerSize.touchTarget), reason: '$type width');
        }
      }
      final icon = tester.getSize(find.byType(SellerIconButton));
      expect(icon.width, greaterThanOrEqualTo(SellerSize.touchTarget));
      expect(icon.height, greaterThanOrEqualTo(SellerSize.touchTarget));
    });

    testWidgets('a custom semantic label is announced once, as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSeller(tester, Center(child: SellerButton(label: 'Accept', semanticLabel: 'Accept order 1042', onPressed: () {})));
      expect(
        tester.getSemantics(find.byType(SellerButton)),
        matchesSemantics(label: 'Accept order 1042', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Accept'), findsNothing);
      handle.dispose();
    });
  });

  group('SellerTextField and SellerFormScope', () {
    testWidgets('label above, required read as "required", error shows icon + text', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = await pumpSeller(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: SellerTextField(label: 'Stock quantity', required: true, errorText: 'Enter a stock quantity', helper: 'Use zero if out of stock.'),
        ),
      );
      expect(find.text('Enter a stock quantity'), findsOneWidget);
      expect(find.byIcon(SellerIcons.error), findsWidgets);
      final label = tester.getSemantics(find.byType(TextField)).label;
      expect(label, contains('Stock quantity'));
      expect(label, contains(l10n.dsRequired));
      handle.dispose();
    });

    testWidgets('focusFirstInvalid focuses the top-most invalid field and lists labels', (tester) async {
      final scope = GlobalKey<SellerFormScopeState>();
      final formKey = GlobalKey<FormState>();
      await pumpSeller(
        tester,
        SellerFormScope(
          key: scope,
          child: Form(
            key: formKey,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              SellerTextField(label: 'Product name', validator: (v) => v.isEmpty ? 'Enter a product name' : null),
              SellerTextField(label: 'Price', validator: (v) => null),
              SellerTextField(label: 'Stock quantity', validator: (v) => v.isEmpty ? 'Enter a stock quantity' : null),
            ]),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(scope.currentState!.invalidLabels, ['Product name', 'Stock quantity']);
      expect(scope.currentState!.focusFirstInvalid(), isTrue);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(focused?.debugLabel, 'Product name');
    });
  });

  group('states and reduced motion', () {
    testWidgets('spinner turns into a static hourglass when animations are off', (tester) async {
      await pumpSeller(tester, const Center(child: SellerSpinner()), reduceMotion: true);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(SellerIcons.hourglass), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('skeleton does not pulse when animations are off', (tester) async {
      await pumpSeller(tester, const SellerSkeletonList(count: 2), reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('FAQ row opens instantly with reduced motion and announces its state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSeller(tester, const SellerExpandableRow(title: 'When do I get paid?', child: Text('After delivery.')), reduceMotion: true);
      expect(find.text('After delivery.'), findsNothing);
      expect(tester.getSemantics(find.bySemanticsLabel('When do I get paid?')).getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);
      await tester.tap(find.text('When do I get paid?'));
      await tester.pump();
      expect(find.text('After delivery.'), findsOneWidget);
      // Already at its final size on the first frame: no size animation.
      final opened = tester.getSize(find.byType(SellerExpandableRow));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SellerExpandableRow)), opened);
      expect(tester.getSemantics(find.bySemanticsLabel('When do I get paid?')).getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
      handle.dispose();
    });
  });

  group('SellerOtpInput', () {
    testWidgets('one labelled field; typing six digits completes; pasted spaces are dropped', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? completed;
      final l10n = await pumpSeller(
        tester,
        Padding(padding: const EdgeInsets.all(16), child: SellerOtpInput(controller: controller, onCompleted: (v) => completed = v)),
      );
      expect(find.bySemanticsLabel(l10n.dsOtpFieldLabel(6)), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12 34 56');
      await tester.pump();
      expect(controller.text, '123456');
      expect(completed, '123456');
      for (final d in '123456'.split('')) {
        expect(find.text(d), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('charts and data', () {
    testWidgets('line chart is announced by its summary; the table reads row by row', (tester) async {
      final handle = tester.ensureSemantics();
      const points = [SellerChartPoint('22 Sep', 3, '3'), SellerChartPoint('23 Sep', 4, '4'), SellerChartPoint('24 Sep', 5, '5')];
      final l10n = await pumpSeller(
        tester,
        SingleChildScrollView(
          child: SellerChartCard(
            title: 'Orders · Last 3 days',
            summary: '12 orders in total',
            initiallyShowTable: true,
            chart: SellerLineChart(
              series: const [SellerChartSeries(name: 'This period', points: points)],
              axisLabel: (v) => v.round().toString(),
              semanticSummary: '12 orders in total',
            ),
            table: const SellerDataTable(
              columns: [SellerTableColumn('Day'), SellerTableColumn('Orders', numeric: true)],
              rows: [['22 Sep', '3'], ['23 Sep', '4'], ['24 Sep', '5']],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('12 orders in total'), findsWidgets);
      expect(find.bySemanticsLabel('${l10n.dsCellLabel('Day', '23 Sep')}, ${l10n.dsCellLabel('Orders', '4')}'), findsOneWidget);
      await tester.tap(find.text(l10n.dsHideTable));
      await tester.pump();
      expect(find.byType(SellerDataTable), findsNothing);
      handle.dispose();
    });

    testWidgets('delta carries meaning in an arrow and a sign, not colour alone', (tester) async {
      await pumpSeller(
        tester,
        const Column(children: [
          SellerDelta(trend: SellerTrend.up, label: '+25%'),
          SellerDelta(trend: SellerTrend.down, label: '−25%'),
          SellerDelta(trend: SellerTrend.none, label: 'Nothing to compare with yet'),
        ]),
      );
      expect(find.byIcon(SellerIcons.trendUp), findsOneWidget);
      expect(find.byIcon(SellerIcons.trendDown), findsOneWidget);
      expect(find.byIcon(SellerIcons.info), findsOneWidget);
    });

    testWidgets('score ring without enough data shows a dash and says so', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = await pumpSeller(tester, const Center(child: SellerScoreRing(score: null)));
      expect(find.text('—'), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.dsScoreUnavailable), findsOneWidget);
      handle.dispose();
    });

    testWidgets('timeline states are spoken', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = await pumpSeller(
        tester,
        const SellerTimeline(steps: [
          SellerTimelineStep(title: 'Application submitted', state: SellerStepState.done),
          SellerTimelineStep(title: 'Documents and details reviewed', state: SellerStepState.current),
          SellerTimelineStep(title: 'Approved — start selling', state: SellerStepState.upcoming),
        ]),
      );
      expect(find.bySemanticsLabel(RegExp('Application submitted.*${l10n.dsStepCompleted}', dotAll: true)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Documents and details reviewed.*${l10n.dsStepCurrent}', dotAll: true)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Approved — start selling.*${l10n.dsStepUpcoming}', dotAll: true)), findsOneWidget);
      handle.dispose();
    });
  });

  group('large text and dark mode', () {
    for (final brightness in Brightness.values) {
      testWidgets('component gallery at 200 % text on a 320 dp phone has no overflow (${brightness.name})', (tester) async {
        await pumpSeller(
          tester,
          ListView(padding: const EdgeInsets.all(16), children: [
            const SellerLogo(),
            SellerButton(label: 'Save and continue', onPressed: () {}, expand: true),
            SellerButtonBar(children: [
              SellerButton.secondary(label: 'Back', onPressed: () {}),
              SellerButton(label: 'Save and continue', onPressed: () {}),
            ]),
            const SellerBanner(message: 'After signing in, add your mobile number.', tone: SellerTone.info),
            SellerListRow(title: 'Business details', subtitle: 'Hours, holidays and GSTIN', icon: SellerIcons.business, onTap: () {}),
            const SellerMetricCard(label: 'Total sales', value: '₹14,000', delta: SellerDelta(trend: SellerTrend.up, label: '+25%'), caption: 'vs previous 7 days (₹11,200)'),
            const SellerMoneyBreakdown(
              lines: [SellerMoneyLine('Item total', '₹580'), SellerMoneyLine('Commission', '−₹29', tone: SellerTone.danger)],
              totalLabel: 'You receive',
              total: '₹551',
            ),
            SellerChipBar(children: [
              SellerChip(label: 'To accept', count: 3, selected: true, onSelected: (_) {}),
              SellerChip(label: 'Packing', selected: false, onSelected: (_) {}),
            ]),
            SellerSegmented<int>(segments: const [SellerSegment(0, '7 days'), SellerSegment(1, '30 days'), SellerSegment(2, '90 days')], selected: 0, onChanged: (_) {}),
            const SellerStepProgress(current: 3, total: 5, stepTitle: 'Documents'),
            const SellerStatusBadge(label: 'Out for delivery', tone: SellerTone.info, icon: SellerIcons.delivery),
            const SellerEmptyState(title: 'No orders yet', message: "When you receive orders, they'll appear here.", icon: SellerIcons.orders),
            SellerSwitchRow(title: 'Visible to buyers', value: true, onChanged: (_) {}),
            const SellerScoreRing(score: 91),
          ]),
          size: const Size(320, 640),
          textScale: 2,
          brightness: brightness,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Scroll the whole gallery so every item lays out.
        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('formatter: Indian grouping, real minus sign, masking', () {
    expect(SellerFormat.money(124500), '₹1,24,500');
    expect(SellerFormat.money(64.5), '₹64.50');
    expect(SellerFormat.money(-29), '−₹29');
    expect(SellerFormat.moneyCompact(45600), '₹45.6K');
    expect(SellerFormat.moneyCompact(120000), '₹1.2L');
    expect(SellerFormat.percentChange(0.25), '+25%');
    expect(SellerFormat.percentChange(-0.25), '−25%');
    expect(SellerFormat.maskPhone('+91 98765 41234'), '+91${SellerFormat.nbsp}••••••1234');
    expect(SellerFormat.maskAccount('1234567894821'), '••••${SellerFormat.nbsp}4821');
    expect(SellerFormat.maskUpi('kaveri@bank'), 'ka•••••@bank');
    expect(SellerFormat.initials('Kaveri Fresh'), 'KF');
    expect(SellerFormat.initials(''), '');
    expect(SellerFormat.dateRange(DateTime(2026, 9, 18), DateTime(2026, 9, 24)), '18 – 24 Sep 2026');
  });

  test('layout classes follow the board 04 breakpoints', () {
    expect(sellerLayoutFor(390), SellerLayout.compact);
    expect(sellerLayoutFor(600), SellerLayout.medium);
    expect(sellerLayoutFor(840), SellerLayout.expanded);
    expect(sellerLayoutFor(1200), SellerLayout.large);
  });
}

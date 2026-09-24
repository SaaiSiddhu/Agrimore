import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';

import '../support/seller_harness.dart';

/// Board 24-02 (owner correction): keyboard focus highlights the control's
/// EXISTING outline — stronger colour and stroke. No second outline, offset
/// ring, halo, glow or gap; the control's geometry does not change.
List<BorderSide> _sides(WidgetTester tester, Finder scope) => [
      for (final m in tester.widgetList<Material>(find.descendant(of: scope, matching: find.byType(Material))))
        if (m.shape is OutlinedBorder) (m.shape! as OutlinedBorder).side,
    ];

Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

/// A focus request applies on one frame; the control repaints on the next.
Future<void> _focus(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    final c = brightness == Brightness.light ? SellerColors.light : SellerColors.dark;

    group('${brightness.name}:', () {
      testWidgets('filled button: the resting hairline becomes a 3 dp focus stroke; size unchanged', (tester) async {
        useKeyboardFocus();
        final node = FocusNode();
        addTearDown(node.dispose);
        await pumpSeller(tester, Center(child: SellerButton(label: 'Save', onPressed: () {}, focusNode: node)), brightness: brightness);
        final button = find.byType(FilledButton);
        final before = tester.getSize(button);
        final rest = _sides(tester, button);
        expect(rest.single.width, SellerSize.hairline);
        expect(rest.single.color, c.primaryStrong);

        await _focus(tester, node);
        final focused = _sides(tester, button);
        expect(focused, hasLength(1), reason: 'one outline, never a second ring');
        expect(focused.single.width, SellerSize.focusStrong);
        expect(focused.single.color, c.focusOnFill);
        expect(focused.single.strokeAlign, BorderSide.strokeAlignInside, reason: 'drawn inside: no gap, no growth');
        expect(tester.getSize(button), before);
      });

      testWidgets('outlined and danger buttons thicken their own border', (tester) async {
        useKeyboardFocus();
        final a = FocusNode(), b = FocusNode();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        await pumpSeller(
          tester,
          Column(children: [
            SellerButton.secondary(label: 'Back', onPressed: () {}, focusNode: a),
            SellerButton.danger(label: 'Delete', onPressed: () {}, focusNode: b),
          ]),
          brightness: brightness,
        );
        final outlined = find.byType(OutlinedButton);
        final size = tester.getSize(outlined);
        expect(_sides(tester, outlined).single.width, SellerSize.outline);
        await _focus(tester, a);
        expect(_sides(tester, outlined).single.width, SellerSize.focusStrong);
        expect(_sides(tester, outlined).single.color, c.focus);
        expect(tester.getSize(outlined), size);

        final danger = find.ancestor(of: find.text('Delete'), matching: find.byType(FilledButton));
        await _focus(tester, b);
        expect(_sides(tester, danger).single.color, c.focusOnDanger);
        expect(_sides(tester, danger).single.width, SellerSize.focusStrong);
      });

      testWidgets('touch focus does not show the keyboard outline', (tester) async {
        useTouchFocus();
        final node = FocusNode();
        addTearDown(node.dispose);
        await pumpSeller(tester, Center(child: SellerButton(label: 'Save', onPressed: () {}, focusNode: node)), brightness: brightness);
        await _focus(tester, node);
        expect(_sides(tester, find.byType(FilledButton)).single.width, SellerSize.hairline);
      });

      testWidgets('list row, card, chip, segment and FAQ row: same outline, heavier; geometry stable', (tester) async {
        useKeyboardFocus();
        await pumpSeller(
          tester,
          ListView(children: [
            SellerListRow(title: 'Help & support', onTap: () {}, bordered: true),
            SellerCard(onTap: () {}, child: const Text('Order 1042')),
            SellerChip(label: 'All', selected: false, onSelected: (_) {}),
            const SellerExpandableRow(title: 'How do payments work?', child: Text('Answer')),
            // Last: Tab moves through its segments one by one.
            SellerSegmented<int>(segments: const [SellerSegment(0, '7 days'), SellerSegment(1, '30 days')], selected: 0, onChanged: (_) {}),
          ]),
          brightness: brightness,
        );
        final targets = [
          find.byType(SellerListRow),
          find.byType(SellerCard),
          find.byType(SellerChip),
          find.byType(SellerExpandableRow),
          find.byType(SellerSegmented<int>),
        ];
        final sizes = [for (final t in targets) tester.getSize(t)];
        final counts = [for (final t in targets) _sides(tester, t).length];

        for (var i = 0; i < targets.length; i++) {
          await _tab(tester);
          final sides = _sides(tester, targets[i]);
          expect(sides.length, counts[i], reason: 'focus adds no extra outline layer (${targets[i]})');
          expect(
            sides.where((s) => s.width >= SellerSize.focus && (s.color == c.focus || s.color == c.focusOnFill)),
            isNotEmpty,
            reason: 'focused ${targets[i]} shows a heavier focus-coloured border',
          );
          expect(sides.every((s) => s.strokeAlign == BorderSide.strokeAlignInside), isTrue);
          expect(tester.getSize(targets[i]), sizes[i], reason: 'geometry stable for ${targets[i]}');
        }
      });

      testWidgets('selected card: focus is still visible as a heavier border', (tester) async {
        useKeyboardFocus();
        await pumpSeller(tester, SellerCard(selected: true, onTap: () {}, child: const Text('Order 1042')), brightness: brightness);
        final card = find.byType(SellerCard);
        final rest = _sides(tester, card).single;
        await _tab(tester);
        final focused = _sides(tester, card).single;
        expect(focused.width, greaterThan(rest.width));
      });

      testWidgets('nav item: the pill carries the focus outline without resizing', (tester) async {
        useKeyboardFocus();
        await pumpSeller(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: SellerNavBar(
              items: const [
                SellerNavItem(icon: SellerIcons.home, label: 'Home'),
                SellerNavItem(icon: SellerIcons.orders, label: 'Orders'),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
          brightness: brightness,
        );
        StadiumBorder pill() => tester
            .widgetList<Container>(find.descendant(of: find.byType(SellerNavBar), matching: find.byType(Container)))
            .map((w) => w.decoration)
            .whereType<ShapeDecoration>()
            .first
            .shape as StadiumBorder;
        final size = tester.getSize(find.byType(SellerNavBar));
        expect(pill().side.width, SellerSize.hairline);
        await _tab(tester);
        expect(pill().side.width, SellerSize.focus);
        expect(tester.getSize(find.byType(SellerNavBar)), size);
      });
    });
  }

  testWidgets('text field: one border, 2 dp focus colour on focus, same size', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpSeller(tester, Padding(padding: const EdgeInsets.all(16), child: SellerTextField(label: 'Stock quantity', focusNode: node)));
    final field = find.byType(TextField);
    final before = tester.getSize(field);
    await _focus(tester, node);
    expect(tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused, isTrue);
    expect(tester.getSize(field), before);
    final theme = SellerTheme.light.inputDecorationTheme;
    expect(theme.enabledBorder!.borderSide.width, SellerSize.hairline);
    expect(theme.focusedBorder!.borderSide.width, SellerSize.focus);
    expect(theme.focusedBorder!.borderSide.color, SellerColors.light.focus);
  });
}

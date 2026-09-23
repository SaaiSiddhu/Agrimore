import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.seller, b),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(WsSpace.page), child: child)),
    );

void main() {
  group('WsOtpInput', () {
    testWidgets('fires onCompleted once all six digits are present (autofill / paste)', (tester) async {
      final controller = TextEditingController();
      String? completed;
      await tester.pumpWidget(_host(WsOtpInput(
        controller: controller,
        digitSemanticsLabel: (i) => 'Digit $i of 6',
        onCompleted: (v) => completed = v,
      )));
      controller.text = '482913';
      await tester.pump();
      expect(completed, '482913');
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('accepts digits only, up to six', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(WsOtpInput(controller: controller, digitSemanticsLabel: (i) => '$i')));
      await tester.enterText(find.byType(TextField), '12a4567890');
      await tester.pump();
      expect(controller.text, '124567');
    });

    testWidgets('labels every cell for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(WsOtpInput(
        controller: TextEditingController(),
        digitSemanticsLabel: (i) => 'Digit $i of 6',
      )));
      for (var i = 1; i <= 6; i++) {
        expect(find.bySemanticsLabel('Digit $i of 6'), findsOneWidget);
      }
      // the real input stays reachable by assistive technology
      final field = tester.getSemantics(find.byType(EditableText));
      expect(field.flagsCollection.isTextField, isTrue);
      handle.dispose();
    });

    testWidgets('renders in dark mode without exceptions', (tester) async {
      await tester.pumpWidget(_host(
        WsOtpInput(controller: TextEditingController(text: '12'), digitSemanticsLabel: (i) => '$i', hasError: true),
        b: Brightness.dark,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('WsTimeline renders every step title and caption', (tester) async {
    await tester.pumpWidget(_host(const WsTimeline(steps: [
      WsTimelineStep(title: 'Submitted', caption: '26 Sep', state: WsTimelineState.done),
      WsTimelineStep(title: 'Review', state: WsTimelineState.current),
      WsTimelineStep(title: 'Approved', state: WsTimelineState.upcoming),
    ])));
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('26 Sep'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byIcon(AgIcons.success), findsOneWidget);
  });

  testWidgets('WsTestModeRibbon pairs its warning colour with an icon', (tester) async {
    await tester.pumpWidget(_host(const WsTestModeRibbon(label: 'Test mode')));
    expect(find.text('Test mode'), findsOneWidget);
    expect(find.byIcon(AgIcons.warning), findsOneWidget);
  });
}

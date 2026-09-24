// DLV-A1 — under the Workspace theme buttons are full-width
// (minimumSize: Size.fromHeight). Two of them sat unwrapped in a Row after
// DLV-C1 moved the rider app onto that theme; this pins the behaviour so a
// future Row of buttons is caught in a test, not on a rider's phone.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('an unwrapped button in a Row fails to lay out under this theme', (t) async {
    await t.pumpWidget(host(Row(children: [OutlinedButton(onPressed: () {}, child: const Text('Call'))])));
    expect(t.takeException(), isNotNull);
  });

  testWidgets('wrapped in Expanded it lays out', (t) async {
    await t.pumpWidget(host(Row(children: [
      Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Call'))),
      Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Navigate'))),
    ])));
    expect(t.takeException(), isNull);
  });
}

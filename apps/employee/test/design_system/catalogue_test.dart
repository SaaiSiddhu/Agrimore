import 'package:employee/catalogue/catalogue_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SaCatalogueApp initializes and renders tabs without Firebase',
      (tester) async {
    await tester.pumpWidget(const SaCatalogueApp());
    await tester.pumpAndSettle();

    // Verify title and tabs are rendered
    expect(find.text('AgriMore SA Design System'), findsOneWidget);
    expect(find.text('Brand & Tokens'), findsOneWidget);
    expect(find.text('Typography'), findsOneWidget);
    expect(find.text('Icons'), findsOneWidget);
    expect(find.text('Components'), findsOneWidget);
    expect(find.text('Content & Privacy'), findsOneWidget);

    // Verify palette elements are present
    expect(find.text('01 Primary Palette'), findsOneWidget);
    expect(find.text('#2563EB'), findsOneWidget);
    expect(find.text('#1D4ED8'), findsOneWidget);
  });
}

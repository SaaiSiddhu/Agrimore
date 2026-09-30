import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';

void main() {
  testWidgets(
      'all Account icons load at consistent size on light and dark menus',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    var taps = 0;
    await tester.runAsync(() async {
      final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
      for (final font in fonts) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List<dynamic>) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
    });

    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: boundaryKey,
        child: Row(children: [
          for (final theme in [SellerTheme.light, SellerTheme.dark])
            Expanded(
                child: Theme(
                    data: theme,
                    child: Builder(
                        builder: (context) => Material(
                              color: theme.scaffoldBackgroundColor,
                              child: Column(children: [
                                const SizedBox(height: 24),
                                Text('Account icons · ${theme.brightness.name}',
                                    style: context.text.titleLarge),
                                const SizedBox(height: 16),
                                for (final kind in SellerAccountIconKind.values)
                                  SellerListRow(
                                    title: kind.fileName.replaceAll('-', ' '),
                                    leading: SellerAccountIcon(kind),
                                    onTap: () => taps++,
                                  ),
                              ]),
                            )))),
        ]),
      ),
    ));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(SellerAccountIcon).first);
      for (final kind in SellerAccountIconKind.values) {
        await precacheImage(AssetImage(kind.assetPath), context);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SellerAccountIcon), findsNWidgets(28));
    for (final element in find.byType(SellerAccountIcon).evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)), const Size(48, 48));
    }
    await tester.tap(find.text('store status').first);
    await tester.pumpAndSettle();
    expect(taps, 1);
    if (const bool.fromEnvironment('ICON_EVIDENCE')) {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('assets/images/clay-icons/account-icons-preview.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

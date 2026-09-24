import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual QA renders (not assertions): real Inter + Lucide fonts, written as
/// PNGs to `$SELLER_QA_OUT` for side-by-side review against the boards.
/// Skipped unless `--dart-define=SELLER_QA_OUT=<dir>` is passed, so the
/// normal suite never writes files.
const String qaOut = String.fromEnvironment('SELLER_QA_OUT');
bool get qaEnabled => qaOut.isNotEmpty;

Future<void> loadSellerFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await lucide.load();
}

/// Wraps the app under test so it can be captured.
final GlobalKey qaBoundary = GlobalKey();

Widget qaFrame(Widget app) => RepaintBoundary(key: qaBoundary, child: app);

Future<void> qaCapture(WidgetTester tester, String name) async {
  if (!qaEnabled) return;
  await tester.pump();
  final boundary = qaBoundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$qaOut/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

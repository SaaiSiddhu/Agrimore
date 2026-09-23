// lib/screens/user/orders/widgets/tracking_marker_icons.dart
//
// Phase DLV-3B — distinct map pins for the rider, the store and the delivery
// address, drawn at run time. BitmapDescriptor.defaultMarkerWithHue has no
// effect on web (every pin rendered the same red on the browser run), so the
// three could not be told apart.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackingMarkerIcons {
  const TrackingMarkerIcons({required this.rider, required this.store, required this.home});

  final BitmapDescriptor rider;
  final BitmapDescriptor store;
  final BitmapDescriptor home;

  static Future<TrackingMarkerIcons> build() async => TrackingMarkerIcons(
        rider: await _dot(const Color(0xFF2D7D3C), Icons.delivery_dining_rounded),
        store: await _dot(const Color(0xFF1976D2), Icons.storefront_rounded),
        home: await _dot(const Color(0xFFE65100), Icons.home_rounded),
      );

  /// A white-ringed coloured disc with a white icon, 44 logical px.
  static Future<BitmapDescriptor> _dot(Color color, IconData icon) async {
    const logical = 44.0;
    const scale = 3.0;
    const size = logical * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const c = Offset(size / 2, size / 2);
    canvas.drawCircle(c, size / 2, Paint()..color = Colors.white);
    canvas.drawCircle(c, size / 2 - 3 * scale, Paint()..color = color);
    final text = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 24 * scale,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: logical,
      height: logical,
    );
  }
}

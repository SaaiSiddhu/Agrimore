import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

/// The two-leaf sprout mark, drawn as vectors so it is sharp at every size
/// and follows the theme (decision D14b; the launcher icon is unchanged).
class SellerLeafMark extends StatelessWidget {
  const SellerLeafMark({super.key, this.size = SellerSize.avatarMd});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: CustomPaint(painter: _LeafPainter(c.primary, c.leaf))),
    );
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.primary, this.leaf);
  final Color primary;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stem = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * 0.5, s * 0.92), Offset(s * 0.5, s * 0.5), stem);
    final right = Path()
      ..moveTo(s * 0.5, s * 0.56)
      ..cubicTo(s * 0.52, s * 0.24, s * 0.78, s * 0.08, s * 0.96, s * 0.08)
      ..cubicTo(s * 0.97, s * 0.38, s * 0.78, s * 0.6, s * 0.5, s * 0.56)
      ..close();
    canvas.drawPath(right, Paint()..color = primary);
    final left = Path()
      ..moveTo(s * 0.5, s * 0.7)
      ..cubicTo(s * 0.47, s * 0.44, s * 0.26, s * 0.3, s * 0.04, s * 0.3)
      ..cubicTo(s * 0.04, s * 0.56, s * 0.22, s * 0.74, s * 0.5, s * 0.7)
      ..close();
    canvas.drawPath(left, Paint()..color = leaf);
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.primary != primary || old.leaf != leaf;
}

/// Logo lockup: leaf mark + "AgriMore" + "SELLER" (boards 06, 16-01). Read
/// once as "AgriMore Seller".
class SellerLogo extends StatelessWidget {
  const SellerLogo({super.key, this.markSize = SellerSize.avatarMd, this.large = false});
  final double markSize;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SellerLeafMark(size: large ? markSize * 1.4 : markSize),
          const SizedBox(width: SellerSpace.s8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.dsBrandName, style: (large ? text.headlineMedium : text.titleLarge)!.copyWith(fontWeight: SellerType.bold)),
                Text(
                  l10n.dsBrandRole.toUpperCase(),
                  style: text.labelSmall!.copyWith(color: c.primary, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple organic illustration for empty, status and success screens: an
/// icon on a mint blob with two leaves and an optional badge (boards 06,
/// 13, 16-06/07/08). Decorative — the heading next to it says what it means.
class SellerIllustration extends StatelessWidget {
  const SellerIllustration({super.key, required this.icon, this.badge, this.tone = SellerTone.brand, this.size = SellerSize.illustration});

  final IconData icon;

  /// Small icon in a circle at the top right (clock, "!", check…).
  final IconData? badge;
  final SellerTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pair = c.tone(tone);
    final blob = tone == SellerTone.brand ? c.primaryContainer : pair.container;
    final ink = tone == SellerTone.brand ? c.primary : pair.foreground;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BlobPainter(blob, c.leaf.withValues(alpha: SellerOpacity.selection)))),
            Center(child: Icon(icon, size: size * 0.42, color: ink)),
            if (badge != null)
              Positioned(
                right: size * 0.1,
                top: size * 0.1,
                child: Container(
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: ink, width: SellerSize.focus),
                  ),
                  child: Icon(badge, size: size * 0.16, color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.fill, this.leaf);
  final Color fill;
  final Color leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final blob = Path()
      ..moveTo(s * 0.5, s * 0.08)
      ..cubicTo(s * 0.78, s * 0.06, s * 0.95, s * 0.28, s * 0.92, s * 0.52)
      ..cubicTo(s * 0.9, s * 0.8, s * 0.7, s * 0.95, s * 0.46, s * 0.92)
      ..cubicTo(s * 0.2, s * 0.9, s * 0.05, s * 0.72, s * 0.08, s * 0.48)
      ..cubicTo(s * 0.1, s * 0.24, s * 0.26, s * 0.1, s * 0.5, s * 0.08)
      ..close();
    canvas.drawPath(blob, Paint()..color = fill);
    final leafPaint = Paint()..color = leaf;
    final l1 = Path()
      ..moveTo(s * 0.1, s * 0.86)
      ..quadraticBezierTo(s * 0.06, s * 0.66, s * 0.24, s * 0.62)
      ..quadraticBezierTo(s * 0.26, s * 0.82, s * 0.1, s * 0.86)
      ..close();
    final l2 = Path()
      ..moveTo(s * 0.9, s * 0.2)
      ..quadraticBezierTo(s * 0.96, s * 0.38, s * 0.8, s * 0.42)
      ..quadraticBezierTo(s * 0.76, s * 0.26, s * 0.9, s * 0.2)
      ..close();
    canvas.drawPath(l1, leafPaint);
    canvas.drawPath(l2, leafPaint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.fill != fill || old.leaf != leaf;
}

/// A strip across the top of the app while it runs against the local
/// emulators, so no screenshot or recording can be mistaken for live data
/// (decision D13). It takes the status-bar inset and removes it below.
class SellerTestDataRibbon extends StatelessWidget {
  const SellerTestDataRibbon({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Material(
          color: c.warningContainer,
          child: SafeArea(
            bottom: false,
            child: Semantics(
              container: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s2),
                child: Text(
                  l10n.dsTestDataRibbon,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium!.copyWith(color: c.warning),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ],
    );
  }
}

/// The sign-in landscape (board 16-01): rolling hills, crop rows, a farmhouse
/// and two trees, drawn from the theme so it works in light and dark.
/// Decorative — the headline under it carries the meaning.
class SellerFarmScene extends StatelessWidget {
  const SellerFarmScene({super.key, this.height = SellerSize.farmScene});
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FarmPainter(
            radius: SellerRadius.dialog,
            far: c.primaryContainer,
            near: c.leaf,
            rows: c.primary,
            house: c.surface,
            roof: c.primaryStrong,
            outline: c.border,
          ),
        ),
      ),
    );
  }
}

class _FarmPainter extends CustomPainter {
  _FarmPainter({required this.radius, required this.far, required this.near, required this.rows, required this.house, required this.roof, required this.outline});
  final double radius;
  final Color far;
  final Color near;
  final Color rows;
  final Color house;
  final Color roof;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Keep the drawing a fixed aspect, centred, whatever the width.
    final dw = h * 2.4 < w ? h * 2.4 : w;
    final ox = (w - dw) / 2;
    Offset p(double x, double y) => Offset(ox + dw * x, h * y);
    // Soft rounded edges, as on the board, instead of a hard crop.
    canvas.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox, 0, dw, h), Radius.circular(radius)));

    final back = Path()
      ..moveTo(p(0, 0.62).dx, p(0, 0.62).dy)
      ..quadraticBezierTo(p(0.22, 0.28).dx, p(0.22, 0.28).dy, p(0.46, 0.5).dx, p(0.46, 0.5).dy)
      ..quadraticBezierTo(p(0.72, 0.2).dx, p(0.72, 0.2).dy, p(1, 0.52).dx, p(1, 0.52).dy)
      ..lineTo(p(1, 1).dx, p(1, 1).dy)
      ..lineTo(p(0, 1).dx, p(0, 1).dy)
      ..close();
    canvas.drawPath(back, Paint()..color = far);

    final front = Path()
      ..moveTo(p(0, 0.78).dx, p(0, 0.78).dy)
      ..quadraticBezierTo(p(0.5, 0.56).dx, p(0.5, 0.56).dy, p(1, 0.74).dx, p(1, 0.74).dy)
      ..lineTo(p(1, 1).dx, p(1, 1).dy)
      ..lineTo(p(0, 1).dx, p(0, 1).dy)
      ..close();
    canvas.drawPath(front, Paint()..color = near.withValues(alpha: 0.55));

    // Crop rows curving toward the horizon.
    final row = Paint()
      ..color = rows.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.018
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = 0.8 + i * 0.05;
      canvas.drawPath(
        Path()
          ..moveTo(p(0.06, y + 0.03).dx, p(0.06, y + 0.03).dy)
          ..quadraticBezierTo(p(0.5, y - 0.1).dx, p(0.5, y - 0.1).dy, p(0.94, y + 0.02).dx, p(0.94, y + 0.02).dy),
        row,
      );
    }

    // Farmhouse.
    final body = Rect.fromLTRB(p(0.44, 0.42).dx, p(0, 0.42).dy, p(0.6, 0).dx, p(0, 0.68).dy);
    canvas.drawRect(body, Paint()..color = house);
    canvas.drawRect(body, Paint()..color = outline..style = PaintingStyle.stroke..strokeWidth = h * 0.01);
    final roofPath = Path()
      ..moveTo(p(0.42, 0.44).dx, p(0.42, 0.44).dy)
      ..lineTo(p(0.52, 0.24).dx, p(0.52, 0.24).dy)
      ..lineTo(p(0.62, 0.44).dx, p(0.62, 0.44).dy)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof);
    final door = Rect.fromLTRB(p(0.5, 0).dx, p(0, 0.54).dy, p(0.54, 0).dx, p(0, 0.68).dy);
    canvas.drawRect(door, Paint()..color = roof.withValues(alpha: 0.8));

    // Trees.
    void tree(double x, double y, double r) {
      canvas.drawLine(p(x, y), p(x, y + r * 2.2), Paint()..color = roof..strokeWidth = h * 0.02);
      canvas.drawCircle(p(x, y), h * r, Paint()..color = rows.withValues(alpha: 0.85));
      canvas.drawCircle(p(x - 0.012, y - 0.04), h * r * 0.6, Paint()..color = near);
    }

    tree(0.3, 0.42, 0.11);
    tree(0.76, 0.4, 0.09);
    tree(0.84, 0.48, 0.07);
  }

  @override
  bool shouldRepaint(_FarmPainter old) =>
      old.far != far || old.near != near || old.rows != rows || old.house != house || old.roof != roof || old.outline != outline;
}

/// Google's four-colour "G", required on a "Continue with Google" button by
/// Google's sign-in branding rules (board 16-01). Its colours are Google's,
/// not the seller palette, so they are fixed in both themes.
class SellerGoogleMark extends StatelessWidget {
  const SellerGoogleMark({super.key, this.size = SellerIconSize.md});
  final double size;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _GooglePainter())));
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: (s - stroke) / 2);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.141592653589793 / 180;
    canvas.drawArc(rect, 0, 45 * deg, false, arc(_blue));
    canvas.drawArc(rect, 45 * deg, 100 * deg, false, arc(_green));
    canvas.drawArc(rect, 145 * deg, 70 * deg, false, arc(_yellow));
    canvas.drawArc(rect, 215 * deg, 100 * deg, false, arc(_red));
    canvas.drawRect(Rect.fromLTRB(s / 2, s / 2 - stroke / 2, s - stroke / 2 + stroke / 2, s / 2 + stroke / 2), Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}

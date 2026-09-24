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

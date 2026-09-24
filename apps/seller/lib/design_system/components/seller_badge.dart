import 'package:flutter/material.dart';

import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

/// Status pill: icon + text + tone (board 12, 24-06 — never colour alone).
/// The icon is decorative for screen readers; the label carries the meaning.
class SellerStatusBadge extends StatelessWidget {
  const SellerStatusBadge({super.key, required this.label, this.tone = SellerTone.neutral, this.icon, this.large = false});

  final String label;
  final SellerTone tone;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final pair = context.colors.tone(tone);
    final style = (large ? context.text.labelLarge : context.text.labelMedium)!.copyWith(color: pair.foreground);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? SellerSpace.s12 : SellerSpace.s8, vertical: large ? SellerSpace.s6 : SellerSpace.s2),
      decoration: BoxDecoration(color: pair.container, borderRadius: BorderRadius.circular(SellerRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: large ? SellerIconSize.md : SellerIconSize.sm, color: pair.foreground)),
            const SizedBox(width: SellerSpace.s4),
          ],
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}

/// Small uppercase tag, e.g. "DRAFT" (board 18-02).
class SellerTag extends StatelessWidget {
  const SellerTag({super.key, required this.label, this.tone = SellerTone.warning});

  final String label;
  final SellerTone tone;

  @override
  Widget build(BuildContext context) {
    final pair = context.colors.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s6, vertical: SellerSpace.s2),
      decoration: BoxDecoration(color: pair.container, borderRadius: BorderRadius.circular(SellerRadius.xs)),
      child: Text(
        label.toUpperCase(),
        style: context.text.labelSmall!.copyWith(color: pair.foreground),
        semanticsLabel: label,
      ),
    );
  }
}

/// Unread dot (board 12). Pass the meaning as [semanticLabel] ("Unread").
class SellerDot extends StatelessWidget {
  const SellerDot({super.key, this.color, this.semanticLabel});
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: SellerSize.dot,
      height: SellerSize.dot,
      decoration: BoxDecoration(color: color ?? context.colors.primary, shape: BoxShape.circle),
    );
    return semanticLabel == null ? ExcludeSemantics(child: dot) : Semantics(label: semanticLabel, child: dot);
  }
}

/// A count inside a chip or header ("To accept 3").
class SellerCount extends StatelessWidget {
  const SellerCount({super.key, required this.count, this.inverse = false});
  final int count;

  /// On a filled (selected) chip.
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: SellerSpace.s20),
      padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s6),
      decoration: BoxDecoration(
        color: inverse ? c.onPrimary.withValues(alpha: 0.2) : c.sunken,
        borderRadius: BorderRadius.circular(SellerRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.text.labelMedium!.copyWith(color: inverse ? c.onPrimary : c.textSecondary).tabular,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_motion.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';

extension SellerLayoutContext on BuildContext {
  /// Window class of the current width (board 04).
  SellerLayout get layout => sellerLayoutFor(MediaQuery.sizeOf(this).width);

  /// Horizontal page inset: 16 on phones, 24 from 600 dp.
  double get pageInset => layout == SellerLayout.compact ? SellerSpace.page : SellerSpace.pageWide;

  /// True when the system text size is large enough that side-by-side
  /// controls should stack.
  bool get largeText => MediaQuery.textScalerOf(this).scale(1) >= 1.3;
}

/// A readable-width scrolling page with an optional sticky footer that sits
/// in the body — so it rises above the keyboard instead of hiding under it
/// (boards 07, 15, 24-04). Pull-to-refresh when [onRefresh] is given.
class SellerPage extends StatelessWidget {
  const SellerPage({
    super.key,
    required this.children,
    this.footer,
    this.onRefresh,
    this.maxWidth = SellerSize.formMaxWidth,
    this.controller,
    this.gap = 0,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final Widget? footer;
  final Future<void> Function()? onRefresh;
  final double maxWidth;
  final ScrollController? controller;

  /// Space inserted between children.
  final double gap;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final inset = context.pageInset;
    Widget scroll = SingleChildScrollView(
      controller: controller,
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.fromLTRB(inset, SellerSpace.s16, inset, SellerSpace.s32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0 && gap > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
    if (onRefresh != null) scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    if (footer == null) return scroll;
    return Column(
      children: [
        Expanded(child: scroll),
        SellerStickyFooter(maxWidth: maxWidth, child: footer!),
      ],
    );
  }
}

/// The bar of main actions at the bottom of a task screen: top hairline,
/// surface fill, safe-area aware, centred at the page's readable width.
class SellerStickyFooter extends StatelessWidget {
  const SellerStickyFooter({super.key, required this.child, this.maxWidth = SellerSize.formMaxWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = context.pageInset;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, SellerSpace.s12, inset, SellerSpace.s12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or more actions side by side ([Back][Save and continue],
/// [Reject][Accept order]) that stack — main action first — when the text is
/// large or the space narrow, so no label is ever cut (board 24-04).
class SellerButtonBar extends StatelessWidget {
  const SellerButtonBar({super.key, required this.children, this.stackBelow = 320});

  /// Left-to-right order when side by side; the LAST child is the main action
  /// and goes first when stacked.
  final List<Widget> children;
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (box.maxWidth / scale < stackBelow || context.largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = children.length - 1; i >= 0; i--) ...[
                children[i],
                if (i > 0) const SizedBox(height: SellerSpace.s8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: SellerSpace.s12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// List + detail from 840 dp (board 04): a fixed list pane, a divider and the
/// detail. Below 840 the caller pushes the detail instead.
class SellerListDetail extends StatelessWidget {
  const SellerListDetail({super.key, required this.list, required this.detail});
  final Widget list;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: SellerSize.listPane, child: list),
        VerticalDivider(width: SellerSize.hairline, thickness: SellerSize.hairline, color: c.border),
        Expanded(child: detail),
      ],
    );
  }
}

/// "—— OR ——" between sign-in options (board 16-01).
class SellerOrDivider extends StatelessWidget {
  const SellerOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SellerSpace.s8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s12),
            child: Text(l10n.orDivider.toUpperCase(), style: context.text.labelMedium),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// A bordered question row that opens in place (board 23-05): chevron turns,
/// the open row takes the mint tint, and the state is announced
/// ("expanded"/"collapsed"). Keyboard focus thickens the row's own border.
class SellerExpandableRow extends StatefulWidget {
  const SellerExpandableRow({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<SellerExpandableRow> createState() => _SellerExpandableRowState();
}

class _SellerExpandableRowState extends State<SellerExpandableRow> {
  late bool _open = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _open = !_open);
    widget.onExpansionChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final l10n = AppLocalizations.of(context);
    final duration = context.motion(SellerMotion.standard);
    final Widget body = _open
        ? Padding(
            padding: const EdgeInsets.fromLTRB(SellerSpace.s16, 0, SellerSpace.s16, SellerSpace.s16),
            child: DefaultTextStyle.merge(style: text.bodyMedium, child: widget.child),
          )
        : const SizedBox(width: double.infinity);
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SellerRadius.card),
          side: sellerOutline(c, focused: focused, rest: _open ? c.primary : c.border),
        );
        return Material(
          color: _open ? c.primarySubtle : c.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _open,
                label: widget.title,
                hint: _open ? l10n.dsCollapseHint : l10n.dsExpandHint,
                excludeSemantics: true,
                onTap: _toggle,
                child: InkWell(
                  focusNode: node,
                  onTap: _toggle,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: SellerSize.touchTarget + SellerSpace.s8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s12),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: SellerIconSize.md, color: c.primary),
                            const SizedBox(width: SellerSpace.s12),
                          ],
                          Expanded(child: Text(widget.title, style: text.titleSmall)),
                          const SizedBox(width: SellerSpace.s8),
                          AnimatedRotation(
                            turns: _open ? 0.5 : 0,
                            duration: duration,
                            child: Icon(SellerIcons.chevronDown, size: SellerIconSize.md, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (context.reduceMotion)
                body
              else
                AnimatedSize(
                  duration: duration,
                  curve: SellerMotion.standardCurve,
                  alignment: Alignment.topCenter,
                  child: body,
                ),
            ],
          ),
        );
      },
    );
  }
}
